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
		match(components: .init(sections), .init(name), isAtStart: true)
	}

	// recursively matches against the pattern
	private func match(
		components: ArraySlice<Section>,
		_ name: Substring,
		isAtStart: Bool
	) -> Bool {
		if name.isEmpty {
			if components.isEmpty || (components.count == 1 && components.first?.isWildcard == true) {
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
		case let (.constant(constant), _, _):
			if let remaining = name.dropPrefix(constant) {
				return match(
					components: components.dropFirst(),
					remaining,
					isAtStart: constant.last == options.pathSeparator
				)
			} else {
				return false
			}
		case (.singleCharacter, _, _):
			guard name.first != options.pathSeparator else { return false }
			if options.requiresExplicitLeadingPeriods && isAtStart && name.first == "." {
				return false
			}

			return match(
				components: components.dropFirst(),
				name.dropFirst(),
				isAtStart: false
			)
		case let (.oneOf(ranges, isNegated: isNegated), _, _):
			if options.requiresExplicitLeadingPeriods && isAtStart && name.first == "." {
				// https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_13_01
				// It is unspecified whether an explicit <period> in a bracket expression matching list, such as "[.abc]", can match a leading <period> in a filename.
				// in our implimentation, it will not match
				return false
			}

			guard let next = name.first, ranges.contains(where: { $0.contains(next) }) == !isNegated else { return false }
			return match(
				components: components.dropFirst(),
				name.dropFirst(),
				isAtStart: next == options.pathSeparator
			)
		case let (_, .constant(constant), false):
			if let remaining = name.dropSuffix(constant) {
				return match(
					components: components.dropLast(),
					remaining,
					isAtStart: isAtStart
				)
			} else {
				return false
			}
		case (_, .singleCharacter, false):
			guard name.last != options.pathSeparator else { return false }
			return match(
				components: components.dropLast(),
				name.dropLast(),
				isAtStart: isAtStart
			)
		case let (_, .oneOf(ranges, isNegated: isNegated), false):
			guard let next = name.last, ranges.contains(where: { $0.contains(next) }) == !isNegated else { return false }
			return match(
				components: components.dropLast(),
				name.dropLast(),
				isAtStart: isAtStart
			)
		case (.componentWildcard, _, _):
			if options.requiresExplicitLeadingPeriods && isAtStart && name.first == "." {
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

			if match(components: components.dropFirst(), name, isAtStart: isAtStart) {
				return true
			} else {
				let next = name.first
				return match(components: components, name.dropFirst(), isAtStart: next == options.pathSeparator)
			}
		case (_, .componentWildcard, false):
			if match(components: components.dropLast(), name, isAtStart: isAtStart) {
				return true
			} else {
				return match(components: components, name.dropLast(), isAtStart: isAtStart)
			}
		case (.pathWildcard, _, _):
			if components.count == 1 {
				// the last component is a path level wildcard, which matches anything
				return true
			}

			if match(components: components.dropFirst(), name, isAtStart: isAtStart) {
				return true
			} else {
				let next = name.first
				return match(components: components, name.dropFirst(), isAtStart: next == options.pathSeparator)
			}
		case (.none, _, _):
			if options.matchLeadingDirectories && name.first == options.pathSeparator {
				return true
			}

			return name.isEmpty
		}
	}
}
