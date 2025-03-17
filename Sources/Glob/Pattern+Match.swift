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
	/// - Returns: true if the string matches the pattern
	public func match(_ name: some StringProtocol) -> Bool {
		match(components: .init(sections), .init(name))
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

		while true {
			if name.isEmpty {
				if components.isEmpty || components.allSatisfy(\.matchesEmptyContent) {
					return true
				} else if components.contains(.pathWildcard) && components.allSatisfy({ $0 == .pathSeparator || $0.matchesEmptyContent }) {
					// match foo/**/bar to foo/bar
					return true
				} else {
					return false
				}
			}

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
				if options.requiresExplicitLeadingPeriods && isAtStart(name) && name.first == "." {
					return false
				}

				components = components.dropFirst()
				name = name.dropFirst()
			case let (.oneOf(ranges, isNegated: isNegated), _, _):
				if options.requiresExplicitLeadingPeriods && isAtStart(name) && name.first == "." {
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
				if options.requiresExplicitLeadingPeriods && isAtStart(name) && name.first == "." {
					return false
				}

				if components.count == 1 {
					if let pathSeparator = options.pathSeparator, !options.matchLeadingDirectories {
						// the last component is a component level wildcard, which matches anything except for the path separator
						return !name.contains(pathSeparator) || (options.matchesTrailingPathSeparator && name.endIndex == name.base.endIndex && name.dropSuffix(String(pathSeparator))?.contains(pathSeparator) == false)
					} else {
						// no special treatment for path separators
						return true
					}
				}

				if match(components: components.dropFirst(), name) {
					return true
				} else {
					// components remain unchanged
					name = name.dropFirst()
				}
			case (_, .componentWildcard, false):
				if match(components: components.dropLast(), name) {
					return true
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
				} else {
					// components remain unchanged
					name = name.dropFirst()
				}
			case let (.patternList(style, subSections), _, _):
				let remaining = matchPatternListPrefix(
					components: components,
					name,
					style: style,
					subSections: subSections
				)

				return remaining?.isEmpty == true
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
			if options.requiresExplicitLeadingPeriods && isAtStart(name) {
				return nil
			}

			return matchPrefix(
				components: components.dropFirst(),
				name.dropFirst()
			)
		case let .oneOf(ranges, isNegated: isNegated):
			if options.requiresExplicitLeadingPeriods && isAtStart(name) {
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
			if options.requiresExplicitLeadingPeriods && isAtStart(name) {
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
		subSections: [[Section]]
	) -> Substring? {
		for sectionsOption in subSections {
			if let remaining = matchPrefix(
				components: ArraySlice(sectionsOption + components.dropFirst()),
				name
			) {
				// stop infinite recursion
				guard remaining != name else { return remaining }

				switch style {
				case .negated:
					return nil
				case .oneOrMore, .zeroOrMore:
					// switch to zeroOrMore since we've already fulfilled the "one" requirement
					return matchPrefix(
						components: [.patternList(.zeroOrMore, subSections)] + components.dropFirst(),
						remaining
					)
				case .one, .zeroOrOne:
					// already matched "one", can't match any more
					return remaining
				}
			}
		}

		switch style {
		case .negated:
			return matchPrefix(components: [.pathWildcard] + components.dropFirst(), name)
		case .zeroOrMore, .zeroOrOne:
			return matchPrefix(components: components.dropFirst(), name)
		case .one, .oneOrMore:
			return nil
		}
	}

	private func isAtStart(_ name: Substring) -> Bool {
		name.startIndex == name.base.startIndex || name.previous() == options.pathSeparator
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
}
