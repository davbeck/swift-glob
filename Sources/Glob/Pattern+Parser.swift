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
			case rightSquareBracket // ]
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
			case caret // ^
			case period // .
			case equal // =

			init(_ character: Character) {
				switch character {
				case "]":
					self = .rightSquareBracket
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
				case "^":
					self = .caret
				case ".":
					self = .period
				case "=":
					self = .equal
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
				case .rightSquareBracket:
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
				case .caret:
					"^"
				case .period:
					"."
				case .equal:
					"="
				}
			}
		}

		mutating func pop(_ condition: (Token) -> Bool = { _ in true }) throws -> Token? {
			if let next = pattern.first {
				let updatedPattern = pattern.dropFirst()

				if options.supportsEscapedCharacters, next == .escape {
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

		mutating func pop(_ tokens: [Token]) throws -> Bool {
			let rollback = pattern

			for token in tokens {
				if try !self.pop(token) {
					pattern = rollback
					return false
				}
			}
			
			return true
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

		private mutating func parseSections(delimiters: some Collection<Token> = EmptyCollection()) throws -> [Section] {
			var sections: [Section] = []

			while let next = try pop({ !delimiters.contains($0) }) {
				switch next {
				case .asterisk:
					if options.supportsPatternLists, let sectionList = try parsePatternList() {
						sections.append(.patternList(.zeroOrMore, sectionList))
					} else if sections.last == .componentWildcard {
						if options.supportsPathLevelWildcards {
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
					if options.supportsPatternLists, let sectionList = try parsePatternList() {
						sections.append(.patternList(.zeroOrOne, sectionList))
					} else {
						sections.append(.singleCharacter)
					}
				case .at:
					if options.supportsPatternLists, let sectionsList = try parsePatternList() {
						sections.append(.patternList(.one, sectionsList))
					} else {
						sections.append(constant: next.character)
					}
				case .plus:
					if options.supportsPatternLists, let sectionsList = try parsePatternList() {
						sections.append(.patternList(.oneOrMore, sectionsList))
					} else {
						sections.append(constant: next.character)
					}
				case .exclamationMark:
					if options.supportsPatternLists, let sectionsList = try parsePatternList() {
						sections.append(.patternList(.negated, sectionsList))
					} else {
						sections.append(constant: next.character)
					}
				case .leftSquareBracket:
					try sections.append(contentsOf: self.parseOneOf())
				case let .character(character):
					if character == options.pathSeparator {
						sections.append(.pathSeparator)
					} else {
						sections.append(constant: character)
					}
				case .rightSquareBracket, .dash, .colon, .leftParen, .rightParen, .verticalLine, .caret, .period, .equal:
					sections.append(constant: next.character)
				}
			}

			return sections
		}

		private mutating func parseOneOf() throws -> [Section] {
			let negated: Bool
			if try pop(options.rangeNegationCharacter.token) {
				negated = true
			} else {
				negated = false
			}

			var ranges: [CharacterClass] = []

			if options.emptyRangeBehavior == .treatClosingBracketAsCharacter, try pop(.rightSquareBracket) {
				// https://man7.org/linux/man-pages/man7/glob.7.html
				// The string enclosed by the brackets cannot be empty; therefore ']' can be allowed between the brackets, provided that it is the first character.
				ranges.append(.character(.init("]")))
			}

			while true {
				if try pop(.rightSquareBracket) {
					break
				} else if try pop(.dash) {
					if !options.supportsRangeSeparatorAtBeginningAndEnd {
						throw PatternParsingError.rangeMissingBounds
					}

					// https://man7.org/linux/man-pages/man7/glob.7.html
					// One may include '-' in its literal meaning by making it the first or last character between the brackets.
					ranges.append(.character(.init("-")))
				} else if try pop([.leftSquareBracket, .colon]) {
					// Named character classes
					guard let endIndex = pattern.firstIndex(of: ":") else { throw PatternParsingError.rangeNotClosed }

					let name = pattern.prefix(upTo: endIndex)

					if let name = CharacterClass.Name(rawValue: String(name)) {
						ranges.append(.named(name))
						pattern = pattern[endIndex...].dropFirst()

						if try !pop(.rightSquareBracket) {
							throw PatternParsingError.rangeNotClosed
						}
					} else {
						throw PatternParsingError.invalidNamedCharacterClass(String(name))
					}
				} else {
					let lower = try parseCharacterBound()

					if try pop(.dash) {
						if try pop(.rightSquareBracket) {
							if !options.supportsRangeSeparatorAtBeginningAndEnd {
								throw PatternParsingError.rangeNotClosed
							}

							// `-` is the last character in the group, treat it as a character
							// https://man7.org/linux/man-pages/man7/glob.7.html
							// One may include '-' in its literal meaning by making it the first or last character between the brackets.
							ranges.append(.character(lower))
							ranges.append(.character(.init("-")))

							break
						} else {
							// this is a range like a-z, find the upper limit of the range
							let upper = try parseCharacterBound()

							ranges.append(.range(lower: lower, upper: upper))
						}
					} else {
						ranges.append(.character(lower))
					}
				}
			}

			guard !ranges.isEmpty else {
				if options.emptyRangeBehavior == .error {
					throw PatternParsingError.rangeIsEmpty
				} else {
					return []
				}
			}

			return [.oneOf(ranges, isNegated: negated)]
		}

		mutating func parseCharacterBound() throws -> CharacterClass.CharacterBound {
			guard let next = try pop() else {
				throw PatternParsingError.rangeNotClosed
			}

			if next == .leftSquareBracket {
				if try pop(.period) {
					// Named character classes
					guard let endIndex = pattern.firstIndex(of: ".") else { throw PatternParsingError.rangeNotClosed }

					let name = pattern.prefix(upTo: endIndex)

					guard let character = name.first, name.count == 1 else {
						throw PatternParsingError.multiCharacterCollatingElementsNotSupported
					}

					pattern = pattern[endIndex...].dropFirst()

					if try !pop(.rightSquareBracket) {
						throw PatternParsingError.rangeNotClosed
					}

					return .init(character)
				} else if try pop(.equal) {
					// Named character classes
					guard let endIndex = pattern.firstIndex(of: "=") else { throw PatternParsingError.rangeNotClosed }

					let name = pattern.prefix(upTo: endIndex)

					guard let character = name.first, name.count == 1 else {
						throw PatternParsingError.multiCharacterCollatingElementsNotSupported
					}

					pattern = pattern[endIndex...].dropFirst()

					if try !pop(.rightSquareBracket) {
						throw PatternParsingError.rangeNotClosed
					}

					return .init(character, matchesEquivalent: true)
				} else {
					return .init("[")
				}
			}

			return .init(next.character)
		}

		/// Parses a pattern list like `(abc|xyz)`
		mutating func parsePatternList() throws -> [[Section]]? {
			if options.supportsPatternLists, try pop(.leftParen) {
				// start of pattern list
				var sectionsList: [[Section]] = []

				loop: while !pattern.isEmpty {
					let subSections = try self.parseSections(delimiters: [.verticalLine, .rightParen])

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

extension Pattern.Options.RangeNegationCharacter {
	var token: Pattern.Parser.Token {
		switch self {
		case .exclamationMark:
			.exclamationMark
		case .caret:
			.caret
		}
	}
}
