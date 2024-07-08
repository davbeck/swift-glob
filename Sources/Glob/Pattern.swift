import Foundation

extension Character {
	static let escape: Character = #"\"#
}

/// A glob pattern that can be matched against string content.
public struct Pattern: Sendable {
	public enum Section: Equatable, Sendable {
		/// A wildcard that matches any 0 or more characters except for the path separator ("/" by default)
		case componentWildcard
		/// A wildcard that matches any 0 or more characters
		case pathWildcard

		/// Matches an exact string
		case constant(String)
		/// Matches any single character
		case singleCharacter
		/// Matches a single character in any of the given ranges
		///
		/// A range may be a single character (ie "a"..."a"). For instance the pattern [abc] will create 3 ranges that are each a single character.
		case oneOf([ClosedRange<Character>], isNegated: Bool)

		/// If the section can match a variable length of characters
		///
		/// When false, the section represents a fixed length match.
		public var isWildcard: Bool {
			switch self {
			case .constant, .singleCharacter, .oneOf:
				false
			case .componentWildcard, .pathWildcard:
				true
			}
		}
	}

	/// The individual parts of the pattern to match against
	public var sections: [Section]
	/// Options used for parsing and matching
	public var options: Options

	/// Parses a pattern string into a reusable pattern
	public init(
		_ pattern: some StringProtocol,
		options: Options = .default
	) throws {
		var pattern = Substring(pattern)
		var sections: [Section] = []

		do {
			func getNext() throws -> Character? {
				if let next = pattern.first {
					pattern = pattern.dropFirst()

					if next == .escape {
						guard let escaped = pattern.first else { throw PatternParsingError.invalidEscapeCharacter }
						pattern = pattern.dropFirst()

						return escaped
					} else {
						return next
					}
				}

				return nil
			}

			func appendConstant(_ next: Character) {
				if case let .constant(value) = sections.last {
					sections[sections.endIndex - 1] = .constant(value + String(next))
				} else {
					sections.append(.constant(String(next)))
				}
			}

			while let next = pattern.first {
				pattern = pattern.dropFirst()

				switch next {
				case "*":
					if sections.last == .componentWildcard {
						if options.wildcardBehavior == .doubleStarMatchesFullPath {
							sections[sections.endIndex - 1] = .pathWildcard
						} else {
							break // ignore repeated wildcards
						}
					} else if sections.last == .pathWildcard {
						break // ignore repeated wildcards
					} else {
						sections.append(.componentWildcard)
					}
				case "?":
					sections.append(.singleCharacter)
				case "[":
					let negated: Bool
					if pattern.first == options.rangeNegationCharacter {
						negated = true
						pattern = pattern.dropFirst()
					} else {
						negated = false
					}

					var ranges: [ClosedRange<Character>] = []

					if options.emptyRangeBehavior == .treatClosingBracketAsCharacter && pattern.first == "]" {
						// https://man7.org/linux/man-pages/man7/glob.7.html
						// The string enclosed by the brackets cannot be empty; therefore ']' can be allowed between the brackets, provided that it is the first character.
						
						pattern = pattern.dropFirst()
						ranges.append("]" ... "]")
					}

					while pattern.first != "]" {
						guard pattern.first != "-" else { throw PatternParsingError.rangeMissingBounds }
						guard let lower = try getNext() else { break }

						if pattern.first == "-" {
							// this is a range like a-z, find the upper limit of the range
							pattern = pattern.dropFirst()

							guard
								pattern.first != "]",
								let upper = try getNext()
							else { throw PatternParsingError.rangeNotClosed }

							guard lower <= upper else { throw PatternParsingError.rangeBoundsAreOutOfOrder }
							ranges.append(lower ... upper)
						} else {
							ranges.append(lower ... lower)
						}
					}

					guard pattern.first == "]" else { throw PatternParsingError.rangeNotClosed }
					pattern = pattern.dropFirst()

					guard !ranges.isEmpty else {
						if options.emptyRangeBehavior == .error {
							throw PatternParsingError.rangeIsEmpty
						} else {
							break
						}
					}

					sections.append(.oneOf(ranges, isNegated: negated))
				case #"\"#:
					guard let next = pattern.first else { throw PatternParsingError.invalidEscapeCharacter }
					pattern = pattern.dropFirst()
					appendConstant(next)
				default:
					appendConstant(next)
				}
			}

			self.sections = sections
			self.options = options
		} catch let error as PatternParsingError {
			// add information about where the error was encountered by including the original pattern and our current location
			throw InvalidPatternError(
				pattern: pattern.base,
				location: pattern.startIndex,
				underlyingError: error
			)
		}
	}
}
