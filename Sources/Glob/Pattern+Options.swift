import FNMDefinitions
import Foundation

public extension Pattern {
	/// Options to control how patterns are parsed and matched
	struct Options: Sendable {
		/// If a double star/asterisk causes the pattern to match path separators.
		///
		/// If `pathSeparator` is `nil` this has no effect.
		public var allowsPathLevelWildcards: Bool = true

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
		public var emptyRangeBehavior: EmptyRangeBehavior

		/// If the pattern supports escaping control characters with '\'
		///
		/// When true, a backslash character ( '\' ) in pattern followed by any other character shall match that second character in string. In particular, "\\" shall match a backslash in string. Otherwise a backslash character shall be treated as an ordinary character.
		public var allowEscapedCharacters: Bool = true

		/// Allows the `-` character to be included in a character class if it is the first or last character (ie `[-abc]` or `[abc-]`)
		public var allowsRangeSeparatorInCharacterClasses: Bool = true

		/// If a period in the name is at the beginning of a component, don't match using wildcards.
		///
		/// Treat the `.` character specially if it appears at the beginning of string. If this flag is set, wildcard constructs in pattern cannot match `.` as the first character of string. If you set both this and `pathSeparator`, then the special treatment applies to `.` following `pathSeparator` as well as to `.` at the beginning of string.
		///
		/// Equivalent to `FNM_PERIOD`.
		public var requiresExplicitLeadingPeriods: Bool = true

		/// If a pattern should match if it matches a parent directory, as defined by `pathSeparator`
		///
		/// Ignore a trailing sequence of characters starting with a `/' in string; that is to say, test whether string starts with a directory name that pattern matches. If this flag is set, either `foo*` or `foobar` as a pattern would match the string `foobar/frobozz`. Equivalent to `FNM_LEADING_DIR`.`
		///
		/// If `pathSeparator` is `nil` this has no effect.
		public var matchLeadingDirectories: Bool = false

		/// The character used to specify when a range matches characters that aren't in the range.
		public var rangeNegationCharacter: Character = "!"

		/// The path separator to use in matching
		///
		/// If this is `nil`, path separators have no special meaning. This is equivalent to excluding `FNM_PATHNAME` in `fnmatch`.
		///
		/// Defaults to "/" regardless of operating system.
		public var pathSeparator: Character? = "/"

		/// Default options for parsing and matching patterns.
		public static let `default`: Self = .init(
			allowsPathLevelWildcards: true,
			emptyRangeBehavior: .error
		)

		/// Attempts to match the behavior of [VSCode](https://code.visualstudio.com/docs/editor/glob-patterns).
		public static let vscode: Self = Options(
			allowsPathLevelWildcards: true,
			emptyRangeBehavior: .error,
			rangeNegationCharacter: "^"
		)

		/// Attempts to match the behavior of [`filepath.Match` in go](https://pkg.go.dev/path/filepath#Match).
		public static let go: Self = Options(
			allowsPathLevelWildcards: false,
			emptyRangeBehavior: .error,
			allowsRangeSeparatorInCharacterClasses: false,
			rangeNegationCharacter: "^"
		)

		/// Attempts to match the behavior of [POSIX glob](https://man7.org/linux/man-pages/man7/glob.7.html).
		/// - Returns: Options to use to create a Pattern.
		public static func posix() -> Self {
			Options(
				allowsPathLevelWildcards: false,
				emptyRangeBehavior: .allow,
				requiresExplicitLeadingPeriods: true
			)
		}

		/// Attempts to match the behavior of `fnmatch`.
		/// - Parameter usePathnameBehavior: When true, matches the behavior of FNM_PATHNAME. Namely, wildcards will not match path separators.
		/// - Returns: Options to use to create a Pattern.
		public static func fnmatch(
			usePathnameBehavior: Bool = false,
			allowEscapedCharacters: Bool = true,
			requiresExplicitLeadingPeriods: Bool = false,
			matchLeadingDirectories: Bool = false
		) -> Self {
			Options(
				allowsPathLevelWildcards: false,
				emptyRangeBehavior: .treatClosingBracketAsCharacter,
				allowEscapedCharacters: allowEscapedCharacters,
				requiresExplicitLeadingPeriods: requiresExplicitLeadingPeriods,
				matchLeadingDirectories: matchLeadingDirectories,
				pathSeparator: usePathnameBehavior ? "/" : nil
			)
		}

		public static func fnmatch(flags: Int32) -> Self {
			.fnmatch(
				usePathnameBehavior: (flags & FNM_PATHNAME) != 0,
				allowEscapedCharacters: (flags & FNM_NOESCAPE) == 0,
				requiresExplicitLeadingPeriods: (flags & FNM_PERIOD) != 0,
				matchLeadingDirectories: (flags & FNM_LEADING_DIR) != 0
			)
		}
	}
}
