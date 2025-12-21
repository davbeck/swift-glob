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
		}

		/// The character used to specify when a range matches characters that aren't in the range.
		public var rangeNegationCharacter: RangeNegationCharacter = .exclamationMark

		/// The path separator to use in matching
		///
		/// If this is `nil`, path separators have no special meaning. This is equivalent to excluding `FNM_PATHNAME` in `fnmatch`.
		///
		/// Defaults to "/" regardless of operating system.
		public var pathSeparator: Character? = "/"

		/// If a trailing path separator in the search string will be ignored if it's not explicitly matched.
		///
		/// This allows patterns to match against a directory or a regular file. For instance "foo*" will match both "foo_file" and "foo_dir/" if this is enabled.
		public var matchesTrailingPathSeparator: Bool = true

		/// Default options for parsing and matching patterns.
		public static let `default`: Self = .init()

		/// Attempts to match the behavior of [VSCode](https://code.visualstudio.com/docs/editor/glob-patterns).
		public static let vscode: Self = Options(
			supportsPathLevelWildcards: true,
			emptyRangeBehavior: .error,
			supportsPatternLists: false,
			supportsBraceExpansion: true,
			rangeNegationCharacter: .caret
		)

		/// Attempts to match the behavior of [`filepath.Match` in go](https://pkg.go.dev/path/filepath#Match).
		public static let go: Self = Options(
			supportsPathLevelWildcards: false,
			emptyRangeBehavior: .error,
			supportsRangeSeparatorAtBeginningAndEnd: false,
			rangeNegationCharacter: .caret
		)

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
		/// - Returns: Options to use to create a Pattern.
		public static func fnmatch(
			usePathnameBehavior: Bool = false,
			supportsEscapedCharacters: Bool = true,
			requiresExplicitLeadingPeriods: Bool = false,
			matchLeadingDirectories: Bool = false,
			supportsExtendedMatching: Bool = false
		) -> Self {
			Options(
				supportsPathLevelWildcards: false,
				emptyRangeBehavior: .treatClosingBracketAsCharacter,
				supportsEscapedCharacters: supportsEscapedCharacters,
				requiresExplicitLeadingPeriods: requiresExplicitLeadingPeriods,
				matchLeadingDirectories: matchLeadingDirectories,
				supportsPatternLists: supportsExtendedMatching,
				pathSeparator: usePathnameBehavior ? "/" : nil,
				matchesTrailingPathSeparator: false
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
