import XCTest

@testable import Glob

final class PatternTests: XCTestCase {
    func test_pathWildcard_matchesSingleNestedFolders() throws {
        try XCTAssertTrue(Pattern("**/*.generated.swift").match("Target/AutoMockable.generated.swift"))
    }
    
    func test_pathWildcard_matchesMultipleNestedFolders() throws {
        try XCTAssertTrue(Pattern("**/*.generated.swift").match("Target/Generated/AutoMockable.generated.swift"))
    }
    
    func test_componentWildcard_matchesNonNestedFiles() throws {
        try XCTAssertTrue(Pattern("*.generated.swift").match("AutoMockable.generated.swift"))
    }
    
    func test_componentWildcard_doesNotMatchNestedPaths() throws {
        try XCTAssertFalse(Pattern("*.generated.swift").match("Target/AutoMockable.generated.swift"))
    }
    
    func test_multipleWildcards_matchesWithMultipleConstants() throws {
        // this can be tricky for some implementations because as they are parsing the first wildcard,
        // it will see a match and move on and the remaining pattern and content will not match
        try XCTAssertTrue(Pattern("**/AutoMockable*.swift").match("Target/AutoMockable/Sources/AutoMockable.generated.swift"))
    }
    
    func test_pathWildcard_pathComponentsOnly_doesNotMatchPath() throws {
        var options = Pattern.Options()
        options.wildcardBehavior = .pathComponentsOnly
        try XCTAssertFalse(Pattern("**/.build", options: options).match("Target/Other/.build"))
    }
    
    func test_componentWildcard_pathComponentsOnly_doesMatchSingleComponent() throws {
        var options = Pattern.Options()
        options.wildcardBehavior = .pathComponentsOnly
        try XCTAssertTrue(Pattern("*/.build", options: options).match("Target/.build"))
    }
    
    func test_constant() throws {
        try XCTAssertTrue(Pattern("abc").match("abc"))
    }
    
    func test_multipleRanges() throws {
        try XCTAssertTrue(Pattern("[a-cA-C]").match("b"))
        try XCTAssertTrue(Pattern("[a-cA-C]").match("B"))
        try XCTAssertFalse(Pattern("[a-cA-C]").match("n"))
        try XCTAssertFalse(Pattern("[a-cA-C]").match("N"))
        try XCTAssertFalse(Pattern("[a-cA-Z]").match("n"))
        try XCTAssertTrue(Pattern("[a-cA-Z]").match("N"))
    }
    
    func test_negateRange() throws {
        try XCTAssertFalse(Pattern("ab[^c]", options: .go).match("abc"))
    }
    
    func test_singleCharacter_doesNotMatchSeparator() throws {
        try XCTAssertFalse(Pattern("a?b").match("a/b"))
    }
    
    func test_go() throws {
        // from https://cs.opensource.google/go/go/+/refs/tags/go1.21.4:src/path/filepath/match_test.go
        
        try XCTAssertTrue(Pattern("abc", options: .go).match("abc"))
        try XCTAssertTrue(Pattern("*", options: .go).match("abc"))
        try XCTAssertTrue(Pattern("*c", options: .go).match("abc"))
        try XCTAssertTrue(Pattern("a*", options: .go).match("abc"))
        try XCTAssertTrue(Pattern("a*", options: .go).match("a"))
        try XCTAssertFalse(Pattern("a*", options: .go).match("ab/c"))
        try XCTAssertTrue(Pattern("a*/b", options: .go).match("abc/b"))
        try XCTAssertFalse(Pattern("a*/b", options: .go).match("a/c/b"))
        try XCTAssertFalse(Pattern("a*/b", options: .go).match("a/c/b"))
        try XCTAssertTrue(Pattern("a*b*c*d*e*/f", options: .go).match("axbxcxdxe/f"))
        try XCTAssertTrue(Pattern("a*b*c*d*e*/f", options: .go).match("axbxcxdxexxx/f"))
        try XCTAssertFalse(Pattern("a*b*c*d*e*/f", options: .go).match("axbxcxdxe/xxx/f"))
        try XCTAssertFalse(Pattern("a*b*c*d*e*/f", options: .go).match("axbxcxdxexxx/fff"))
        try XCTAssertTrue(Pattern("a*b?c*x", options: .go).match("abxbbxdbxebxczzx"))
        try XCTAssertFalse(Pattern("a*b?c*x", options: .go).match("abxbbxdbxebxczzy"))
        try XCTAssertTrue(Pattern("ab[c]", options: .go).match("abc"))
        try XCTAssertTrue(Pattern("ab[b-d]", options: .go).match("abc"))
        try XCTAssertFalse(Pattern("ab[e-g]", options: .go).match("abc"))
        try XCTAssertFalse(Pattern("ab[^c]", options: .go).match("abc"))
        try XCTAssertFalse(Pattern("ab[^b-d]", options: .go).match("abc"))
        try XCTAssertTrue(Pattern("ab[^e-g]", options: .go).match("abc"))
        try XCTAssertTrue(Pattern("a\\*b", options: .go).match("a*b"))
        try XCTAssertFalse(Pattern("a\\*b", options: .go).match("ab"))
        try XCTAssertTrue(Pattern("a?b", options: .go).match("a☺b"))
        try XCTAssertTrue(Pattern("a[^a]b", options: .go).match("a☺b"))
        try XCTAssertFalse(Pattern("a???b", options: .go).match("a☺b"))
        try XCTAssertFalse(Pattern("a[^a][^a][^a]b", options: .go).match("a☺b"))
        try XCTAssertTrue(Pattern("[a-ζ]*", options: .go).match("α"))
        try XCTAssertFalse(Pattern("*[a-ζ]", options: .go).match("A"))
        try XCTAssertFalse(Pattern("a?b", options: .go).match("a/b"))
        try XCTAssertFalse(Pattern("a*b", options: .go).match("a/b"))
        try XCTAssertTrue(Pattern("[\\]a]", options: .go).match("]"))
        try XCTAssertTrue(Pattern("[\\-]", options: .go).match("-"))
        try XCTAssertTrue(Pattern("[x\\-]", options: .go).match("x"))
        try XCTAssertTrue(Pattern("[x\\-]", options: .go).match("-"))
        try XCTAssertFalse(Pattern("[x\\-]", options: .go).match("z"))
        try XCTAssertTrue(Pattern("[\\-x]", options: .go).match("x"))
        try XCTAssertTrue(Pattern("[\\-x]", options: .go).match("-"))
        try XCTAssertFalse(Pattern("[\\-x]", options: .go).match("a"))
        try XCTAssertTrue(Pattern("*x", options: .go).match("xxx"))
        
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
