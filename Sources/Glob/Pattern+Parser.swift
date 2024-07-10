extension Pattern {
	struct Parser {
		private var pattern: Substring
		let options: Options

		init(pattern: some StringProtocol, options: Options) {
			self.pattern = Substring(pattern)
			self.options = options
		}

		mutating func getNext(_ condition: ((character: Character, isEscaped: Bool)) -> Bool = { _ in true }) throws -> (character: Character, isEscaped: Bool)? {
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

		mutating func parse() throws -> Pattern {
			do {
				let sections = try self.parseSections()

				return Pattern(sections: sections, options: options)
			} catch let error as PatternParsingError {
				// add information about where the error was encountered by including the original pattern and our current location
				throw InvalidPatternError(
					pattern: pattern.base,
					location: pattern.startIndex,
					underlyingError: error
				)
			}
		}

		private mutating func parseSections(delimeters: some Collection<Character> = EmptyCollection()) throws -> [Section] {
			var sections: [Section] = []

			while let next = try getNext() {
				switch next {
				case ("*", false):
					if sections.last == .componentWildcard {
						if options.allowsPathLevelWildcards {
							sections[sections.endIndex - 1] = .pathWildcard
						} else {
							break // ignore repeated wildcards
						}
					} else if sections.last == .pathWildcard {
						break // ignore repeated wildcards
					} else {
						sections.append(.componentWildcard)
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
					if case let .constant(value) = sections.last {
						sections[sections.endIndex - 1] = .constant(value + String(next.character))
					} else {
						sections.append(.constant(String(next.character)))
					}
				}
			}

			return sections
		}
	}
}
