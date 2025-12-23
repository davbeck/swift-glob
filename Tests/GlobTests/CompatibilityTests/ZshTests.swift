import Testing

@testable import Glob

/// Tests derived from zsh's D02glob.ztst test file.
/// See: https://github.com/zsh-users/zsh/blob/master/Test/D02glob.ztst
///
/// Note: Many zsh extended glob features are not supported by this library:
/// - `#` operator (zero or more of preceding): `fo#` means `f` followed by zero or more `o`s
/// - `^` negation operator: `^foo` matches anything except `foo`
/// - `~` exclusion operator: `*.c~foo*` matches .c files except those starting with foo
/// - `(#i)` case-insensitive matching
/// - `(#l)` lowercase matching
/// - `(#a)` approximate matching
/// - `(#c)` match count specifications
/// - `(#s)` and `(#e)` start/end anchors
/// - `(#b)` backreferences
/// - `(#q)` glob qualifiers
/// - `<n-m>` numeric ranges
///
/// This test suite focuses on KSH-style patterns which are supported:
/// - `@(pattern|pattern)` - match exactly one of the patterns
/// - `*(pattern|pattern)` - match zero or more of the patterns
/// - `+(pattern|pattern)` - match one or more of the patterns
/// - `?(pattern|pattern)` - match zero or one of the patterns
/// - `!(pattern|pattern)` - match anything except the patterns

// MARK: - KSH Compatibility Tests

/// Tests from the `globtest globtests.ksh` section of D02glob.ztst
struct zshTests {
	// MARK: - Basic pattern list tests

	@Test func kshGlob_zeroOrMore_basic() throws {
		// *(f*(o)) - zero or more of (f followed by zero or more o's)
		try assertMatches("fofo", pattern: "*(f*(o))", options: .zsh)
		try assertMatches("ffo", pattern: "*(f*(o))", options: .zsh)
		try assertMatches("foooofo", pattern: "*(f*(o))", options: .zsh)
		try assertMatches("foooofof", pattern: "*(f*(o))", options: .zsh)
		try assertMatches("fooofoofofooo", pattern: "*(f*(o))", options: .zsh)
		try assertDoesNotMatch("xfoooofof", pattern: "*(f*(o))", options: .zsh)
		try assertDoesNotMatch("foooofofx", pattern: "*(f*(o))", options: .zsh)
		try assertDoesNotMatch("ofooofoofofooo", pattern: "*(f*(o))", options: .zsh)
	}

	@Test func kshGlob_oneOrMore_basic() throws {
		// *(f+(o)) - zero or more of (f followed by one or more o's)
		try assertDoesNotMatch("foooofof", pattern: "*(f+(o))", options: .zsh)
		try assertMatches("ofoofo", pattern: "*(of+(o))", options: .zsh)
		try assertMatches("oxfoxoxfox", pattern: "*(oxf+(ox))", options: .zsh)
		try assertDoesNotMatch("oxfoxfox", pattern: "*(oxf+(ox))", options: .zsh)
	}

	@Test func kshGlob_nested_patterns() throws {
		// Nested pattern lists
		try assertMatches("ofxoofxo", pattern: "*(*(of*(o)x)o)", options: .zsh)
		try assertMatches("foooxfooxfoxfooox", pattern: "*(f*(o)x)", options: .zsh)
		try assertDoesNotMatch("foooxfooxofoxfooox", pattern: "*(f*(o)x)", options: .zsh)
		try assertMatches("foooxfooxfxfooox", pattern: "*(f*(o)x)", options: .zsh)
		try assertMatches("ofxoofxo", pattern: "*(*(of*(o)x)o)", options: .zsh)
		try assertMatches("ofoooxoofxo", pattern: "*(*(of*(o)x)o)", options: .zsh)
		try assertMatches("ofoooxoofxoofoooxoofxo", pattern: "*(*(of*(o)x)o)", options: .zsh)
		try assertMatches("ofoooxoofxoofoooxoofxoo", pattern: "*(*(of*(o)x)o)", options: .zsh)
		try assertDoesNotMatch("ofoooxoofxoofoooxoofxofo", pattern: "*(*(of*(o)x)o)", options: .zsh)
		try assertMatches("ofoooxoofxoofoooxoofxooofxofxo", pattern: "*(*(of*(o)x)o)", options: .zsh)
	}

	@Test func kshGlob_exactlyOne() throws {
		// @() - exactly one match
		try assertMatches("aac", pattern: "*(@(a))a@(c)", options: .zsh)
		try assertMatches("ac", pattern: "*(@(a))a@(c)", options: .zsh)
		try assertDoesNotMatch("c", pattern: "*(@(a))a@(c)", options: .zsh)
		try assertMatches("aaac", pattern: "*(@(a))a@(c)", options: .zsh)
		try assertDoesNotMatch("baaac", pattern: "*(@(a))a@(c)", options: .zsh)
	}

	@Test func kshGlob_mixedPatterns() throws {
		try assertMatches("abcd", pattern: "?@(a|b)*@(c)d", options: .zsh)
		try assertMatches("abcd", pattern: "@(ab|a*@(b))*(c)d", options: .zsh)
		try assertMatches("acd", pattern: "@(ab|a*(b))*(c)d", options: .zsh)
		try assertMatches("abbcd", pattern: "@(ab|a*(b))*(c)d", options: .zsh)
	}

	@Test func kshGlob_complexAlternatives() throws {
		// @(b+(c)d|e*(f)g?|?(h)i@(j|k))
		try assertMatches("effgz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", options: .zsh)
		try assertMatches("efgz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", options: .zsh)
		try assertMatches("egz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", options: .zsh)
		try assertMatches("egzefffgzbcdij", pattern: "*(b+(c)d|e*(f)g?|?(h)i@(j|k))", options: .zsh)
		try assertDoesNotMatch("egz", pattern: "@(b+(c)d|e+(f)g?|?(h)i@(j|k))", options: .zsh)
	}

	@Test func kshGlob_alternativesWithRepetition() throws {
		try assertMatches("ofoofo", pattern: "*(of+(o)|f)", options: .zsh)
		try assertMatches("foofoofo", pattern: "@(foo|f|fo)*(f|of+(o))", options: .zsh)
		try assertMatches("oofooofo", pattern: "*(of|oof+(o))", options: .zsh)
		try assertMatches("fofoofoofofoo", pattern: "*(fo|foo)", options: .zsh)
	}

	@Test(.disabled("Pattern causes exponential backtracking - takes ~20 seconds"))
	func kshGlob_alternativesWithRepetition_slow() throws {
		// This pattern *(*(f)*(o)) can cause exponential backtracking
		try assertMatches("fffooofoooooffoofffooofff", pattern: "*(*(f)*(o))", options: .zsh)
		try assertDoesNotMatch("fffooofoooooffoofffooofffx", pattern: "*(*(f)*(o))", options: .zsh)
	}

	// MARK: - Negation pattern tests

	@Test func kshGlob_negation_basic() throws {
		// !(pattern) - match anything except pattern
		try assertMatches("foo", pattern: "!(x)", options: .zsh)
		try assertMatches("foo", pattern: "!(x)*", options: .zsh)
		try assertDoesNotMatch("foo", pattern: "!(foo)", options: .zsh)
		try assertMatches("foo", pattern: "!(foo)*", options: .zsh)
		try assertMatches("foobar", pattern: "!(foo)", options: .zsh)
		try assertMatches("foobar", pattern: "!(foo)*", options: .zsh)
	}

	@Test func kshGlob_negation_withDot() throws {
		// This pattern is quite complex: !(*.*) means "anything not containing a dot"
		// So !(*.*).!(*.*) means "no-dot DOT no-dot"
		// Our implementation has issues with this pattern
		withKnownIssue {
			try assertMatches("moo.cow", pattern: "!(*.*).!(*.*)", options: .zsh)
			try assertDoesNotMatch("mad.moo.cow", pattern: "!(*.*).!(*.*)", options: .zsh)
		}
	}

	@Test func kshGlob_negation_complex() throws {
		try assertDoesNotMatch("mucca.pazza", pattern: "mu!(*(c))?.pa!(*(z))?", options: .zsh)
		try assertDoesNotMatch("_foo~", pattern: "_?(*[^~])", options: .zsh)
	}

	@Test func kshGlob_negation_repeating() throws {
		// !(f) should match any single char except f, *(!(f)) matches strings without f
		try assertMatches("fff", pattern: "!(f)", options: .zsh)
		try assertMatches("fff", pattern: "*(!(f))", options: .zsh)
		try assertMatches("fff", pattern: "+(!(f))", options: .zsh)
		try assertMatches("ooo", pattern: "!(f)", options: .zsh)
		try assertMatches("ooo", pattern: "*(!(f))", options: .zsh)
		try assertMatches("ooo", pattern: "+(!(f))", options: .zsh)
		try assertMatches("foo", pattern: "!(f)", options: .zsh)
		try assertMatches("foo", pattern: "*(!(f))", options: .zsh)
		try assertMatches("foo", pattern: "+(!(f))", options: .zsh)
		try assertDoesNotMatch("f", pattern: "!(f)", options: .zsh)
		try assertDoesNotMatch("f", pattern: "*(!(f))", options: .zsh)
		try assertDoesNotMatch("f", pattern: "+(!(f))", options: .zsh)
	}

	@Test func kshGlob_negation_withAlternatives() throws {
		try assertMatches("foot", pattern: "@(!(z*)|*x)", options: .zsh)
		try assertDoesNotMatch("zoot", pattern: "@(!(z*)|*x)", options: .zsh)
		try assertMatches("foox", pattern: "@(!(z*)|*x)", options: .zsh)
		try assertMatches("zoox", pattern: "@(!(z*)|*x)", options: .zsh)
	}

	@Test func kshGlob_negation_edge_cases() throws {
		try assertMatches("foo", pattern: "*(!(foo))", options: .zsh)
		try assertDoesNotMatch("foob", pattern: "!(foo)b*", options: .zsh)
		try assertMatches("foobb", pattern: "!(foo)b*", options: .zsh)
	}
}

// MARK: - Character Class Tests

struct ZshCharacterClassTests {
	@Test func bracketExpression_specialChars() throws {
		// [ alone
		try assertMatches("[", pattern: "[[]", options: .zsh)
		// ] alone - in zsh, []] means bracket containing just ]
		// Our implementation treats this as empty range which is an error
		withKnownIssue {
			try assertMatches("]", pattern: "[]]", options: .zsh)
		}
	}

	@Test func bracketExpression_negation() throws {
		// ^ active in character class
		try assertDoesNotMatch("a", pattern: "[^a]", options: .zsh)
		// ! active in character class
		try assertDoesNotMatch("a", pattern: "[!a]", options: .zsh)
	}

	@Test func bracketExpression_rangeWithDash() throws {
		// - is special in ranges
		try assertDoesNotMatch("-", pattern: "[a-z]", options: .zsh)
		// Range test
		try assertMatches("b-1", pattern: "[a-z]-[0-9]", options: .zsh)
	}

	@Test func bracketExpression_closingBracketFirst() throws {
		// ] after [ is normal character, - still works
		// Note: This relies on ] being first in the bracket to be literal
		withKnownIssue {
			try assertMatches("b-1", pattern: "[]a-z]-[]0-9]", options: .zsh)
		}
	}

	@Test func bracketExpression_specialChars_zshSpecific() throws {
		// These use zsh's # operator (zero or more of preceding)
		withKnownIssue {
			// [: as pattern - [[:]# means [: repeated
			try assertMatches("[:", pattern: "[[:]#", options: .zsh)
			// :] as pattern
			try assertMatches(":]", pattern: "[]:]#", options: .zsh)
			try assertMatches(":]", pattern: "[:]]#", options: .zsh)
		}
	}
}

// MARK: - Basic Glob Tests

struct ZshBasicGlobTests {
	@Test func emptyStrings() throws {
		try assertMatches("", pattern: "", options: .zsh)
	}

	@Test func basicPatterns() throws {
		try assertMatches("foo", pattern: "f*", options: .zsh)
		// Using @() for exactly-one-of since bare () is zsh extended glob
		try assertMatches("fob", pattern: "f@(o|a)@(o|b)", options: .zsh)
		try assertMatches("fab", pattern: "f@(o|a)@(o|b)", options: .zsh)
		try assertDoesNotMatch("fib", pattern: "f@(o|a)@(o|b)", options: .zsh)
	}

	@Test func zshBareParensPatterns() throws {
		// In zsh extended glob, bare () is a grouping construct
		// This is not supported in our ksh-style implementation
		withKnownIssue {
			try assertMatches("fob", pattern: "f(o|a)(o|b)", options: .zsh)
			try assertMatches("fab", pattern: "f(o|a)(o|b)", options: .zsh)
			try assertDoesNotMatch("fib", pattern: "f(o|a)(o|b)", options: .zsh)
		}
	}
}

// MARK: - KSH Glob Option Tests

struct zshOptionTests {
	@Test func kshGlobSpecialCharsWithoutParens() throws {
		// When kshglob is enabled, +, @, ! without following ( are literal
		// In our implementation, pattern lists require the opening paren
		try assertMatches("+fours", pattern: "+*", options: .zsh)
		try assertMatches("@titude", pattern: "@*", options: .zsh)
		try assertMatches("!bang", pattern: "!*", options: .zsh)
	}

	@Test func kshGlobPatternListsStillWork() throws {
		try assertMatches("+bus+bus", pattern: "+(+bus|-car)", options: .zsh)
		try assertMatches("@sinhats", pattern: "@(@sinhats|wrensinfens)", options: .zsh)
		try assertMatches("!kerror", pattern: "!(!somethingelse)", options: .zsh)
	}

	@Test func kshGlobPatternListsNonMatching() throws {
		try assertDoesNotMatch("+more", pattern: "+(+less)", options: .zsh)
		try assertDoesNotMatch("@all@all", pattern: "@(@all)", options: .zsh)
		try assertDoesNotMatch("!goesitall", pattern: "!(!goesitall)", options: .zsh)
	}
}

// MARK: - Unsupported Features (for documentation)

/// These tests document zsh extended glob features that are NOT supported.
/// They are wrapped in withKnownIssue to track potential future implementation.
struct ZshUnsupportedFeaturesTests {
	@Test func unsupported_hashOperator() throws {
		// # means zero or more of preceding element in zsh
		// fo# means f followed by zero or more o's
		withKnownIssue {
			try assertMatches("fofo", pattern: "(fo#)#", options: .zsh)
			try assertMatches("ffo", pattern: "(fo#)#", options: .zsh)
			try assertMatches("foooofo", pattern: "(fo#)#", options: .zsh)
		}
	}

	@Test func unsupported_caretNegation() throws {
		// ^ in extended glob means negation (different from ! in bracket expressions)
		withKnownIssue {
			try assertMatches("foo", pattern: "(^x)", options: .zsh)
			try assertDoesNotMatch("foo", pattern: "(^foo)", options: .zsh)
		}
	}

	@Test func unsupported_tildeExclusion() throws {
		// ~ is the exclusion operator: pattern~excluded
		withKnownIssue {
			try assertMatches("foo.c", pattern: "*.c~boo*", options: .zsh)
			try assertDoesNotMatch("foo.c", pattern: "*.c~boo*~foo*", options: .zsh)
		}
	}

	@Test func unsupported_caseInsensitive() throws {
		// (#i) enables case-insensitive matching
		withKnownIssue {
			try assertMatches("fooxx", pattern: "(#i)FOOXX", options: .zsh)
		}
	}

	@Test func unsupported_approximateMatching() throws {
		// (#a1) allows 1 error in matching
		withKnownIssue {
			try assertMatches("READ.ME", pattern: "(#ia1)readme", options: .zsh)
		}
	}

	@Test func unsupported_matchCount() throws {
		// (#c5) means exactly 5 repetitions
		withKnownIssue {
			try assertMatches("XabcdabcY", pattern: "X(ab|c|d)(#c5)Y", options: .zsh)
		}
	}

	@Test func unsupported_numericRanges() throws {
		// <1-1000> matches numbers in range
		withKnownIssue {
			try assertMatches("633", pattern: "<1-1000>33", options: .zsh)
		}
	}

	@Test func unsupported_startEndAnchors() throws {
		// (#s) and (#e) are start/end anchors
		withKnownIssue {
			try assertMatches("test", pattern: "*((#s)|/)test((#e)|/)*", options: .zsh)
		}
	}
}
