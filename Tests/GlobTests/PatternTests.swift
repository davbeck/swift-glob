import Testing

@testable import Glob

struct PatternTests {
	@Test func pathWildcard_matchesSingleNestedFolders() throws {
		try assertMatches("Target/AutoMockable.generated.swift", pattern: "**/*.generated.swift")
	}

	@Test func pathWildcard_matchesMultipleNestedFolders() throws {
		try assertMatches("Target/Generated/AutoMockable.generated.swift", pattern: "**/*.generated.swift")
	}

	@Test func componentWildcard_matchesNonNestedFiles() throws {
		try assertMatches("AutoMockable.generated.swift", pattern: "*.generated.swift")
	}

	@Test func componentWildcard_doesNotMatchNestedPaths() throws {
		try assertDoesNotMatch("Target/AutoMockable.generated.swift", pattern: "*.generated.swift")
	}

	@Test func multipleWildcards_matchesWithMultipleConstants() throws {
		// this can be tricky for some implementations because as they are parsing the first wildcard,
		// it will see a match and move on and the remaining pattern and content will not match
		try assertMatches("Target/AutoMockable/Sources/AutoMockable.generated.swift", pattern: "**/AutoMockable*.swift")
	}

	@Test func pathWildcard_pathComponentsOnly_doesNotMatchPath() throws {
		var options = Pattern.Options.default
		options.supportsPathLevelWildcards = false
		try assertDoesNotMatch("Target/Other/.build", pattern: "**/.build", options: options)
	}

	@Test func componentWildcard_pathComponentsOnly_doesMatchSingleComponent() throws {
		var options = Pattern.Options.default
		options.supportsPathLevelWildcards = false
		try assertMatches("Target/.build", pattern: "*/.build", options: options)
	}

	@Test func constant() throws {
		try assertMatches("abc", pattern: "abc")
	}

	@Test func ranges() throws {
		try assertMatches("b", pattern: "[a-c]")
		try assertMatches("B", pattern: "[A-C]")
		try assertDoesNotMatch("n", pattern: "[a-c]")
	}

	@Test func multipleRanges() throws {
		try assertMatches("b", pattern: "[a-cA-C]")
		try assertMatches("B", pattern: "[a-cA-C]")
		try assertDoesNotMatch("n", pattern: "[a-cA-C]")
		try assertDoesNotMatch("N", pattern: "[a-cA-C]")
		try assertDoesNotMatch("n", pattern: "[a-cA-Z]")
		try assertMatches("N", pattern: "[a-cA-Z]")
	}

	@Test func negateRange() throws {
		try assertDoesNotMatch("abc", pattern: "ab[^c]", options: .go)
	}

	@Test func singleCharacter_doesNotMatchSeparator() throws {
		try assertDoesNotMatch("a/b", pattern: "a?b")
	}

	@Test func namedCharacterClasses_alpha() throws {
		try assertMatches("b", pattern: "[[:alpha:]]")
		try assertMatches("B", pattern: "[[:alpha:]]")
		try assertMatches("ē", pattern: "[[:alpha:]]")
		try assertMatches("ž", pattern: "[[:alpha:]]")
		try assertDoesNotMatch("9", pattern: "[[:alpha:]]")
		try assertDoesNotMatch("&", pattern: "[[:alpha:]]")
	}

	@Test func trailingPathSeparator() throws {
		try assertMatches("abc/", pattern: "a*")
		try assertDoesNotMatch("abc/", pattern: "a*", options: .init(matchesTrailingPathSeparator: false))
		try assertMatches("dirB1/dirB2/", pattern: "**dirB2")
	}

	@Test func nonNestedWildcards() throws {
		// from https://fishshell.com/docs/3.4/language.html#expand-wildcard
		// If ** is a segment by itself, that segment may match zero times, for compatibility with other shells.

		try assertMatches("dir/File.swift", pattern: "dir/**/*.swift")
		try assertMatches("dir/File.swift", pattern: "dir/**/File.swift")
		try assertDoesNotMatch("dir/File.swift", pattern: "foo/File**/*.swift")
	}
}
