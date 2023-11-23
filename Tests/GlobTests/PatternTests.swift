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
		var options = Pattern.Options()
		options.wildcardBehavior = .pathComponentsOnly
		try XCTAssertDoesNotMatch("Target/Other/.build", pattern: "**/.build", options: options)
	}

	func test_componentWildcard_pathComponentsOnly_doesMatchSingleComponent() throws {
		var options = Pattern.Options()
		options.wildcardBehavior = .pathComponentsOnly
		try XCTAssertMatches("Target/.build", pattern: "*/.build", options: options)
	}

	func test_constant() throws {
		try XCTAssertMatches("abc", pattern: "abc")
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

	func test_go() throws {
		// from https://cs.opensource.google/go/go/+/refs/tags/go1.21.4:src/path/filepath/match_test.go

		try XCTAssertMatches("abc", pattern: "abc", options: .go)
		try XCTAssertMatches("abc", pattern: "*", options: .go)
		try XCTAssertMatches("abc", pattern: "*c", options: .go)
		try XCTAssertMatches("abc", pattern: "a*", options: .go)
		try XCTAssertMatches("a", pattern: "a*", options: .go)
		try XCTAssertDoesNotMatch("ab/c", pattern: "a*", options: .go)
		try XCTAssertMatches("abc/b", pattern: "a*/b", options: .go)
		try XCTAssertDoesNotMatch("a/c/b", pattern: "a*/b", options: .go)
		try XCTAssertDoesNotMatch("a/c/b", pattern: "a*/b", options: .go)
		try XCTAssertMatches("axbxcxdxe/f", pattern: "a*b*c*d*e*/f", options: .go)
		try XCTAssertMatches("axbxcxdxexxx/f", pattern: "a*b*c*d*e*/f", options: .go)
		try XCTAssertDoesNotMatch("axbxcxdxe/xxx/f", pattern: "a*b*c*d*e*/f", options: .go)
		try XCTAssertDoesNotMatch("axbxcxdxexxx/fff", pattern: "a*b*c*d*e*/f", options: .go)
		try XCTAssertMatches("abxbbxdbxebxczzx", pattern: "a*b?c*x", options: .go)
		try XCTAssertDoesNotMatch("abxbbxdbxebxczzy", pattern: "a*b?c*x", options: .go)
		try XCTAssertMatches("abc", pattern: "ab[c]", options: .go)
		try XCTAssertMatches("abc", pattern: "ab[b-d]", options: .go)
		try XCTAssertDoesNotMatch("abc", pattern: "ab[e-g]", options: .go)
		try XCTAssertDoesNotMatch("abc", pattern: "ab[^c]", options: .go)
		try XCTAssertDoesNotMatch("abc", pattern: "ab[^b-d]", options: .go)
		try XCTAssertMatches("abc", pattern: "ab[^e-g]", options: .go)
		try XCTAssertMatches("a*b", pattern: "a\\*b", options: .go)
		try XCTAssertDoesNotMatch("ab", pattern: "a\\*b", options: .go)
		try XCTAssertMatches("a☺b", pattern: "a?b", options: .go)
		try XCTAssertMatches("a☺b", pattern: "a[^a]b", options: .go)
		try XCTAssertDoesNotMatch("a☺b", pattern: "a???b", options: .go)
		try XCTAssertDoesNotMatch("a☺b", pattern: "a[^a][^a][^a]b", options: .go)
		try XCTAssertMatches("α", pattern: "[a-ζ]*", options: .go)
		try XCTAssertDoesNotMatch("A", pattern: "*[a-ζ]", options: .go)
		try XCTAssertDoesNotMatch("a/b", pattern: "a?b", options: .go)
		try XCTAssertDoesNotMatch("a/b", pattern: "a*b", options: .go)
		try XCTAssertMatches("]", pattern: "[\\]a]", options: .go)
		try XCTAssertMatches("-", pattern: "[\\-]", options: .go)
		try XCTAssertMatches("x", pattern: "[x\\-]", options: .go)
		try XCTAssertMatches("-", pattern: "[x\\-]", options: .go)
		try XCTAssertDoesNotMatch("z", pattern: "[x\\-]", options: .go)
		try XCTAssertMatches("x", pattern: "[\\-x]", options: .go)
		try XCTAssertMatches("-", pattern: "[\\-x]", options: .go)
		try XCTAssertDoesNotMatch("a", pattern: "[\\-x]", options: .go)
		try XCTAssertMatches("xxx", pattern: "*x", options: .go)

		XCTAssertThrowsError(try Pattern("[]a]", options: .go).match("]"))
		XCTAssertThrowsError(try Pattern("[-]", options: .go).match("-"))
		XCTAssertThrowsError(try Pattern("[x-]", options: .go).match("x"))
		XCTAssertThrowsError(try Pattern("[x-]", options: .go).match("-"))
		XCTAssertThrowsError(try Pattern("[x-]", options: .go).match("z"))
		XCTAssertThrowsError(try Pattern("[-x]", options: .go).match("x"))
		XCTAssertThrowsError(try Pattern("[-x]", options: .go).match("-"))
		XCTAssertThrowsError(try Pattern("[-x]", options: .go).match("a"))
		XCTAssertThrowsError(try Pattern("\\", options: .go).match("a"))
		XCTAssertThrowsError(try Pattern("[a-b-c]", options: .go).match("a"))
		XCTAssertThrowsError(try Pattern("[", options: .go).match("a"))
		XCTAssertThrowsError(try Pattern("[^", options: .go).match("a"))
		XCTAssertThrowsError(try Pattern("[^bc", options: .go).match("a"))
		XCTAssertThrowsError(try Pattern("a[", options: .go).match("a"))
		XCTAssertThrowsError(try Pattern("a[", options: .go).match("ab"))
		XCTAssertThrowsError(try Pattern("a[", options: .go).match("x"))
		XCTAssertThrowsError(try Pattern("a/b[", options: .go).match("x"))
	}
}
