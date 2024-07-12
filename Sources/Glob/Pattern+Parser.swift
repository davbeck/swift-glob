extension Pattern {
	struct Parser {
		private var pattern: Substring
		let options: Options

		init(pattern: some StringProtocol, options: Options) {
			self.pattern = Substring(pattern)
			self.options = options
		}

		enum Token: Equatable {
			case character(Character)
			case leftSquareBracket // [
			case righSquareBracket // ]
			case questionMark // ?
			case dash // -
			case asterisk // *
			case colon // :
			case leftParen // (
			case rightParen // )
			case verticalLine // |
			case at // @
			case plus // +
			case exclamationMark // !

			init(_ character: Character) {
				switch character {
				case "]":
					self = .righSquareBracket
				case "[":
					self = .leftSquareBracket
				case "?":
					self = .questionMark
				case "-":
					self = .dash
				case "*":
					self = .asterisk
				case ":":
					self = .colon
				case "(":
					self = .leftParen
				case ")":
					self = .rightParen
				case "|":
					self = .verticalLine
				case "@":
					self = .at
				case "+":
					self = .plus
				case "!":
					self = .exclamationMark
				default:
					self = .character(character)
				}
			}

			var character: Character {
				switch self {
				case let .character(character):
					character
				case .leftSquareBracket:
					"["
				case .righSquareBracket:
					"]"
				case .questionMark:
					"?"
				case .dash:
					"-"
				case .asterisk:
					"*"
				case .colon:
					":"
				case .leftParen:
					"("
				case .rightParen:
					")"
				case .verticalLine:
					"|"
				case .at:
					"@"
				case .plus:
					"+"
				case .exclamationMark:
					"!"
				}
			}
		}

		mutating func pop(_ condition: (Token) -> Bool = { _ in true }) throws -> Token? {
			if let next = pattern.first {
				let updatedPattern = pattern.dropFirst()

				if options.allowEscapedCharacters, next == .escape {
					guard let escaped = updatedPattern.first else { throw PatternParsingError.invalidEscapeCharacter }

					guard condition(.character(escaped)) else { return nil }

					pattern = updatedPattern.dropFirst()
					return .character(escaped)
				} else {
					let token = Token(next)

					guard condition(token) else { return nil }

					pattern = updatedPattern
					return token
				}
			}

			return nil
		}

		mutating func pop(_ token: Token) throws -> Bool {
			try pop { $0 == token } != nil
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

		private mutating func parseSections(delimeters: some Collection<Token> = EmptyCollection()) throws -> [Section] {
			var sections: [Section] = []

			while let next = try pop({ !delimeters.contains($0) }) {
				switch next {
				case .asterisk:
					if options.useExtendedMatching, let sectionList = try parsePatternList() {
						sections.append(.patternList(.zeroOrMore, sectionList))
					} else if sections.last == .componentWildcard {
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
				case .questionMark:
					if options.useExtendedMatching, let sectionList = try parsePatternList() {
						sections.append(.patternList(.zeroOrOne, sectionList))
					} else {
						sections.append(.singleCharacter)
					}
				case .at:
					if options.useExtendedMatching, let sectionsList = try parsePatternList() {
						sections.append(.patternList(.one, sectionsList))
					} else {
						sections.append(constant: next.character)
					}
				case .plus:
					if options.useExtendedMatching, let sectionsList = try parsePatternList() {
						sections.append(.patternList(.oneOrMore, sectionsList))
					} else {
						sections.append(constant: next.character)
					}
				case .exclamationMark:
					if options.useExtendedMatching, let sectionsList = try parsePatternList() {
						sections.append(.patternList(.negated, sectionsList))
					} else {
						sections.append(constant: next.character)
					}
				case .leftSquareBracket:
					let negated: Bool
					if pattern.first == options.rangeNegationCharacter {
						negated = true
						pattern = pattern.dropFirst()
					} else {
						negated = false
					}

					var ranges: [CharacterClass] = []

					if options.emptyRangeBehavior == .treatClosingBracketAsCharacter, try pop(.righSquareBracket) {
						// https://man7.org/linux/man-pages/man7/glob.7.html
						// The string enclosed by the brackets cannot be empty; therefore ']' can be allowed between the brackets, provided that it is the first character.
						ranges.append(.character("]"))
					}

					loop: while true {
						guard let next = try pop() else {
							throw PatternParsingError.rangeNotClosed
						}

						switch next {
						case .righSquareBracket:
							break loop
						case .leftSquareBracket:
							if try pop(.colon) {
								// Named character classes
								guard let endIndex = pattern.firstIndex(of: ":") else { throw PatternParsingError.rangeNotClosed }

								let name = pattern.prefix(upTo: endIndex)

								if let name = CharacterClass.Name(rawValue: String(name)) {
									ranges.append(.named(name))
									pattern = pattern[endIndex...].dropFirst()

									if try !pop(.righSquareBracket) {
										throw PatternParsingError.rangeNotClosed
									}
								} else {
									throw PatternParsingError.invalidNamedCharacterClass(String(name))
								}
							} else {
								ranges.append(.character("["))
							}
						case .dash:
							if !options.allowsRangeSeparatorInCharacterClasses {
								throw PatternParsingError.rangeMissingBounds
							}

							// https://man7.org/linux/man-pages/man7/glob.7.html
							// One may include '-' in its literal meaning by making it the first or last character between the brackets.
							ranges.append(.character("-"))
						default:
							if try pop(.dash) {
								if try pop(.righSquareBracket) {
									if !options.allowsRangeSeparatorInCharacterClasses {
										throw PatternParsingError.rangeNotClosed
									}

									// `-` is the last character in the group, treat it as a character
									// https://man7.org/linux/man-pages/man7/glob.7.html
									// One may include '-' in its literal meaning by making it the first or last character between the brackets.
									ranges.append(.character(next.character))
									ranges.append(.character("-"))

									break loop
								} else {
									// this is a range like a-z, find the upper limit of the range
									guard
										let upper = try pop()
									else { throw PatternParsingError.rangeNotClosed }

									guard next.character <= upper.character else { throw PatternParsingError.rangeBoundsAreOutOfOrder }
									ranges.append(.range(next.character ... upper.character))
								}
							} else {
								ranges.append(.character(next.character))
							}
						}
					}

					guard !ranges.isEmpty else {
						if options.emptyRangeBehavior == .error {
							throw PatternParsingError.rangeIsEmpty
						} else {
							break
						}
					}

					sections.append(.oneOf(ranges, isNegated: negated))
				case let .character(character):
					sections.append(constant: character)
				case .righSquareBracket, .dash, .colon, .leftParen, .rightParen, .verticalLine:
					sections.append(constant: next.character)
				}
			}

			return sections
		}

		/// Parses a pattern list like `(abc|xyz)`
		mutating func parsePatternList() throws -> [[Section]]? {
			if options.useExtendedMatching, try pop(.leftParen) {
				// start of pattern list
				var sectionsList: [[Section]] = []

				loop: while !pattern.isEmpty {
					let subSections = try self.parseSections(delimeters: [.verticalLine, .rightParen])

					sectionsList.append(subSections)

					switch try pop() {
					case .verticalLine:
						continue
					case .rightParen:
						break loop
					default:
						throw PatternParsingError.patternListNotClosed
					}
				}

				guard !sectionsList.isEmpty else {
					throw PatternParsingError.emptyPatternList
				}

				return sectionsList
			} else {
				return nil
			}
		}
	}
}

private extension [Pattern.Section] {
	mutating func append(constant character: Character) {
		if case let .constant(value) = self.last {
			self[self.endIndex - 1] = .constant(value + String(character))
		} else {
			self.append(.constant(String(character)))
		}
	}
}
