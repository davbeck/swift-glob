import Foundation

extension Character {
	static let escape: Character = #"\"#
}

/// A glob pattern that can be matched against string content.
public struct Pattern: Equatable, Sendable {
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

		case pathSeparator

		public enum PatternListStyle: Equatable, Sendable {
			case zeroOrOne
			case zeroOrMore
			case oneOrMore
			case one
			case negated

			var allowsZero: Bool {
				switch self {
				case .zeroOrOne, .zeroOrMore, .negated:
					true
				case .oneOrMore, .one:
					false
				}
			}

			var allowsMultiple: Bool {
				switch self {
				case .oneOrMore, .zeroOrMore:
					true
				case .zeroOrOne, .one, .negated:
					false
				}
			}
		}

		case patternList(_ style: PatternListStyle, _ sections: [[Section]])

		/// If the section can match a variable length of characters
		///
		/// When false, the section represents a fixed length match.
		public var matchesEmptyContent: Bool {
			switch self {
			case .constant, .singleCharacter, .oneOf, .pathSeparator:
				false
			case .componentWildcard, .pathWildcard:
				true
			case let .patternList(style, subSections):
				switch style {
				case .negated, .zeroOrOne, .zeroOrMore:
					true
				case .one, .oneOrMore:
					subSections.contains(where: { subSection in
						subSection.allSatisfy { section in
							section.matchesEmptyContent
						}
					})
				}
			}
		}
	}

	/// Represents a character class for use in bracket expressions.
	///
	/// Character classes can be:
	/// - A range of characters (e.g., `a-z` becomes `.range("a"..."z")`)
	/// - A named POSIX class (e.g., `[:alpha:]` becomes `.named(.alpha)`)
	///
	/// ## Limitations
	///
	/// ### Equivalence Classes
	/// POSIX equivalence classes (e.g., `[[=a=]]`) are parsed but only match the literal character.
	/// Full locale-aware equivalence matching (where `[[=a=]]` would match 'a', 'á', 'à', 'ä', etc.)
	/// is not supported. This matches behavior in the C locale.
	///
	/// ### Collating Symbols
	/// Collating symbols (e.g., `[[.ch.]]`) are parsed but only match single characters.
	/// Multi-character collating elements are not supported.
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
	///
	/// When brace expansion is used, this returns the sections of the first alternative.
	/// Use `alternatives` to access all expanded patterns.
	public var sections: [Section] {
		get { alternatives.first ?? [] }
		set { alternatives = [newValue] }
	}

	/// All pattern alternatives after brace expansion.
	///
	/// When brace expansion is not used or the pattern contains no braces,
	/// this contains a single element.
	public var alternatives: [[Section]]

	/// Options used for parsing and matching
	public var options: Options

	init(sections: [Section], options: Options) {
		self.alternatives = [sections]
		self.options = options
	}

	init(alternatives: [[Section]], options: Options) {
		self.alternatives = alternatives
		self.options = options
	}

	/// Parses a pattern string into a reusable pattern
	public init(
		_ pattern: some StringProtocol,
		options: Options = .default
	) throws {
		if options.supportsBraceExpansion {
			let expandedPatterns = BraceExpansion.expand(
				String(pattern),
				supportsEscapedCharacters: options.supportsEscapedCharacters
			)

			var allAlternatives: [[Section]] = []
			for expandedPattern in expandedPatterns {
				var parser = Parser(pattern: expandedPattern, options: options)
				let parsed = try parser.parse()
				allAlternatives.append(contentsOf: parsed.alternatives)
			}

			self.alternatives = allAlternatives
			self.options = options
		} else {
			var parser = Parser(pattern: pattern, options: options)
			self = try parser.parse()
		}
	}
}
