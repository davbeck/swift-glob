import Testing

@testable import Glob

func assertMatches(
	_ value: String,
	pattern: String,
	options: Glob.Pattern.Options = .default,
	sourceLocation: SourceLocation = #_sourceLocation
) throws {
	#expect(
		try Pattern(pattern, options: options).match(value),
		"\(value) did not match pattern \(pattern) with options \(options)",
		sourceLocation: sourceLocation
	)
}

func assertDoesNotMatch(
	_ value: String,
	pattern: String,
	options: Glob.Pattern.Options = .default,
	sourceLocation: SourceLocation = #_sourceLocation
) throws {
	#expect(
		try !Pattern(pattern, options: options).match(value),
		"'\(value)' matched pattern '\(pattern)' with options \(options)",
		sourceLocation: sourceLocation
	)
}
