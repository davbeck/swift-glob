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
						.allSatisfy(\.properties.generalCategory.isPrintable)
				case .lower:
					character.isLowercase
				case .printable:
					character.unicodeScalars
						.allSatisfy(\.properties.generalCategory.isPrintable)
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
			func getNext(_ condition: ((character: Character, isEscaped: Bool)) -> Bool = { _ in true }) throws -> (character: Character, isEscaped: Bool)? {
				if let next = pattern.first {
					let updatedPattern = pattern.dropFirst()

					if options.allowEscapedCharacters, next == .escape {
						guard let escaped = updatedPattern.first else { throw PatternParsingError.invalidEscapeCharacter }

						guard condition((escaped, true)) else { return nil }

						pattern = updatedPattern.dropFirst()
						return (escaped, true)
					} else {
						guard condition((next, false)) else { return nil }

						pattern = updatedPattern
						return (next, false)
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

			while let next = try getNext() {
				switch next {
				case ("*", false):
					if sections.last == .componentWildcard {
						if options.wildcardBehavior == .doubleStarMatchesFullPath {
							sections[sections.endIndex - 1] = .pathWildcard
						} else {
							break // ignore repeated wildcards
						}
					} else if sections.last == .pathWildcard {
						break // ignore repeated wildcards
					} else {
						if options.wildcardBehavior == .singleStarMatchesFullPath {
							sections.append(.pathWildcard)
						} else {
							sections.append(.componentWildcard)
						}
					}
				case ("?", false):
					sections.append(.singleCharacter)
				case ("[", false):
					let negated: Bool
					if pattern.first == options.rangeNegationCharacter {
						negated = true
						pattern = pattern.dropFirst()
					} else {
						negated = false
					}

					var ranges: [CharacterClass] = []

					if options.emptyRangeBehavior == .treatClosingBracketAsCharacter, let closing = try getNext({ !$0.isEscaped && $0.character == "]" }) {
						// https://man7.org/linux/man-pages/man7/glob.7.html
						// The string enclosed by the brackets cannot be empty; therefore ']' can be allowed between the brackets, provided that it is the first character.
						ranges.append(.character(closing.character))
					}

					while let next = try getNext({ $0.isEscaped || $0.character != "]" }) {
						if !next.isEscaped && next.character == "[" {
							if try getNext({ !$0.isEscaped && $0.character == ":" }) != nil {
								// Named character classes
								guard let endIndex = pattern.firstIndex(of: ":") else { throw PatternParsingError.rangeNotClosed }

								let name = pattern.prefix(upTo: endIndex)

								if let name = CharacterClass.Name(rawValue: String(name)) {
									ranges.append(.named(name))
									pattern = pattern[endIndex...].dropFirst()

									if try getNext({ !$0.isEscaped && $0.character == "]" }) == nil {
										throw PatternParsingError.rangeNotClosed
									}
								} else {
									throw PatternParsingError.invalidNamedCharacterClass(String(name))
								}
							} else {
								ranges.append(.character("["))
							}
						} else if !next.isEscaped && next.character == "-" {
							if !options.allowsRangeSeparatorInCharacterClasses {
								throw PatternParsingError.rangeMissingBounds
							}

							// https://man7.org/linux/man-pages/man7/glob.7.html
							// One may include '-' in its literal meaning by making it the first or last character between the brackets.
							ranges.append(.character("-"))
						} else {
							if try getNext({ !$0.isEscaped && $0.character == "-" }) != nil {
								if pattern.first == "]" {
									if !options.allowsRangeSeparatorInCharacterClasses {
										throw PatternParsingError.rangeNotClosed
									}

									// `-` is the last character in the group, treat it as a character
									// https://man7.org/linux/man-pages/man7/glob.7.html
									// One may include '-' in its literal meaning by making it the first or last character between the brackets.
									ranges.append(.character(next.character))
									ranges.append(.character("-"))
								} else {
									// this is a range like a-z, find the upper limit of the range
									guard
										let upper = try getNext()
									else { throw PatternParsingError.rangeNotClosed }

									guard next.character <= upper.character else { throw PatternParsingError.rangeBoundsAreOutOfOrder }
									ranges.append(.range(next.character ... upper.character))
								}
							} else {
								ranges.append(.character(next.character))
							}
						}
					}

					guard try getNext({ !$0.isEscaped && $0.character == "]" }) != nil else { throw PatternParsingError.rangeNotClosed }

					guard !ranges.isEmpty else {
						if options.emptyRangeBehavior == .error {
							throw PatternParsingError.rangeIsEmpty
						} else {
							break
						}
					}

					sections.append(.oneOf(ranges, isNegated: negated))
				default:
					appendConstant(next.character)
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
