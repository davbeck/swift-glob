import XCTest

@testable import Glob

func XCTAssertMatches(
	_ value: String,
	pattern: String,
	options: Glob.Pattern.Options = .default,
	file: StaticString = #filePath,
	line: UInt = #line
) throws {
	try XCTAssertTrue(
		Pattern(pattern, options: options).match(value),
		"\(value) did not match pattern \(pattern) with options \(options)",
		file: file,
		line: line
	)
}

func XCTAssertDoesNotMatch(
	_ value: String,
	pattern: String,
	options: Glob.Pattern.Options = .default,
	file: StaticString = #filePath,
	line: UInt = #line
) throws {
	try XCTAssertFalse(
		Pattern(pattern, options: options).match(value),
		"\(value) matched pattern \(pattern) with options \(options)",
		file: file,
		line: line
	)
}
