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

		switch (components.first, components.last) {
		case let (.constant(constant), _):
			if let remaining = name.dropPrefix(constant) {
				return match(
					components: components.dropFirst(),
					remaining
				)
			} else {
				return false
			}
		case (.singleCharacter, _):
			guard name.first != options.pathSeparator else { return false }
			return match(
				components: components.dropFirst(),
				name.dropFirst()
			)
		case let (.oneOf(ranges, isNegated: isNegated), _):
			guard let next = name.first, ranges.contains(where: { $0.contains(next) }) == !isNegated else { return false }
			return match(
				components: components.dropFirst(),
				name.dropFirst()
			)
		case let (_, .constant(constant)):
			if let remaining = name.dropSuffix(constant) {
				return match(
					components: components.dropLast(),
					remaining
				)
			} else {
				return false
			}
		case (_, .singleCharacter):
			guard name.last != options.pathSeparator else { return false }
			return match(
				components: components.dropLast(),
				name.dropLast()
			)
		case let (_, .oneOf(ranges, isNegated: isNegated)):
			guard let next = name.last, ranges.contains(where: { $0.contains(next) }) == !isNegated else { return false }
			return match(
				components: components.dropLast(),
				name.dropLast()
			)
		case (.componentWildcard, _):
			if components.count == 1 {
				// the last component is a component level wildcard, which matches anything except for the path separator
				return !name.contains(options.pathSeparator)
			}

			if match(components: components.dropFirst(), name) {
				return true
			} else {
				return match(components: components, name.dropFirst())
			}
		case (_, .componentWildcard):
			if match(components: components.dropLast(), name) {
				return true
			} else {
				return match(components: components, name.dropLast())
			}
		case (.pathWildcard, _):
			if components.count == 1 {
				// the last component is a path level wildcard, which matches anything
				return true
			}

			if match(components: components.dropFirst(), name) {
				return true
			} else {
				return match(components: components, name.dropFirst())
			}
		case (.none, _):
			return name.isEmpty
		}
	}
}
