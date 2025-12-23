import FNMDefinitions
import Foundation

// naming philosophy

// "allow" indicates that if it's not enabled, an error would be thrown
// "supports" indicates that if it's not enabled, it will be ignored and treated as normal input

public extension Pattern {
	/// Options to control how patterns are parsed and matched
	struct Options: Equatable, Sendable {
		/// If a double star/asterisk causes the pattern to match path separators.
		///
		/// If `pathSeparator` is `nil` this has no effect.
		public var supportsPathLevelWildcards: Bool = true

		/// How empty ranges (`[]`) are treated
		public enum EmptyRangeBehavior: Sendable {
			/// Treat an empty range as matching nothing, equivalent to nothing at all
			case allow
			/// Throw an error when an empty range is used
			case error
			/// When a range starts with a closing range character, treat the closing bracket as a character and continue the range
			case treatClosingBracketAsCharacter
		}

		/// How are empty ranges handled.
		public var emptyRangeBehavior: EmptyRangeBehavior = .error

		/// How unclosed bracket expressions (e.g., `[abc` with no closing `]`) are treated
		public enum UnclosedBracketBehavior: Sendable {
			/// Treat an unclosed bracket as a parsing error
			case error
			/// Treat an unclosed bracket as a literal `[` character
			case treatAsLiteral
		}

		/// How are unclosed brackets handled.
		///
		/// In fnmatch, an unclosed `[` is treated as a literal character. For example, the pattern `a[b`
		/// would match the string `a[b` literally.
		public var unclosedBracketBehavior: UnclosedBracketBehavior = .error

		/// If the pattern supports escaping control characters with `\`
		///
		/// When true, a backslash character (`\`) in pattern followed by any other character shall match that second character in string. In particular, `\\` shall match a backslash in string. Otherwise a backslash character shall be treated as an ordinary character.
		public var supportsEscapedCharacters: Bool = true

		/// Allows the `-` character to be included in a character class if it is the first or last character (ie `[-abc]` or `[abc-]`)
		public var supportsRangeSeparatorAtBeginningAndEnd: Bool = true

		/// If a period in the name is at the beginning of a component (ie hidden files), don't match using wildcards.
		///
		/// Treat the `.` character specially if it appears at the beginning of string. If this flag is set, wildcard constructs in pattern cannot match `.` as the first character of string. If you set both this and `pathSeparator`, then the special treatment applies to `.` following `pathSeparator` as well as to `.` at the beginning of string.
		///
		/// Equivalent to `FNM_PERIOD`.
		public var requiresExplicitLeadingPeriods: Bool = true

		/// If a pattern should match if it matches a parent directory, as defined by `pathSeparator`.
		///
		/// Ignore a trailing sequence of characters starting with a `/` in string; that is to say, test whether string starts with a directory name that pattern matches. If this flag is set, either `foo*` or `foobar` as a pattern would match the string `foobar/frobozz`. Equivalent to `FNM_LEADING_DIR`.`
		///
		/// If `pathSeparator` is `nil` this has no effect.
		public var matchLeadingDirectories: Bool = false

		/// Recognize beside the normal patterns also the extended patterns introduced in `ksh`. Equivalent to `FNM_EXTMATCH`.
		///
		/// The patterns are written in the form explained in the following table where pattern-list is a | separated list of patterns.
		///
		/// - ?(pattern-list)
		/// 	The pattern matches if zero or one occurences of any of the patterns in the pattern-list allow matching the input string.
		/// - *(pattern-list)
		/// 	The pattern matches if zero or more occurences of any of the patterns in the pattern-list allow matching the input string.
		/// - +(pattern-list)
		/// 	The pattern matches if one or more occurences of any of the patterns in the pattern-list allow matching the input string.
		/// - @(pattern-list)
		/// 	The pattern matches if exactly one occurence of any of the patterns in the pattern-list allows matching the input string.
		/// - !(pattern-list)
		/// 	The pattern matches if the input string cannot be matched with any of the patterns in the pattern-list.
		public var supportsPatternLists: Bool = true

		/// Recognize brace expansion syntax like `{a,b,c}`.
		///
		/// When enabled, patterns containing braces are expanded into multiple alternative patterns.
		/// For example, `*.{js,ts}` expands to match either `*.js` or `*.ts`.
		///
		/// Examples:
		/// - `{a,b,c}` matches "a", "b", or "c"
		/// - `*.{html,js}` matches files ending in ".html" or ".js"
		/// - `{foo,bar}/**` matches anything under "foo/" or "bar/"
		/// - `{**/*.js,**/*.ts}` matches any .js or .ts file
		///
		/// Note: This is different from ksh-style pattern lists (`@(a|b)`) which are handled by `supportsPatternLists`.
		/// Brace expansion is a pre-processing step that creates multiple patterns, while pattern lists are
		/// evaluated during matching.
		public var supportsBraceExpansion: Bool = false

		/// The character used to invert a character class.
		public enum RangeNegationCharacter: Equatable, Sendable {
			/// Use the `!` character to denote an inverse character class.
			case exclamationMark
			/// Use the `^` character to denote an inverse character class.
			case caret
			/// Use either `!` or `^` to denote an inverse character class.
			case both
		}

		/// The character used to specify when a range matches characters that aren't in the range.
		public var rangeNegationCharacter: RangeNegationCharacter = .exclamationMark

		/// The path separator to use in matching
		///
		/// If this is `nil`, path separators have no special meaning. This is equivalent to excluding `FNM_PATHNAME` in `fnmatch`.
		///
		/// Defaults to "/" regardless of operating system.
		public var pathSeparator: Character? = "/"

		/// Additional characters that should be treated as path separators in the input string.
		///
		/// This is useful for matching Windows-style paths where both `/` and `\` should be treated as path separators.
		/// Note: These characters are only recognized as path separators in the input string being matched,
		/// not in the pattern itself.
		public var additionalPathSeparators: Set<Character> = []

		/// Returns true if the given character is a path separator (either the primary or an additional one)
		public func isPathSeparator(_ character: Character?) -> Bool {
			guard let character else { return false }
			if let pathSeparator, character == pathSeparator {
				return true
			}
			return additionalPathSeparators.contains(character)
		}

		/// If true, bracket expressions cannot match path separators even if they explicitly contain them.
		///
		/// For example, with this option enabled, `foo[/]bar` will NOT match `foo/bar` because
		/// path separators cannot be matched within bracket expressions.
		/// This matches VSCode's glob behavior.
		public var bracketExpressionsCannotMatchPathSeparators: Bool = false

		/// If a trailing path separator in the search string will be ignored if it's not explicitly matched.
		///
		/// This allows patterns to match against a directory or a regular file. For instance "foo*" will match both "foo_file" and "foo_dir/" if this is enabled.
		public var matchesTrailingPathSeparator: Bool = true

		/// If a trailing `/**` in a pattern requires at least one path component to match.
		///
		/// When true (Fish shell behavior), the pattern `foo/**` will NOT match `foo` or `foo/` because
		/// the trailing `/**` must match at least one component.
		///
		/// When false (VSCode behavior), the pattern `foo/**` will match `foo`, `foo/`, and `foo/bar`
		/// because the trailing `/**` can match zero or more path components.
		///
		/// This only affects trailing `/**` patterns. Mid-pattern `/**/` (like `foo/**/bar`) can always
		/// match zero path components regardless of this setting.
		public var trailingPathWildcardRequiresComponent: Bool = true

		/// If character ranges should use diacritic-insensitive comparison.
		///
		/// When enabled, character ranges like `[a-z]` will match accented characters like `ä`, `ö`, `ü`
		/// because they are compared as their base characters (`a`, `o`, `u`). This provides locale-like
		/// behavior for character ranges without requiring full locale support.
		///
		/// This is useful for matching glibc fnmatch behavior in German and other locales where accented
		/// characters are expected to fall within the `[a-z]` range.
		///
		/// Note: This only affects character ranges, not equivalence classes or named character classes.
		public var diacriticInsensitiveRanges: Bool = false

		/// Default options for parsing and matching patterns.
		public static let `default`: Self = .init()

		/// Attempts to match the behavior of [VSCode](https://code.visualstudio.com/docs/editor/glob-patterns).
		public static let vscode: Self = Options(
			supportsPathLevelWildcards: true,
			emptyRangeBehavior: .treatClosingBracketAsCharacter,
			supportsPatternLists: false,
			supportsBraceExpansion: true,
			rangeNegationCharacter: .both,
			additionalPathSeparators: ["\\"],
			bracketExpressionsCannotMatchPathSeparators: true,
			trailingPathWildcardRequiresComponent: false
		)

		/// Attempts to match the behavior of [`filepath.Match` in go](https://pkg.go.dev/path/filepath#Match).
		public static let go: Self = Options(
			supportsPathLevelWildcards: false,
			emptyRangeBehavior: .error,
			supportsRangeSeparatorAtBeginningAndEnd: false,
			rangeNegationCharacter: .caret
		)

		/// Options matching [zsh shell behavior](https://zsh.sourceforge.io/Doc/Release/Expansion.html).
		static let zsh: Self = {
			var options = Pattern.Options.default
			options.supportsPatternLists = true
			options.rangeNegationCharacter = .both
			return options
		}()

		/// Attempts to match the behavior of [POSIX glob](https://man7.org/linux/man-pages/man7/glob.7.html).
		/// - Returns: Options to use to create a Pattern.
		public static func posix() -> Self {
			.fnmatch(
				usePathnameBehavior: true,
				requiresExplicitLeadingPeriods: true
			)
		}

		/// Attempts to match the behavior of [`fnmatch`](https://man7.org/linux/man-pages/man3/fnmatch.3.html).
		/// - Parameter usePathnameBehavior: When true, matches the behavior of `FNM_PATHNAME`. Namely, wildcards will not match path separators.
		/// - Parameter supportsEscapedCharacters: If the pattern supports escaping control characters with `\`. `false` is equivalent to `FNM_NOESCAPE`.
		/// - Parameter requiresExplicitLeadingPeriods: If a period in the name is at the beginning of a component, don't match using wildcards. Equivalent to `FNM_PERIOD`.
		/// - Parameter matchLeadingDirectories: If a pattern should match if it matches a parent directory. Equivalent to `FNM_LEADING_DIR`.
		/// - Parameter supportsExtendedMatching: Enables `supportsPatternLists` equivalent to `FNM_EXTMATCH`.
		/// - Parameter diacriticInsensitiveRanges: When true, character ranges use diacritic-insensitive comparison (e.g., `[a-z]` matches `ä`).
		/// - Returns: Options to use to create a Pattern.
		public static func fnmatch(
			usePathnameBehavior: Bool = false,
			supportsEscapedCharacters: Bool = true,
			requiresExplicitLeadingPeriods: Bool = false,
			matchLeadingDirectories: Bool = false,
			supportsExtendedMatching: Bool = false,
			diacriticInsensitiveRanges: Bool = false
		) -> Self {
			Options(
				supportsPathLevelWildcards: false,
				emptyRangeBehavior: .treatClosingBracketAsCharacter,
				unclosedBracketBehavior: .treatAsLiteral,
				supportsEscapedCharacters: supportsEscapedCharacters,
				requiresExplicitLeadingPeriods: requiresExplicitLeadingPeriods,
				matchLeadingDirectories: matchLeadingDirectories,
				supportsPatternLists: supportsExtendedMatching,
				pathSeparator: usePathnameBehavior ? "/" : nil,
				matchesTrailingPathSeparator: false,
				diacriticInsensitiveRanges: diacriticInsensitiveRanges
			)
		}

		/// Attempts to match the behavior of `fnmatch`.
		/// - Parameter flags: A list of `FNM_` flags to be converted. It is the bitwise OR of zero or more of the following flags: `FNM_PATHNAME`, `FNM_NOESCAPE`, `FNM_PERIOD`, `FNM_LEADING_DIR`, `FNM_EXTMATCH`.
		/// - Returns: Options to use to create a Pattern.
		public static func fnmatch(flags: Int32) -> Self {
			.fnmatch(
				usePathnameBehavior: (flags & FNM_PATHNAME) != 0,
				supportsEscapedCharacters: (flags & FNM_NOESCAPE) == 0,
				requiresExplicitLeadingPeriods: (flags & FNM_PERIOD) != 0,
				matchLeadingDirectories: (flags & FNM_LEADING_DIR) != 0,
				supportsExtendedMatching: (flags & FNM_EXTMATCH) != 0
			)
		}
	}
}
