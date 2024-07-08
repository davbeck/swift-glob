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
		case oneOf([CharacterClass], isNegated: Bool)

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

	public enum CharacterClass: Equatable, Sendable {
		case range(ClosedRange<Character>)

		public enum Name: String, Equatable, Sendable {
			// https://man7.org/linux/man-pages/man7/glob.7.html
			// https://www.domaintools.com/resources/user-guides/dnsdb-glob-reference-guide/

			/// Alphanumeric characters 0-9, A-Z, and a-z
			case alphaNumeric = "alnum"
			/// Alphabetic characters A-Z, a-z
			case alpha
			/// Blank characters (space and tab)
			case blank
			/// Control characters
			case control = "cntrl"
			/// Decimal digits 0-9
			case numeric = "digit"
			/// Any printable character other than space.
			case graph
			/// Lower case alphabetic characters a-z
			case lower
			/// Any printable character
			case printable = "print"
			/// Printable characters other than space and `alphaNumeric`
			case punctuation = "punct"
			///  Any whitespace character
			case space
			/// Upper case alphabetic characters A-Z
			case upper
			/// Hexadecimal digits 0-9, a-f, A-F
			case hexadecimalDigit = "xdigit"

			public func contains(_ character: Character) -> Bool {
				switch self {
				case .alphaNumeric:
					character.isLetter || character.isNumber
				case .alpha:
					character.isLetter
				case .blank:
					character.isWhitespace
				case .control:
					character.unicodeScalars
						.allSatisfy { $0.properties.generalCategory == .control }
				case .numeric:
					character.isNumber
				case .graph:
					character != " " && character.unicodeScalars
						.allSatisfy { $0.properties.generalCategory.isPrintable }
				case .lower:
					character.isLowercase
				case .printable:
					character.unicodeScalars
						.allSatisfy { $0.properties.generalCategory.isPrintable }
				case .punctuation:
					character.isPunctuation
				case .space:
					character.isWhitespace
				case .upper:
					character.isUppercase
				case .hexadecimalDigit:
					character.isHexDigit
				}
			}
		}

		case named(Name)

		static func character(_ character: Character) -> Self {
			.range(character ... character)
		}

		public func contains(_ character: Character) -> Bool {
			switch self {
			case let .range(closedRange):
				closedRange.contains(character)
			case let .named(name):
				name.contains(character)
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

					var ranges: [CharacterClass] = []

					if options.emptyRangeBehavior == .treatClosingBracketAsCharacter && pattern.first == "]" {
						// https://man7.org/linux/man-pages/man7/glob.7.html
						// The string enclosed by the brackets cannot be empty; therefore ']' can be allowed between the brackets, provided that it is the first character.

						pattern = pattern.dropFirst()
						ranges.append(.character("]"))
					}

					while pattern.first != "]" {
						if pattern.first == "[" {
							pattern = pattern.dropFirst()

							if pattern.first == ":" {
								// Named character classes
								pattern = pattern.dropFirst()
								guard let endIndex = pattern.firstIndex(of: ":") else { throw PatternParsingError.rangeNotClosed }

								let name = pattern.prefix(upTo: endIndex)

								if let name = CharacterClass.Name(rawValue: String(name)) {
									ranges.append(.named(name))
									pattern = pattern[endIndex...].dropFirst()

									guard pattern.first == "]" else {
										throw PatternParsingError.rangeNotClosed
									}
									pattern = pattern.dropFirst()
								} else {
									throw PatternParsingError.invalidNamedCharacterClass(String(name))
								}
							} else {
								ranges.append(.character("["))
							}
						} else {
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
								ranges.append(.range(lower ... upper))
							} else {
								ranges.append(.range(lower ... lower))
							}
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
