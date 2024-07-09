import XCTest

@testable import Glob

final class PatternTests: XCTestCase {
	func test_pathWildcard_matchesSingleNestedFolders() throws {
		try XCTAssertMatches("Target/AutoMockable.generated.swift", pattern: "**/*.generated.swift")
	}

	func test_pathWildcard_matchesMultipleNestedFolders() throws {
		try XCTAssertMatches("Target/Generated/AutoMockable.generated.swift", pattern: "**/*.generated.swift")
	}

	func test_componentWildcard_matchesNonNestedFiles() throws {
		try XCTAssertMatches("AutoMockable.generated.swift", pattern: "*.generated.swift")
	}

	func test_componentWildcard_doesNotMatchNestedPaths() throws {
		try XCTAssertDoesNotMatch("Target/AutoMockable.generated.swift", pattern: "*.generated.swift")
	}

	func test_multipleWildcards_matchesWithMultipleConstants() throws {
		// this can be tricky for some implementations because as they are parsing the first wildcard,
		// it will see a match and move on and the remaining pattern and content will not match
		try XCTAssertMatches("Target/AutoMockable/Sources/AutoMockable.generated.swift", pattern: "**/AutoMockable*.swift")
	}

	func test_pathWildcard_pathComponentsOnly_doesNotMatchPath() throws {
		var options = Pattern.Options.default
		options.wildcardBehavior = .pathComponentsOnly
		try XCTAssertDoesNotMatch("Target/Other/.build", pattern: "**/.build", options: options)
	}

	func test_componentWildcard_pathComponentsOnly_doesMatchSingleComponent() throws {
		var options = Pattern.Options.default
		options.wildcardBehavior = .pathComponentsOnly
		try XCTAssertMatches("Target/.build", pattern: "*/.build", options: options)
	}

	func test_constant() throws {
		try XCTAssertMatches("abc", pattern: "abc")
	}
	
	func test_ranges() throws {
		try XCTAssertMatches("b", pattern: "[a-c]")
		try XCTAssertMatches("B", pattern: "[A-C]")
		try XCTAssertDoesNotMatch("n", pattern: "[a-c]")
	}

	func test_multipleRanges() throws {
		try XCTAssertMatches("b", pattern: "[a-cA-C]")
		try XCTAssertMatches("B", pattern: "[a-cA-C]")
		try XCTAssertDoesNotMatch("n", pattern: "[a-cA-C]")
		try XCTAssertDoesNotMatch("N", pattern: "[a-cA-C]")
		try XCTAssertDoesNotMatch("n", pattern: "[a-cA-Z]")
		try XCTAssertMatches("N", pattern: "[a-cA-Z]")
	}

	func test_negateRange() throws {
		try XCTAssertDoesNotMatch("abc", pattern: "ab[^c]", options: .go)
	}

	func test_singleCharacter_doesNotMatchSeparator() throws {
		try XCTAssertDoesNotMatch("a/b", pattern: "a?b")
	}

	func test_namedCharacterClasses_alpha() throws {
		try XCTAssertMatches("b", pattern: "[[:alpha:]]")
		try XCTAssertMatches("B", pattern: "[[:alpha:]]")
		try XCTAssertMatches("ē", pattern: "[[:alpha:]]")
		try XCTAssertMatches("ž", pattern: "[[:alpha:]]")
		try XCTAssertDoesNotMatch("9", pattern: "[[:alpha:]]")
		try XCTAssertDoesNotMatch("&", pattern: "[[:alpha:]]")
	}
}
