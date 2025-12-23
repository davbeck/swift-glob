//
//  Pattern+GoTests.swift
//
//
//  Created by David Beck on 7/7/24.
//
import Testing

@testable import Glob

// from https://cs.opensource.google/go/go/+/refs/tags/go1.21.4:src/path/filepath/match_test.go

struct GoTests {
	@Test func goPatternMatching() throws {
		try assertMatches("abc", pattern: "abc", options: .go)
		try assertMatches("abc", pattern: "*", options: .go)
		try assertMatches("abc", pattern: "*c", options: .go)
		try assertMatches("abc", pattern: "a*", options: .go)
		try assertMatches("a", pattern: "a*", options: .go)
		try assertDoesNotMatch("ab/c", pattern: "a*", options: .go)
		try assertMatches("abc/b", pattern: "a*/b", options: .go)
		try assertDoesNotMatch("a/c/b", pattern: "a*/b", options: .go)
		try assertDoesNotMatch("a/c/b", pattern: "a*/b", options: .go)
		try assertMatches("axbxcxdxe/f", pattern: "a*b*c*d*e*/f", options: .go)
		try assertMatches("axbxcxdxexxx/f", pattern: "a*b*c*d*e*/f", options: .go)
		try assertDoesNotMatch("axbxcxdxe/xxx/f", pattern: "a*b*c*d*e*/f", options: .go)
		try assertDoesNotMatch("axbxcxdxexxx/fff", pattern: "a*b*c*d*e*/f", options: .go)
		try assertMatches("abxbbxdbxebxczzx", pattern: "a*b?c*x", options: .go)
		try assertDoesNotMatch("abxbbxdbxebxczzy", pattern: "a*b?c*x", options: .go)
		try assertMatches("abc", pattern: "ab[c]", options: .go)
		try assertMatches("abc", pattern: "ab[b-d]", options: .go)
		try assertDoesNotMatch("abc", pattern: "ab[e-g]", options: .go)
		try assertDoesNotMatch("abc", pattern: "ab[^c]", options: .go)
		try assertDoesNotMatch("abc", pattern: "ab[^b-d]", options: .go)
		try assertMatches("abc", pattern: "ab[^e-g]", options: .go)
		try assertMatches("a*b", pattern: "a\\*b", options: .go)
		try assertDoesNotMatch("ab", pattern: "a\\*b", options: .go)
		try assertMatches("a☺b", pattern: "a?b", options: .go)
		try assertMatches("a☺b", pattern: "a[^a]b", options: .go)
		try assertDoesNotMatch("a☺b", pattern: "a???b", options: .go)
		try assertDoesNotMatch("a☺b", pattern: "a[^a][^a][^a]b", options: .go)
		try assertMatches("α", pattern: "[a-ζ]*", options: .go)
		try assertDoesNotMatch("A", pattern: "*[a-ζ]", options: .go)
		try assertDoesNotMatch("a/b", pattern: "a?b", options: .go)
		try assertDoesNotMatch("a/b", pattern: "a*b", options: .go)
		try assertMatches("]", pattern: "[\\]a]", options: .go)
		try assertMatches("-", pattern: "[\\-]", options: .go)
		try assertMatches("x", pattern: "[x\\-]", options: .go)
		try assertMatches("-", pattern: "[x\\-]", options: .go)
		try assertDoesNotMatch("z", pattern: "[x\\-]", options: .go)
		try assertMatches("x", pattern: "[\\-x]", options: .go)
		try assertMatches("-", pattern: "[\\-x]", options: .go)
		try assertDoesNotMatch("a", pattern: "[\\-x]", options: .go)
		try assertMatches("xxx", pattern: "*x", options: .go)

		#expect(throws: (any Error).self) { _ = try Pattern("[]a]", options: .go) }
		#expect(throws: (any Error).self) { _ = try Pattern("[-]", options: .go) }
		#expect(throws: (any Error).self) { _ = try Pattern("[x-]", options: .go) }
		#expect(throws: (any Error).self) { _ = try Pattern("[-x]", options: .go) }
		#expect(throws: (any Error).self) { _ = try Pattern("\\", options: .go) }
		#expect(throws: (any Error).self) { _ = try Pattern("[a-b-c]", options: .go) }
		#expect(throws: (any Error).self) { _ = try Pattern("[", options: .go) }
		#expect(throws: (any Error).self) { _ = try Pattern("[^", options: .go) }
		#expect(throws: (any Error).self) { _ = try Pattern("[^bc", options: .go) }
		#expect(throws: (any Error).self) { _ = try Pattern("a[", options: .go) }
		#expect(throws: (any Error).self) { _ = try Pattern("a/b[", options: .go) }
	}
}
