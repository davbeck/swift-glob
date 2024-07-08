import Foundation

public extension Pattern {
	/// Options to control how patterns are parsed and matched
	struct Options: Sendable {
		/// How wildcards are interpreted
		public enum WildcardBehavior: Sendable {
			/// A single star/asterisk will match any character, including the path separator
			///
			/// Additional star/asterisks are ignored. This matches the behavior of fnmatch when `FNM_PATHNAME` is not provided.
			case singleStarMatchesFullPath
			/// A single star/asterisk will not match path separators, but a double star/asterisk will.
			///
			/// Additional star/asterisks after the second occurrence are ignored.
			case doubleStarMatchesFullPath
			/// A single star/asterisk will not match a path separator, and additional star/asterisks are ignored
			///
			/// This matches the behavior of [POSIX glob](https://man7.org/linux/man-pages/man7/glob.7.html) and [`glob` in libc](https://man7.org/linux/man-pages/man3/glob.3.html).
			case pathComponentsOnly
		}

		/// How wildcards are interpreted
		public var wildcardBehavior: WildcardBehavior

		/// When false, an error will be thrown if an empty range (`[]`) is found.
		public var allowsEmptyRanges: Bool

		/// The character used to specify when a range matches characters that aren't in the range.
		public var rangeNegationCharacter: Character = "!"

		/// The path separator to use in matching
		///
		/// Defaults to "/" regardless of operating system.
		public var pathSeparator: Character = "/"

		/// Default options for parsing and matching patterns.
		public static let `default`: Self = .init(
			wildcardBehavior: .doubleStarMatchesFullPath,
			allowsEmptyRanges: false
		)

		/// Attempts to match the behavior of [VSCode](https://code.visualstudio.com/docs/editor/glob-patterns).
		public static let vscode: Self = Options(
			wildcardBehavior: .doubleStarMatchesFullPath,
			allowsEmptyRanges: false,
			rangeNegationCharacter: "^"
		)

		/// Attempts to match the behavior of [`filepath.Match` in go](https://pkg.go.dev/path/filepath#Match).
		public static let go: Self = Options(
			wildcardBehavior: .pathComponentsOnly,
			allowsEmptyRanges: false,
			rangeNegationCharacter: "^"
		)

		/// Attempts to match the behavior of [POSIX glob](https://man7.org/linux/man-pages/man7/glob.7.html).
		/// - Returns: Options to use to create a Pattern.
		public static func posix() -> Self {
			Options(
				wildcardBehavior: .pathComponentsOnly,
				allowsEmptyRanges: true
			)
		}

		/// Attempts to match the behavior of `fnmatch`.
		/// - Parameter usePathnameBehavior: When true, matches the behavior of FNM_PATHNAME. Namely, wildcards will not match path separators.
		/// - Returns: Options to use to create a Pattern.
		public static func fnmatch(usePathnameBehavior: Bool = false) -> Self {
			Options(
				wildcardBehavior: usePathnameBehavior ? .pathComponentsOnly : .singleStarMatchesFullPath,
				allowsEmptyRanges: true
			)
		}

		public static func fnmatch(flags: Int32) -> Self {
			.fnmatch(
				usePathnameBehavior: (flags & FNM_PATHNAME) != 0
			)
		}
	}
}
