import Foundation

extension Substring {
	/// If the string has the given prefix, drop it and return the remaining string, otherwise return nil
	func dropPrefix(_ prefix: some StringProtocol) -> Substring? {
		if let range = range(of: prefix, options: .anchored) {
			self[range.upperBound...]
		} else {
			nil
		}
	}

	/// If the string has the given suffix, drop it and return the remaining string, otherwise return nil
	func dropSuffix(_ suffix: some StringProtocol) -> Substring? {
		if let range = range(of: suffix, options: [.anchored, .backwards]) {
			self[..<range.lowerBound]
		} else {
			nil
		}
	}
}

extension Pattern {
	/// Test if a given string matches the pattern
	/// - Parameter name: The string to match against
	/// - Returns: true if the string matches the pattern (or any alternative if brace expansion was used)
	public func match(_ name: some StringProtocol) -> Bool {
		// Try each alternative (from brace expansion)
		for sections in alternatives {
			if match(components: .init(sections), .init(name)) {
				return true
			} else if options.matchesTrailingPathSeparator && name.last == options.pathSeparator {
				if match(components: .init(sections), .init(name).dropLast()) {
					return true
				}
			}
		}

		return false
	}

	// recursively matches against the pattern
	private func match(
		components: ArraySlice<Section>,
		_ name: Substring
	) -> Bool {
		// we use a loop to avoid unbounded recursion on arbitrarily long search strings
		// this method still recurses for wildcard matching, but it is bounded by the number of wildcards in the pattern, not the size of the search string
		// the previous version that didn't use a loop would crash with search strings as small as 99 characters
		var components = components
		var name = name

		#if DEBUG
			// used for infinite loop detection
			var lastComponents: ArraySlice<Pattern.Section>?
			var lastName: Substring?
		#endif

		while true {
			#if DEBUG
				if lastComponents == components && lastName == name {
					fatalError("infinite loop!")
				}
				lastComponents = components
				lastName = name
			#endif

			// this matches the value both from the beginning and the end, in order of what should be the most performant
			// matching at the beginning of a string is faster than iterating over the end of a string
			// matching constant length components is faster than wildcards
			// matching a component level wildcard is faster than a path level wildcard because it is more likely to find a limit

			// when matchLeadingDirectories is set, we can't match from the end

			switch (components.first, components.last, options.matchLeadingDirectories) {
			case (.pathSeparator, _, _):
				if name.first == options.pathSeparator {
					components = components.dropFirst()
					name = name.dropFirst()
				} else if components.dropFirst().first == .pathWildcard {
					components = components.dropFirst(2)
				} else {
					return false
				}
			case let (.constant(constant), _, _):
				if let remaining = name.dropPrefix(constant) {
					components = components.dropFirst()
					name = remaining
				} else {
					return false
				}
			case (.singleCharacter, _, _):
				guard name.first != options.pathSeparator else { return false }
				if options.requiresExplicitLeadingPeriods && isAtSegmentStart(name) && name.first == "." {
					return false
				}

				components = components.dropFirst()
				name = name.dropFirst()
			case let (.oneOf(ranges, isNegated: isNegated), _, _):
				if options.requiresExplicitLeadingPeriods && isAtSegmentStart(name) && name.first == "." {
					// https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_13_01
					// It is unspecified whether an explicit <period> in a bracket expression matching list, such as "[.abc]", can match a leading <period> in a filename.
					// in our implimentation, it will not match
					return false
				}

				guard let next = name.first, ranges.contains(where: { $0.contains(next) }) == !isNegated else { return false }

				components = components.dropFirst()
				name = name.dropFirst()
			case (_, .pathSeparator, false):
				if name.last == options.pathSeparator {
					components = components.dropLast()
					name = name.dropLast()
				} else if name.isEmpty && components.dropLast().last == .pathWildcard {
					components = components.dropLast(2)
				} else {
					return false
				}
			case let (_, .constant(constant), false):
				if let remaining = name.dropSuffix(constant) {
					components = components.dropLast()
					name = remaining
				} else {
					return false
				}
			case (_, .singleCharacter, false):
				guard name.last != options.pathSeparator else { return false }

				components = components.dropLast()
				name = name.dropLast()
			case let (_, .oneOf(ranges, isNegated: isNegated), false):
				guard let next = name.last, ranges.contains(where: { $0.contains(next) }) == !isNegated else { return false }

				components = components.dropLast()
				name = name.dropLast()
			case (.componentWildcard, _, _):
				if options.requiresExplicitLeadingPeriods && isAtSegmentStart(name) && name.first == "." {
					return false
				}

				if components.count == 1 {
					if let pathSeparator = options.pathSeparator, !options.matchLeadingDirectories {
						// the last component is a component level wildcard, which matches anything except for the path separator
						return !name.contains(pathSeparator)
					} else {
						// no special treatment for path separators
						return true
					}
				}

				if match(components: components.dropFirst(), name) {
					return true
				} else if name.isEmpty {
					return false
				} else {
					// components remain unchanged
					name = name.dropFirst()
				}
			case (_, .componentWildcard, false):
				if match(components: components.dropLast(), name) {
					return true
				} else if name.isEmpty {
					return false
				} else {
					// components remain unchanged
					name = name.dropLast()
				}
			case (.pathWildcard, _, _):
				if components.count == 1 {
					// the last component is a path level wildcard, which matches anything
					return true
				}

				if match(components: components.dropFirst(), name) {
					return true
				} else if components.dropFirst().first == .pathSeparator, match(components: components.dropFirst(2), name) {
					return true
				} else if name.isEmpty {
					return false
				} else {
					// components remain unchanged
					name = name.dropFirst()
				}
			case let (.patternList(style, subSections), _, _):
				let remaining = matchPatternListPrefix(
					components: components,
					name,
					style: style,
					subSections: subSections,
					requiresCompleteMatch: true
				)

				return remaining != nil
			case (.none, _, _):
				if options.matchLeadingDirectories && name.first == options.pathSeparator {
					return true
				}

				return name.isEmpty
			}
		}
	}

	/// Matches the beginning of the string and returns the rest. If a match cannot be made, returns nil.
	private func matchPrefix(
		components: ArraySlice<Section>,
		_ name: Substring
	) -> Substring? {
		if name.isEmpty {
			if components.isEmpty || components.allSatisfy(\.matchesEmptyContent) {
				return name.dropAll()
			} else if components.contains(.pathWildcard) && components.allSatisfy({ $0 == .pathSeparator || $0.matchesEmptyContent }) {
				return name.dropAll()
			} else {
				return nil
			}
		}

		switch components.first {
		case .pathSeparator:
			if name.first == options.pathSeparator {
				return matchPrefix(
					components: components.dropFirst(),
					name.dropFirst()
				)
			} else {
				return nil
			}
		case let .constant(constant):
			if let remaining = name.dropPrefix(constant) {
				return matchPrefix(
					components: components.dropFirst(),
					remaining
				)
			} else {
				return nil
			}
		case .singleCharacter:
			guard name.first != options.pathSeparator else { return nil }
			if options.requiresExplicitLeadingPeriods && isAtSegmentStart(name) {
				return nil
			}

			return matchPrefix(
				components: components.dropFirst(),
				name.dropFirst()
			)
		case let .oneOf(ranges, isNegated: isNegated):
			if options.requiresExplicitLeadingPeriods && isAtSegmentStart(name) {
				// https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_13_01
				// It is unspecified whether an explicit <period> in a bracket expression matching list, such as "[.abc]", can match a leading <period> in a filename.
				// in our implimentation, it will not match
				return nil
			}

			guard let next = name.first, ranges.contains(where: { $0.contains(next) }) == !isNegated else { return nil }
			return matchPrefix(
				components: components.dropFirst(),
				name.dropFirst()
			)
		case .componentWildcard:
			if options.requiresExplicitLeadingPeriods && isAtSegmentStart(name) {
				return nil
			}

			if components.count == 1 {
				if let pathSeparator = options.pathSeparator, !options.matchLeadingDirectories {
					// the last component is a component level wildcard, which matches anything except for the path separator
					if let index = name.firstIndex(of: pathSeparator) {
						return name.suffix(from: index)
					} else {
						return name.dropAll()
					}
				} else {
					// no special treatment for path separators
					return name.dropAll()
				}
			}

			if let remaining = matchPrefix(components: components.dropFirst(), name) {
				return remaining
			} else {
				return matchPrefix(components: components, name.dropFirst())
			}
		case .pathWildcard:
			if components.count == 1 {
				// the last component is a path level wildcard, which matches anything
				return name.dropAll()
			}

			if let remaining = matchPrefix(components: components.dropFirst(), name) {
				return remaining
			} else if components.dropFirst().first == .pathSeparator, let remaining = matchPrefix(components: components.dropFirst(2), name) {
				return remaining
			} else {
				return matchPrefix(components: components, name.dropFirst())
			}
		case let .patternList(style, subSections):
			return matchPatternListPrefix(
				components: components,
				name,
				style: style,
				subSections: subSections
			)
		case .none:
			return name
		}
	}

	private func matchPatternListPrefix(
		components: ArraySlice<Section>,
		_ name: Substring,
		style: Section.PatternListStyle,
		subSections: [[Section]],
		requiresCompleteMatch: Bool = false
	) -> Substring? {
		switch style {
		case .negated:
			return matchNegatedPatternListPrefix(
				components: components,
				name,
				subSections: subSections,
				requiresCompleteMatch: requiresCompleteMatch
			)
		case .one:
			// Must match exactly one of the options
			for sectionsOption in subSections {
				// Get all possible matches for this option (enables backtracking)
				let optionMatches = allPossiblePrefixMatches(
					components: ArraySlice(sectionsOption),
					name
				)
				for afterOption in optionMatches {
					// Get all possible matches for the rest of the pattern
					let restMatches = allPossiblePrefixMatches(
						components: components.dropFirst(),
						afterOption
					)
					for remaining in restMatches {
						if !requiresCompleteMatch || remaining.isEmpty {
							return remaining
						}
					}
				}
			}
			return nil
		case .zeroOrOne:
			// Try matching one of the options first
			for sectionsOption in subSections {
				let optionMatches = allPossiblePrefixMatches(
					components: ArraySlice(sectionsOption),
					name
				)
				for afterOption in optionMatches {
					let restMatches = allPossiblePrefixMatches(
						components: components.dropFirst(),
						afterOption
					)
					for remaining in restMatches {
						if !requiresCompleteMatch || remaining.isEmpty {
							return remaining
						}
					}
				}
			}
			// Then try matching zero
			let zeroMatches = allPossiblePrefixMatches(components: components.dropFirst(), name)
			for remaining in zeroMatches {
				if !requiresCompleteMatch || remaining.isEmpty {
					return remaining
				}
			}
			return nil
		case .oneOrMore:
			// Must match at least one, then try to match more
			return matchRepeatingPatternListPrefix(
				components: components,
				name,
				subSections: subSections,
				needsAtLeastOne: true,
				requiresCompleteMatch: requiresCompleteMatch
			)
		case .zeroOrMore:
			// Can match zero or more
			return matchRepeatingPatternListPrefix(
				components: components,
				name,
				subSections: subSections,
				needsAtLeastOne: false,
				requiresCompleteMatch: requiresCompleteMatch
			)
		}
	}

	private func matchRepeatingPatternListPrefix(
		components: ArraySlice<Section>,
		_ name: Substring,
		subSections: [[Section]],
		needsAtLeastOne: Bool,
		requiresCompleteMatch: Bool = false
	) -> Substring? {
		// Try each option
		for sectionsOption in subSections {
			// Get all possible prefix matches for this option (shortest first for backtracking)
			let possibleMatches = allPossiblePrefixMatches(
				components: ArraySlice(sectionsOption),
				name
			)

			for afterOption in possibleMatches {
				// Prevent infinite recursion when option matches empty
				guard afterOption != name else { continue }

				// After matching one, try to match more occurrences
				if let remaining = matchRepeatingPatternListPrefix(
					components: components,
					afterOption,
					subSections: subSections,
					needsAtLeastOne: false,
					requiresCompleteMatch: requiresCompleteMatch
				) {
					// Only accept if this leads to a complete match when required
					if !requiresCompleteMatch || remaining.isEmpty {
						return remaining
					}
				}

				// Try using just this occurrence and matching the rest of the pattern
				if let remaining = matchPrefix(components: components.dropFirst(), afterOption) {
					if !requiresCompleteMatch || remaining.isEmpty {
						return remaining
					}
				}
			}
		}

		// If allowed, try matching zero occurrences
		if !needsAtLeastOne {
			if let remaining = matchPrefix(components: components.dropFirst(), name) {
				if !requiresCompleteMatch || remaining.isEmpty {
					return remaining
				}
			}
		}

		return nil
	}

	/// Returns all possible prefix matches for a pattern, sorted by match length (shortest first).
	/// This enables backtracking by trying shorter matches when longer ones don't work.
	private func allPossiblePrefixMatches(
		components: ArraySlice<Section>,
		_ name: Substring
	) -> [Substring] {
		// Check if the pattern contains any variable-length sections that need exploration
		let hasVariableLengthSections = components.contains { section in
			switch section {
			case .componentWildcard, .pathWildcard, .patternList:
				true
			default:
				false
			}
		}

		// For simple patterns without wildcards or pattern lists, just use matchPrefix
		if !hasVariableLengthSections {
			if let result = matchPrefix(components: components, name) {
				return [result]
			}
			return []
		}

		// Collect all possible matches
		var results: [Substring] = []
		collectAllPrefixMatches(components: components, name, into: &results)

		// Sort by remaining length descending (shortest match first = longest remaining)
		// and deduplicate
		let unique = Set(results.map(\.startIndex))
		return unique.sorted { $0 > $1 }.compactMap { index in
			results.first { $0.startIndex == index }
		}
	}

	private func collectAllPrefixMatches(
		components: ArraySlice<Section>,
		_ name: Substring,
		into results: inout [Substring]
	) {
		guard let first = components.first else {
			results.append(name)
			return
		}

		let rest = components.dropFirst()

		switch first {
		case .pathSeparator:
			if name.first == options.pathSeparator {
				collectAllPrefixMatches(components: rest, name.dropFirst(), into: &results)
			}

		case let .constant(constant):
			if let remaining = name.dropPrefix(constant) {
				collectAllPrefixMatches(components: rest, remaining, into: &results)
			}

		case .singleCharacter:
			guard !name.isEmpty, name.first != options.pathSeparator else { return }
			if options.requiresExplicitLeadingPeriods && isAtSegmentStart(name) && name.first == "." {
				return
			}
			collectAllPrefixMatches(components: rest, name.dropFirst(), into: &results)

		case let .oneOf(ranges, isNegated: isNegated):
			guard let next = name.first, ranges.contains(where: { $0.contains(next) }) == !isNegated else { return }
			if options.requiresExplicitLeadingPeriods && isAtSegmentStart(name) && name.first == "." {
				return
			}
			collectAllPrefixMatches(components: rest, name.dropFirst(), into: &results)

		case .componentWildcard:
			if options.requiresExplicitLeadingPeriods && isAtSegmentStart(name) && name.first == "." {
				return
			}
			// Try matching 0, 1, 2, ... characters
			var remaining = name
			while true {
				collectAllPrefixMatches(components: rest, remaining, into: &results)
				guard !remaining.isEmpty, remaining.first != options.pathSeparator else { break }
				remaining = remaining.dropFirst()
			}

		case .pathWildcard:
			// Try matching 0, 1, 2, ... characters (including path separators)
			var remaining = name
			while true {
				collectAllPrefixMatches(components: rest, remaining, into: &results)
				guard !remaining.isEmpty else { break }
				remaining = remaining.dropFirst()
			}

		case let .patternList(style, subSections):
			collectPatternListMatches(
				components: components,
				name,
				style: style,
				subSections: subSections,
				into: &results
			)
		}
	}

	private func collectPatternListMatches(
		components: ArraySlice<Section>,
		_ name: Substring,
		style: Section.PatternListStyle,
		subSections: [[Section]],
		into results: inout [Substring]
	) {
		let rest = components.dropFirst()

		switch style {
		case .one:
			// Match exactly one option
			for option in subSections {
				var optionMatches: [Substring] = []
				collectAllPrefixMatches(components: ArraySlice(option), name, into: &optionMatches)
				for afterOption in optionMatches {
					collectAllPrefixMatches(components: rest, afterOption, into: &results)
				}
			}

		case .zeroOrOne:
			// Try zero first
			collectAllPrefixMatches(components: rest, name, into: &results)
			// Then try one
			for option in subSections {
				var optionMatches: [Substring] = []
				collectAllPrefixMatches(components: ArraySlice(option), name, into: &optionMatches)
				for afterOption in optionMatches {
					collectAllPrefixMatches(components: rest, afterOption, into: &results)
				}
			}

		case .oneOrMore:
			collectRepeatingMatches(
				components: components,
				name,
				subSections: subSections,
				needsAtLeastOne: true,
				into: &results
			)

		case .zeroOrMore:
			collectRepeatingMatches(
				components: components,
				name,
				subSections: subSections,
				needsAtLeastOne: false,
				into: &results
			)

		case .negated:
			// For negated patterns, try all prefix lengths that don't match any sub-pattern
			for length in 0 ... name.count {
				let prefix = name.prefix(length)
				let matchesAnyPattern = subSections.contains { sections in
					if let remaining = matchPrefix(components: ArraySlice(sections), Substring(prefix)) {
						return remaining.isEmpty
					}
					return false
				}
				if !matchesAnyPattern {
					let afterNegation = name.dropFirst(length)
					collectAllPrefixMatches(components: rest, afterNegation, into: &results)
				}
			}
		}
	}

	private func collectRepeatingMatches(
		components: ArraySlice<Section>,
		_ name: Substring,
		subSections: [[Section]],
		needsAtLeastOne: Bool,
		into results: inout [Substring]
	) {
		let rest = components.dropFirst()

		// Try zero if allowed
		if !needsAtLeastOne {
			collectAllPrefixMatches(components: rest, name, into: &results)
		}

		// Try matching one or more
		for option in subSections {
			var optionMatches: [Substring] = []
			collectAllPrefixMatches(components: ArraySlice(option), name, into: &optionMatches)

			for afterOption in optionMatches {
				guard afterOption != name else { continue } // Prevent infinite recursion

				// After one match, try matching more (with zero allowed) or finishing
				collectRepeatingMatches(
					components: components,
					afterOption,
					subSections: subSections,
					needsAtLeastOne: false,
					into: &results
				)
			}
		}
	}

	private func matchNegatedPatternListPrefix(
		components: ArraySlice<Section>,
		_ name: Substring,
		subSections: [[Section]],
		requiresCompleteMatch: Bool = false
	) -> Substring? {
		// !(pattern-list) matches any string that cannot be matched by any pattern in the list
		// We try different prefix lengths (longest first) and check if any pattern matches that exact prefix

		// Try consuming different lengths of the input (longest first for greedy matching)
		for length in stride(from: name.count, through: 0, by: -1) {
			let prefix = name.prefix(length)

			// Check if this exact prefix matches any pattern completely
			let matchesAnyPattern = subSections.contains { sections in
				if let remaining = matchPrefix(components: ArraySlice(sections), Substring(prefix)) {
					return remaining.isEmpty
				}
				return false
			}

			if !matchesAnyPattern {
				// This prefix doesn't match any pattern exactly, it's a valid negation match
				let afterNegation = name.dropFirst(length)
				if let remaining = matchPrefix(components: components.dropFirst(), afterNegation) {
					if !requiresCompleteMatch || remaining.isEmpty {
						return remaining
					}
				}
			}
		}

		return nil
	}

	private func isAtSegmentStart(_ name: Substring) -> Bool {
		name.isAtStart || name.previous() == options.pathSeparator
	}
}

private extension Substring {
	/// Returns the character just before the substring starts
	func previous() -> Character? {
		guard startIndex > base.startIndex else { return nil }
		let index = base.index(before: startIndex)

		return base[index]
	}

	/// returns an empty substring preserving endIndex
	func dropAll() -> Substring {
		self.suffix(0)
	}

	var isAtStart: Bool {
		startIndex == base.startIndex
	}
}
