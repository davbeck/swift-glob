import Foundation

public extension Pattern {
    /// Options to control how patterns are parsed and matched
    struct Options {
        /// How wildcards are interpreted
        public enum WildcardBehavior {
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
        public var wildcardBehavior: WildcardBehavior = .doubleStarMatchesFullPath
        
        /// The path separator to use in matching
        ///
        /// Defaults to "/" regardless of operating system.
        public var pathSeparator: Character = "/"
        
        public init() {}
        
        /// Default options for parsing and matching patterns.
        public static let `default`: Self = .init()
        
        /// Attempts to match the behavior of [`filepath.Match` in go](https://pkg.go.dev/path/filepath#Match).
        public static var go: Self {
            var options = Options()
            options.wildcardBehavior = .pathComponentsOnly
            return options
        }
        
        /// Attempts to match the behavior of [POSIX glob](https://man7.org/linux/man-pages/man7/glob.7.html).
        /// - Returns: Options to use to create a Pattern.
        public static func posix() -> Self {
            var options = Options()
            options.wildcardBehavior = .pathComponentsOnly
            return options
        }
        
        /// Attempts to match the behavior of `fnmatch`.
        /// - Parameter usePathnameBehavior: When true, matches the behavior of FNM_PATHNAME. Namely, wildcards will not match path separators.
        /// - Returns: Options to use to create a Pattern.
        public static func fnmatch(usePathnameBehavior: Bool = false) -> Self {
            var options = Options()
            options.wildcardBehavior = usePathnameBehavior ? .pathComponentsOnly : .singleStarMatchesFullPath
            return options
        }
    }
}
