import XCTest

@testable import Glob

private let PATHNAME = FNM_PATHNAME
private let PERIOD = FNM_PERIOD
private let NOESCAPE = FNM_NOESCAPE
private let NOMATCH = FNM_NOMATCH
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
	private let LEADING_DIR = FNM_LEADING_DIR
#else
	private let LEADING_DIR = (1 as Int32) << 29
#endif
private let EXTMATCH = (1 as Int32) << 30 // FNM_EXTMATCH

private func XCTAssertMatchesFNMatch(
	_ value: String,
	pattern: String,
	flags: Int32,
	result expectedResult: Int32,
	file: StaticString = #filePath,
	line: UInt = #line
) {
	let patternResult: Int32
	do {
		if try Pattern(pattern, options: .fnmatch(flags: flags)).match(value) {
			patternResult = 0
		} else {
			patternResult = NOMATCH
		}
	} catch {
		patternResult = -1
	}

	let fnmatchResult = fnmatch(pattern, value, flags)

	XCTAssertEqual(
		fnmatchResult,
		expectedResult,
		"fnmatch output did not match expected result '\(expectedResult)'",
		file: file,
		line: line
	)
	XCTAssertEqual(
		patternResult,
		expectedResult,
		"matching '\(value)' to pattern '\(pattern)' with flags \(flags) did not match fnmatch result \(expectedResult)",
		file: file,
		line: line
	)
}

final class PatternFNMatchTests: XCTestCase {
	// derrived from https://github.com/bminor/glibc/blob/9fc639f654dc004736836613be703e6bed0c36a8/posix/tst-fnmatch.input

	// Derived from the IEEE 2003.2 text.  The standard only contains some
	// wording describing the situations to be tested.  It does not specify
	// any specific tests.  I.e., the tests below are in no case sufficient.
	// They are hopefully necessary, though.
	//
	// See:
	//
	// http://pubs.opengroup.org/onlinepubs/9699919799/xrat/V4_xbd_chap09.html
	//
	// > RE Bracket Expression
	// >
	// > Range expressions are, historically, an integral part of REs.
	// > However, the requirements of "natural language behavior" and
	// > portability do conflict. In the POSIX locale, ranges must be treated
	// > according to the collating sequence and include such characters that
	// > fall within the range based on that collating sequence, regardless
	// > of character values. In other locales, ranges have unspecified behavior.
	// > ...
	// > The current standard leaves unspecified the behavior of a range
	// > expression outside the POSIX locale. This makes it clearer that
	// > conforming applications should avoid range expressions outside the
	// > POSIX locale, and it allows implementations and compatible user-mode
	// > matchers to interpret range expressions using native order, CEO,
	// > collation sequence, or other, more advanced techniques. The concerns
	// > which led to this change were raised in IEEE PASC interpretation
	// > 1003.2 #43 and others, and related to ambiguities in the
	// > specification of how multi-character collating elements should be
	// > handled in range expressions. These ambiguities had led to multiple
	// > interpretations of the specification, in conflicting ways, which led
	// > to varying implementations. As noted above, efforts were made to
	// > resolve the differences, but no solution has been found that would
	// > be specific enough to allow for portable software while not
	// > invalidating existing implementations.
	//
	// Therefore, using [a-z] does not make much sense except in the C/POSIX locale.
	// The new iso14651_t1_common lists upper case and lower case Latin characters
	// in a different order than the old one which causes surprising results
	// for example in the de_DE locale: [a-z] now includes A because A comes
	// after a in iso14651_t1_common but does not include Z because that comes
	// after z in iso14651_t1_common.
	//
	// This lead to several bugs and problems with user scripts that do not
	// expect [a-z] to match uppercase characters.
	//
	// See the following bugs:
	// https://sourceware.org/bugzilla/show_bug.cgi?id=23393
	// https://sourceware.org/bugzilla/show_bug.cgi?id=23420
	//
	// No consensus exists on how best to handle the changes so the
	// iso14651_t1_common collation element order (CEO) has been changed to
	// deinterlace the a-z and A-Z regions.
	//
	// With the deinterlacing commit ac3a3b4b0d561d776b60317d6a926050c8541655
	// could be reverted to re-test the correct non-interleaved expectations.
	//
	// Please note that despite the region being deinterlaced, the ordering
	// of collation remains the same.  In glibc we implement CEO and because of
	// that we can reorder the elements to reorder ranges without impacting
	// collation which depends on weights.  The collation element ordering
	// could have been changed to include just a-z, A-Z, and 0-9 in three
	// distinct blocks, but this needs more discussion by the community.

	// I wish I could find what the section headings (ie "B.6 004(C)") referred to

	//  B.6 004(C)
	func test_b_6_004_c() throws {
		// C		 "!#%+,-./01234567889"	"!#%+,-./01234567889"  0
		XCTAssertMatchesFNMatch("!#%+,-./01234567889", pattern: "!#%+,-./01234567889", flags: 0, result: 0)
		// C		 ":;=@ABCDEFGHIJKLMNO"	":;=@ABCDEFGHIJKLMNO"  0
		XCTAssertMatchesFNMatch(":;=@ABCDEFGHIJKLMNO", pattern: ":;=@ABCDEFGHIJKLMNO", flags: 0, result: 0)
		// C		 "PQRSTUVWXYZ]abcdefg"	"PQRSTUVWXYZ]abcdefg"  0
		XCTAssertMatchesFNMatch("PQRSTUVWXYZ]abcdefg", pattern: "PQRSTUVWXYZ]abcdefg", flags: 0, result: 0)
		// C		 "hijklmnopqrstuvwxyz"	"hijklmnopqrstuvwxyz"  0
		XCTAssertMatchesFNMatch("hijklmnopqrstuvwxyz", pattern: "hijklmnopqrstuvwxyz", flags: 0, result: 0)
		// C		 "^_{}~"		"^_{}~"		       0
		XCTAssertMatchesFNMatch("^_{}~", pattern: "^_{}~", flags: 0, result: 0)
	}

	//  B.6 005(C)
	func test_b_6_005_c() throws {
		// C		 "\"$&'()"		"\\\"\\$\\&\\'\\(\\)"  0
		XCTAssertMatchesFNMatch("\"$&'()", pattern: "\\\"\\$\\&\\'\\(\\)", flags: 0, result: 0)
		// C		 "*?[\\`|"		"\\*\\?\\[\\\\\\`\\|"  0
		XCTAssertMatchesFNMatch("*?[\\`|", pattern: "\\*\\?\\[\\\\\\`\\|", flags: 0, result: 0)
		// C		 "<>"			"\\<\\>"	       0
		XCTAssertMatchesFNMatch("<>", pattern: "\\<\\>", flags: 0, result: 0)
	}

	//  B.6 006(C)
	func test_b_6_006_c() throws {
		// C		 "?*["			"[?*[][?*[][?*[]"      0
		XCTAssertMatchesFNMatch("?*[", pattern: "[?*[][?*[][?*[]", flags: 0, result: 0)
		// C		 "a/b"			"?/b"		       0
		XCTAssertMatchesFNMatch("a/b", pattern: "?/b", flags: 0, result: 0)
	}

	//  B.6 007(C)
	func test_b_6_007_c() throws {
		// C		 "a/b"			"a?b"		       0
		XCTAssertMatchesFNMatch("a/b", pattern: "a?b", flags: 0, result: 0)
		// C		 "a/b"			"a/?"		       0
		XCTAssertMatchesFNMatch("a/b", pattern: "a/?", flags: 0, result: 0)
		// C		 "aa/b"			"?/b"		       NOMATCH
		XCTAssertMatchesFNMatch("aa/b", pattern: "?/b", flags: 0, result: NOMATCH)
		// C		 "aa/b"			"a?b"		       NOMATCH
		XCTAssertMatchesFNMatch("aa/b", pattern: "a?b", flags: 0, result: NOMATCH)
		// C		 "a/bb"			"a/?"		       NOMATCH
		XCTAssertMatchesFNMatch("a/bb", pattern: "a/?", flags: 0, result: NOMATCH)
	}

	//  B.6 009(C)
	func test_b_6_009_c() throws {
		// C		 "abc"			"[abc]"		       NOMATCH
		XCTAssertMatchesFNMatch("abc", pattern: "[abc]", flags: 0, result: NOMATCH)
		// C		 "x"			"[abc]"		       NOMATCH
		XCTAssertMatchesFNMatch("x", pattern: "[abc]", flags: 0, result: NOMATCH)
		// C		 "a"			"[abc]"		       0
		XCTAssertMatchesFNMatch("a", pattern: "[abc]", flags: 0, result: 0)
		// C		 "["			"[[abc]"	       0
		XCTAssertMatchesFNMatch("[", pattern: "[[abc]", flags: 0, result: 0)
		// C		 "a"			"[][abc]"	       0
		XCTAssertMatchesFNMatch("a", pattern: "[][abc]", flags: 0, result: 0)
		// C		 "a]"			"[]a]]"		       0
		XCTAssertMatchesFNMatch("a]", pattern: "[]a]]", flags: 0, result: 0)
	}

	//  B.6 010(C)
	func test_b_6_010_c() throws {
		// C		 "xyz"			"[!abc]"	       NOMATCH
		XCTAssertMatchesFNMatch("xyz", pattern: "[!abc]", flags: 0, result: NOMATCH)
		// C		 "x"			"[!abc]"	       0
		XCTAssertMatchesFNMatch("x", pattern: "[!abc]", flags: 0, result: 0)
		// C		 "a"			"[!abc]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[!abc]", flags: 0, result: NOMATCH)
	}

	//  B.6 011(C)
	func test_b_6_011_c() throws {
		// C		 "]"			"[][abc]"	       0
		XCTAssertMatchesFNMatch("]", pattern: "[][abc]", flags: 0, result: 0)
		// C		 "abc]"			"[][abc]"	       NOMATCH
		XCTAssertMatchesFNMatch("abc]", pattern: "[][abc]", flags: 0, result: NOMATCH)
		// C		 "[]abc"		"[][]abc"	       NOMATCH
		XCTAssertMatchesFNMatch("[]abc", pattern: "[][]abc", flags: 0, result: NOMATCH)
		// C		 "]"			"[!]]"		       NOMATCH
		XCTAssertMatchesFNMatch("]", pattern: "[!]]", flags: 0, result: NOMATCH)
		// C		 "aa]"			"[!]a]"		       NOMATCH
		XCTAssertMatchesFNMatch("aa]", pattern: "[!]a]", flags: 0, result: NOMATCH)
		// C		 "]"			"[!a]"		       0
		XCTAssertMatchesFNMatch("]", pattern: "[!a]", flags: 0, result: 0)
		// C		 "]]"			"[!a]]"		       0
		XCTAssertMatchesFNMatch("]]", pattern: "[!a]]", flags: 0, result: 0)
	}

	//  B.6 012(C)
	func test_b_6_012_c() throws {
		XCTExpectFailure {
			// C		 "a"			"[[.a.]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[.a.]]", flags: 0, result: 0)
			// C		 "-"			"[[.-.]]"	       0
			XCTAssertMatchesFNMatch("-", pattern: "[[.-.]]", flags: 0, result: 0)
			// C		 "-"			"[[.-.][.].]]"	       0
			XCTAssertMatchesFNMatch("-", pattern: "[[.-.][.].]]", flags: 0, result: 0)
			// C		 "-"			"[[.].][.-.]]"	       0
			XCTAssertMatchesFNMatch("-", pattern: "[[.].][.-.]]", flags: 0, result: 0)
			// C		 "-"			"[[.-.][=u=]]"	       0
			XCTAssertMatchesFNMatch("-", pattern: "[[.-.][=u=]]", flags: 0, result: 0)
			// C		 "-"			"[[.-.][:alpha:]]"     0
			XCTAssertMatchesFNMatch("-", pattern: "[[.-.][:alpha:]]", flags: 0, result: 0)
			// C		 "a"			"[![.a.]]"	       NOMATCH
			XCTAssertMatchesFNMatch("a", pattern: "[![.a.]]", flags: 0, result: NOMATCH)
		}
	}

	//  B.6 013(C)
	func test_b_6_013_c() throws {
		// C		 "a"			"[[.b.]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[.b.]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[.b.][.c.]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[.b.][.c.]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[.b.][=b=]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[.b.][=b=]]", flags: 0, result: NOMATCH)
	}

	//  B.6 015(C)
	func test_b_6_015_c() throws {
		XCTExpectFailure {
			// C		 "a"			"[[=a=]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=a=]]", flags: 0, result: 0)
			// C		 "b"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0)
			// C		 "b"			"[[=a=][=b=]]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=a=][=b=]]", flags: 0, result: 0)
			// C		 "a"			"[[=a=][=b=]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=a=][=b=]]", flags: 0, result: 0)
			// C		 "a"			"[[=a=][.b.]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=a=][.b.]]", flags: 0, result: 0)
			// C		 "a"			"[[=a=][:digit:]]"     0
			XCTAssertMatchesFNMatch("a", pattern: "[[=a=][:digit:]]", flags: 0, result: 0)
		}
	}

	//  B.6 016(C)
	func test_b_6_016_c() throws {
		// C		 "="			"[[=a=]b]"	       NOMATCH
		XCTAssertMatchesFNMatch("=", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
		// C		 "]"			"[[=a=]b]"	       NOMATCH
		XCTAssertMatchesFNMatch("]", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[=b=][=c=]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][=c=]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[=b=][.].]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][.].]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[=b=][:digit:]]"     NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][:digit:]]", flags: 0, result: NOMATCH)
	}

	//  B.6 017(C)
	func test_b_6_017_c() throws {
		// C		 "a"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "a"			"[![:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[![:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "-"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "a]a"			"[[:alnum:]]a"	       NOMATCH
		XCTAssertMatchesFNMatch("a]a", pattern: "[[:alnum:]]a", flags: 0, result: NOMATCH)
		// C		 "-"			"[[:alnum:]-]"	       0
		XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]-]", flags: 0, result: 0)
		// C		 "aa"			"[[:alnum:]]a"	       0
		XCTAssertMatchesFNMatch("aa", pattern: "[[:alnum:]]a", flags: 0, result: 0)
		// C		 "-"			"[![:alnum:]]"	       0
		XCTAssertMatchesFNMatch("-", pattern: "[![:alnum:]]", flags: 0, result: 0)
		// C		 "]"			"[!][:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("]", pattern: "[!][:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "["			"[![:alnum:][]"	       NOMATCH
		XCTAssertMatchesFNMatch("[", pattern: "[![:alnum:][]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "b"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("b", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "c"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("c", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "d"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("d", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "e"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("e", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "f"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("f", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "g"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("g", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "h"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("h", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "i"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("i", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "j"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("j", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "k"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("k", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "l"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("l", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "m"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("m", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "n"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("n", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "o"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("o", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "p"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("p", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "q"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("q", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "r"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("r", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "s"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("s", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "t"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("t", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "u"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("u", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "v"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("v", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "w"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("w", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "x"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("x", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "y"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("y", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "z"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("z", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "A"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("A", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "B"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("B", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "C"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("C", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "D"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("D", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "E"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("E", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "F"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("F", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "G"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("G", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "H"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("H", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "I"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("I", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "J"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("J", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "K"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("K", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "L"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("L", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "M"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("M", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "N"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("N", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "O"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("O", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "P"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("P", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "Q"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("Q", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "R"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("R", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "S"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("S", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "T"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("T", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "U"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("U", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "V"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("V", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "W"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("W", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "X"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("X", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "Y"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("Y", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "Z"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("Z", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "0"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("0", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "1"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("1", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "2"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("2", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "3"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("3", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "4"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("4", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "5"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("5", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "6"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("6", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "7"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("7", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "8"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("8", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "9"			"[[:alnum:]]"	       0
		XCTAssertMatchesFNMatch("9", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "!"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("!", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "#"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("#", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "%"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("%", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "+"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("+", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 ","			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch(",", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "-"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "."			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch(".", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "/"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("/", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 ":"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch(":", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 ";"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch(";", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "="			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("=", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "@"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("@", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "["			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("[", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "\\"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\\", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "]"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("]", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "^"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("^", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "_"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("_", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "{"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("{", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "}"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("}", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "~"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("~", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "\""			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\"", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "$"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("$", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "&"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("&", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "'"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("'", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "("			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("(", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 ")"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch(")", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "*"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("*", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "?"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("?", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "`"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("`", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "|"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("|", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "<"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("<", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 ">"			"[[:alnum:]]"	       NOMATCH
		XCTAssertMatchesFNMatch(">", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:cntrl:]]"	       0
		XCTAssertMatchesFNMatch("\t", pattern: "[[:cntrl:]]", flags: 0, result: 0)
		// C		 "t"			"[[:cntrl:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("t", pattern: "[[:cntrl:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:lower:]]"	       0
		XCTAssertMatchesFNMatch("t", pattern: "[[:lower:]]", flags: 0, result: 0)
		// C		 "\t"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\t", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// C		 "T"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("T", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:space:]]"	       0
		XCTAssertMatchesFNMatch("\t", pattern: "[[:space:]]", flags: 0, result: 0)
		// C		 "t"			"[[:space:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("t", pattern: "[[:space:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:alpha:]]"	       0
		XCTAssertMatchesFNMatch("t", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// C		 "\t"			"[[:alpha:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\t", pattern: "[[:alpha:]]", flags: 0, result: NOMATCH)
		// C		 "0"			"[[:digit:]]"	       0
		XCTAssertMatchesFNMatch("0", pattern: "[[:digit:]]", flags: 0, result: 0)
		// C		 "\t"			"[[:digit:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:digit:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:print:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\t", pattern: "[[:print:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:print:]]"	       0
		XCTAssertMatchesFNMatch("t", pattern: "[[:print:]]", flags: 0, result: 0)
		// C		 "T"			"[[:upper:]]"	       0
		XCTAssertMatchesFNMatch("T", pattern: "[[:upper:]]", flags: 0, result: 0)
		// C		 "\t"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:blank:]]"	       0
		XCTAssertMatchesFNMatch("\t", pattern: "[[:blank:]]", flags: 0, result: 0)
		// C		 "t"			"[[:blank:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("t", pattern: "[[:blank:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:graph:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\t", pattern: "[[:graph:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:graph:]]"	       0
		XCTAssertMatchesFNMatch("t", pattern: "[[:graph:]]", flags: 0, result: 0)
		// C		 "."			"[[:punct:]]"	       0
		XCTAssertMatchesFNMatch(".", pattern: "[[:punct:]]", flags: 0, result: 0)
		// C		 "t"			"[[:punct:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:punct:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH)
		// C		 "0"			"[[:xdigit:]]"	       0
		XCTAssertMatchesFNMatch("0", pattern: "[[:xdigit:]]", flags: 0, result: 0)
		// C		 "\t"			"[[:xdigit:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[:xdigit:]]"	       0
		XCTAssertMatchesFNMatch("a", pattern: "[[:xdigit:]]", flags: 0, result: 0)
		// C		 "A"			"[[:xdigit:]]"	       0
		XCTAssertMatchesFNMatch("A", pattern: "[[:xdigit:]]", flags: 0, result: 0)
		// C		 "t"			"[[:xdigit:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[alpha]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[alpha]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[alpha:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[alpha:]]", flags: 0, result: NOMATCH)
		// C		 "a]"			"[[alpha]]"	       0
		XCTAssertMatchesFNMatch("a]", pattern: "[[alpha]]", flags: 0, result: 0)
		// C		 "a]"			"[[alpha:]]"	       0
		XCTAssertMatchesFNMatch("a]", pattern: "[[alpha:]]", flags: 0, result: 0)
		// C		 "a"			"[[:alpha:][.b.]]"     0
		XCTExpectFailure {
			XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][.b.]]", flags: 0, result: 0)
		}
		// C		 "a"			"[[:alpha:][=b=]]"     0
		XCTExpectFailure {
			XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][=b=]]", flags: 0, result: 0)
		}
		// C		 "a"			"[[:alpha:][:digit:]]" 0
		XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][:digit:]]", flags: 0, result: 0)
		// C		 "a"			"[[:digit:][:alpha:]]" 0
		XCTAssertMatchesFNMatch("a", pattern: "[[:digit:][:alpha:]]", flags: 0, result: 0)
	}

	//  B.6 018(C)
	func test_b_6_018_c() throws {
		// C		 "a"			"[a-c]"		       0
		XCTAssertMatchesFNMatch("a", pattern: "[a-c]", flags: 0, result: 0)
		// C		 "b"			"[a-c]"		       0
		XCTAssertMatchesFNMatch("b", pattern: "[a-c]", flags: 0, result: 0)
		// C		 "c"			"[a-c]"		       0
		XCTAssertMatchesFNMatch("c", pattern: "[a-c]", flags: 0, result: 0)
		// C		 "a"			"[b-c]"		       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[b-c]", flags: 0, result: NOMATCH)
		// C		 "d"			"[b-c]"		       NOMATCH
		XCTAssertMatchesFNMatch("d", pattern: "[b-c]", flags: 0, result: NOMATCH)
		// C		 "B"			"[a-c]"		       NOMATCH
		XCTAssertMatchesFNMatch("B", pattern: "[a-c]", flags: 0, result: NOMATCH)
		// C		 "b"			"[A-C]"		       NOMATCH
		XCTAssertMatchesFNMatch("b", pattern: "[A-C]", flags: 0, result: NOMATCH)
		// C		 ""			"[a-c]"		       NOMATCH
		XCTAssertMatchesFNMatch("", pattern: "[a-c]", flags: 0, result: NOMATCH)
		// C		 "as"			"[a-ca-z]"	       NOMATCH
		XCTAssertMatchesFNMatch("as", pattern: "[a-ca-z]", flags: 0, result: NOMATCH)

		XCTExpectFailure {
			// C		 "a"			"[[.a.]-c]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[.a.]-c]", flags: 0, result: 0)
			// C		 "a"			"[a-[.c.]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[a-[.c.]]", flags: 0, result: 0)
			// C		 "a"			"[[.a.]-[.c.]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
			// C		 "b"			"[[.a.]-c]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[.a.]-c]", flags: 0, result: 0)
			// C		 "b"			"[a-[.c.]]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[a-[.c.]]", flags: 0, result: 0)
			// C		 "b"			"[[.a.]-[.c.]]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
			// C		 "c"			"[[.a.]-c]"	       0
			XCTAssertMatchesFNMatch("c", pattern: "[[.a.]-c]", flags: 0, result: 0)
			// C		 "c"			"[a-[.c.]]"	       0
			XCTAssertMatchesFNMatch("c", pattern: "[a-[.c.]]", flags: 0, result: 0)
			// C		 "c"			"[[.a.]-[.c.]]"	       0
			XCTAssertMatchesFNMatch("c", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
			// C		 "d"			"[[.a.]-c]"	       NOMATCH
			XCTAssertMatchesFNMatch("d", pattern: "[[.a.]-c]", flags: 0, result: NOMATCH)
			// C		 "d"			"[a-[.c.]]"	       NOMATCH
			XCTAssertMatchesFNMatch("d", pattern: "[a-[.c.]]", flags: 0, result: NOMATCH)
			// C		 "d"			"[[.a.]-[.c.]]"	       NOMATCH
			XCTAssertMatchesFNMatch("d", pattern: "[[.a.]-[.c.]]", flags: 0, result: NOMATCH)
		}
	}

	//  B.6 019(C)
	func test_b_6_019_c() throws {
		XCTExpectFailure {
			// C		 "a"			"[c-a]"		       NOMATCH
			XCTAssertMatchesFNMatch("a", pattern: "[c-a]", flags: 0, result: NOMATCH)
			// C		 "a"			"[[.c.]-a]"	       NOMATCH
			XCTAssertMatchesFNMatch("a", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH)
			// C		 "a"			"[c-[.a.]]"	       NOMATCH
			XCTAssertMatchesFNMatch("a", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH)
			// C		 "a"			"[[.c.]-[.a.]]"	       NOMATCH
			XCTAssertMatchesFNMatch("a", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH)
			// C		 "c"			"[c-a]"		       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[c-a]", flags: 0, result: NOMATCH)
			// C		 "c"			"[[.c.]-a]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH)
			// C		 "c"			"[c-[.a.]]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH)
			// C		 "c"			"[[.c.]-[.a.]]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH)
		}
	}

	//  B.6 020(C)
	func test_b_6_020_c() throws {
		// C		 "a"			"[a-c0-9]"	       0
		XCTAssertMatchesFNMatch("a", pattern: "[a-c0-9]", flags: 0, result: 0)
		// C		 "d"			"[a-c0-9]"	       NOMATCH
		XCTAssertMatchesFNMatch("d", pattern: "[a-c0-9]", flags: 0, result: NOMATCH)
		// C		 "B"			"[a-c0-9]"	       NOMATCH
		XCTAssertMatchesFNMatch("B", pattern: "[a-c0-9]", flags: 0, result: NOMATCH)
	}

	//  B.6 021(C)
	func test_b_6_021_c() throws {
		// C		 "-"			"[-a]"		       0
		XCTAssertMatchesFNMatch("-", pattern: "[-a]", flags: 0, result: 0)
		// C		 "a"			"[-b]"		       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[-b]", flags: 0, result: NOMATCH)
		// C		 "-"			"[!-a]"		       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[!-a]", flags: 0, result: NOMATCH)
		// C		 "a"			"[!-b]"		       0
		XCTAssertMatchesFNMatch("a", pattern: "[!-b]", flags: 0, result: 0)
		// C		 "-"			"[a-c-0-9]"	       0
		XCTAssertMatchesFNMatch("-", pattern: "[a-c-0-9]", flags: 0, result: 0)
		// C		 "b"			"[a-c-0-9]"	       0
		XCTAssertMatchesFNMatch("b", pattern: "[a-c-0-9]", flags: 0, result: 0)
		// C		 "a:"			"a[0-9-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("a:", pattern: "a[0-9-a]", flags: 0, result: NOMATCH)
		// C		 "a:"			"a[09-a]"	       0
		XCTAssertMatchesFNMatch("a:", pattern: "a[09-a]", flags: 0, result: 0)
	}

	//  B.6 024(C)
	func test_b_6_024_c() throws {
		// C		 ""			"*"		       0
		XCTAssertMatchesFNMatch("", pattern: "*", flags: 0, result: 0)
		// C		 "asd/sdf"		"*"		       0
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "*", flags: 0, result: 0)
	}

	//  B.6 025(C)
	func test_b_6_025_c() throws {
		// C		 "as"			"[a-c][a-z]"	       0
		XCTAssertMatchesFNMatch("as", pattern: "[a-c][a-z]", flags: 0, result: 0)
		// C		 "as"			"??"		       0
		XCTAssertMatchesFNMatch("as", pattern: "??", flags: 0, result: 0)
	}

	//  B.6 026(C)
	func test_b_6_026_c() throws {
		// C		 "asd/sdf"		"as*df"		       0
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*df", flags: 0, result: 0)
		// C		 "asd/sdf"		"as*"		       0
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*", flags: 0, result: 0)
		// C		 "asd/sdf"		"*df"		       0
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "*df", flags: 0, result: 0)
		// C		 "asd/sdf"		"as*dg"		       NOMATCH
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*dg", flags: 0, result: NOMATCH)
		// C		 "asdf"			"as*df"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "as*df", flags: 0, result: 0)
		// C		 "asdf"			"as*df?"	       NOMATCH
		XCTAssertMatchesFNMatch("asdf", pattern: "as*df?", flags: 0, result: NOMATCH)
		// C		 "asdf"			"as*??"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "as*??", flags: 0, result: 0)
		// C		 "asdf"			"a*???"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "a*???", flags: 0, result: 0)
		// C		 "asdf"			"*????"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "*????", flags: 0, result: 0)
		// C		 "asdf"			"????*"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "????*", flags: 0, result: 0)
		// C		 "asdf"			"??*?"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "??*?", flags: 0, result: 0)
	}

	//  B.6 027(C)
	func test_b_6_027_c() throws {
		// C		 "/"			"/"		       0
		XCTAssertMatchesFNMatch("/", pattern: "/", flags: 0, result: 0)
		// C		 "/"			"/*"		       0
		XCTAssertMatchesFNMatch("/", pattern: "/*", flags: 0, result: 0)
		// C		 "/"			"*/"		       0
		XCTAssertMatchesFNMatch("/", pattern: "*/", flags: 0, result: 0)
		// C		 "/"			"/?"		       NOMATCH
		XCTAssertMatchesFNMatch("/", pattern: "/?", flags: 0, result: NOMATCH)
		// C		 "/"			"?/"		       NOMATCH
		XCTAssertMatchesFNMatch("/", pattern: "?/", flags: 0, result: NOMATCH)
		// C		 "/"			"?"		       0
		XCTAssertMatchesFNMatch("/", pattern: "?", flags: 0, result: 0)
		// C		 "."			"?"		       0
		XCTAssertMatchesFNMatch(".", pattern: "?", flags: 0, result: 0)
		// C		 "/."			"??"		       0
		XCTAssertMatchesFNMatch("/.", pattern: "??", flags: 0, result: 0)
		// C		 "/"			"[!a-c]"	       0
		XCTAssertMatchesFNMatch("/", pattern: "[!a-c]", flags: 0, result: 0)
		// C		 "."			"[!a-c]"	       0
		XCTAssertMatchesFNMatch(".", pattern: "[!a-c]", flags: 0, result: 0)
	}

	//  B.6 029(C)
	func test_b_6_029_c() throws {
		// C		 "/"			"/"		       0       PATHNAME
		XCTAssertMatchesFNMatch("/", pattern: "/", flags: PATHNAME, result: 0)
		// C		 "//"			"//"		       0       PATHNAME
		XCTAssertMatchesFNMatch("//", pattern: "//", flags: PATHNAME, result: 0)
		// C		 "/.a"			"/*"		       0       PATHNAME
		XCTAssertMatchesFNMatch("/.a", pattern: "/*", flags: PATHNAME, result: 0)
		// C		 "/.a"			"/?a"		       0       PATHNAME
		XCTAssertMatchesFNMatch("/.a", pattern: "/?a", flags: PATHNAME, result: 0)
		// C		 "/.a"			"/[!a-z]a"	       0       PATHNAME
		XCTAssertMatchesFNMatch("/.a", pattern: "/[!a-z]a", flags: PATHNAME, result: 0)
		// C		 "/.a/.b"		"/*/?b"		       0       PATHNAME
		XCTAssertMatchesFNMatch("/.a/.b", pattern: "/*/?b", flags: PATHNAME, result: 0)
	}

	//  B.6 030(C)
	func test_b_6_030_c() throws {
		// C		 "/"			"?"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("/", pattern: "?", flags: PATHNAME, result: NOMATCH)
		// C		 "/"			"*"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("/", pattern: "*", flags: PATHNAME, result: NOMATCH)
		// C		 "a/b"			"a?b"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("a/b", pattern: "a?b", flags: PATHNAME, result: NOMATCH)
		// C		 "/.a/.b"		"/*b"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("/.a/.b", pattern: "/*b", flags: PATHNAME, result: NOMATCH)
	}

	//  B.6 031(C)
	func test_b_6_031_c() throws {
		// C		 "/$"			"\\/\\$"	       0
		XCTAssertMatchesFNMatch("/$", pattern: "\\/\\$", flags: 0, result: 0)
		// C		 "/["			"\\/\\["	       0
		XCTAssertMatchesFNMatch("/[", pattern: "\\/\\[", flags: 0, result: 0)
		// C		 "/["			"\\/["		       0
		XCTExpectFailure {
			// Apple's implimentation of fnmatch doesn't produce this result
			XCTAssertMatchesFNMatch("/[", pattern: "\\/[", flags: 0, result: 0)
		}
		// C		 "/[]"			"\\/\\[]"	       0
		XCTAssertMatchesFNMatch("/[]", pattern: "\\/\\[]", flags: 0, result: 0)
	}

	//  B.6 032(C)
	func test_b_6_032_c() throws {
		XCTExpectFailure {
			// C		 "/$"			"\\/\\$"	       NOMATCH NOESCAPE
			XCTAssertMatchesFNMatch("/$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH)
			// C		 "/\\$"			"\\/\\$"	       NOMATCH NOESCAPE
			XCTAssertMatchesFNMatch("/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH)
			// C		 "\\/\\$"		"\\/\\$"	       0       NOESCAPE
			XCTAssertMatchesFNMatch("\\/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: 0)
		}
	}

	//  B.6 033(C)
	func test_b_6_033_c() throws {
		// C		 ".asd"			".*"		       0       PERIOD
		XCTAssertMatchesFNMatch(".asd", pattern: ".*", flags: PERIOD, result: 0)
		// C		 "/.asd"		"*"		       0       PERIOD
		XCTAssertMatchesFNMatch("/.asd", pattern: "*", flags: PERIOD, result: 0)
		// C		 "/as/.df"		"*/?*f"		       0       PERIOD
		XCTAssertMatchesFNMatch("/as/.df", pattern: "*/?*f", flags: PERIOD, result: 0)
		// C		 "..asd"		".[!a-z]*"	       0       PERIOD
		XCTAssertMatchesFNMatch("..asd", pattern: ".[!a-z]*", flags: PERIOD, result: 0)
	}

	//  B.6 034(C)
	func test_b_6_034_c() throws {
		XCTExpectFailure {
			// C		 ".asd"			"*"		       NOMATCH PERIOD
			XCTAssertMatchesFNMatch(".asd", pattern: "*", flags: PERIOD, result: NOMATCH)
			// C		 ".asd"			"?asd"		       NOMATCH PERIOD
			XCTAssertMatchesFNMatch(".asd", pattern: "?asd", flags: PERIOD, result: NOMATCH)
			// C		 ".asd"			"[!a-z]*"	       NOMATCH PERIOD
			XCTAssertMatchesFNMatch(".asd", pattern: "[!a-z]*", flags: PERIOD, result: NOMATCH)
		}
	}

	//  B.6 035(C)
	func test_b_6_035_c() throws {
		// C		 "/."			"/."		       0       PATHNAME|PERIOD
		XCTAssertMatchesFNMatch("/.", pattern: "/.", flags: PATHNAME | PERIOD, result: 0)
		// C		 "/.a./.b."		"/.*/.*"	       0       PATHNAME|PERIOD
		XCTAssertMatchesFNMatch("/.a./.b.", pattern: "/.*/.*", flags: PATHNAME | PERIOD, result: 0)
		// C		 "/.a./.b."		"/.??/.??"	       0       PATHNAME|PERIOD
		XCTAssertMatchesFNMatch("/.a./.b.", pattern: "/.??/.??", flags: PATHNAME | PERIOD, result: 0)
	}

	//  B.6 036(C)
	func test_b_6_036_c() throws {
		XCTExpectFailure {
			// C		 "/."			"*"		       NOMATCH PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("/.", pattern: "*", flags: PATHNAME | PERIOD, result: NOMATCH)
			// C		 "/."			"/*"		       NOMATCH PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("/.", pattern: "/*", flags: PATHNAME | PERIOD, result: NOMATCH)
			// C		 "/."			"/?"		       NOMATCH PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("/.", pattern: "/?", flags: PATHNAME | PERIOD, result: NOMATCH)
			// C		 "/."			"/[!a-z]"	       NOMATCH PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("/.", pattern: "/[!a-z]", flags: PATHNAME | PERIOD, result: NOMATCH)
			// C		 "/a./.b."		"/*/*"		       NOMATCH PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("/a./.b.", pattern: "/*/*", flags: PATHNAME | PERIOD, result: NOMATCH)
			// C		 "/a./.b."		"/??/???"	       NOMATCH PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("/a./.b.", pattern: "/??/???", flags: PATHNAME | PERIOD, result: NOMATCH)
		}
	}

	//  Some home-grown tests utf8
	func test_some_home_grown_tests_utf8() throws {
		// C		"foobar"		"foo*[abc]z"	       NOMATCH
		XCTAssertMatchesFNMatch("foobar", pattern: "foo*[abc]z", flags: 0, result: NOMATCH)
		// C		"foobaz"		"foo*[abc][xyz]"       0
		XCTAssertMatchesFNMatch("foobaz", pattern: "foo*[abc][xyz]", flags: 0, result: 0)
		// C		"foobaz"		"foo?*[abc][xyz]"      0
		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc][xyz]", flags: 0, result: 0)
		// C		"foobaz"		"foo?*[abc][x/yz]"     0
		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc][x/yz]", flags: 0, result: 0)
		// C		"foobaz"		"foo?*[abc]/[xyz]"     NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc]/[xyz]", flags: PATHNAME, result: NOMATCH)
		// C		"a"			"a/"                   NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("a", pattern: "a/", flags: PATHNAME, result: NOMATCH)
		// C		"a/"			"a"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("a/", pattern: "a", flags: PATHNAME, result: NOMATCH)
		// C		"//a"			"/a"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("//a", pattern: "/a", flags: PATHNAME, result: NOMATCH)
		// C		"/a"			"//a"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("/a", pattern: "//a", flags: PATHNAME, result: NOMATCH)
		// C		"az"			"[a-]z"		       0
		XCTAssertMatchesFNMatch("az", pattern: "[a-]z", flags: 0, result: 0)
		// C		"bz"			"[ab-]z"	       0
		XCTAssertMatchesFNMatch("bz", pattern: "[ab-]z", flags: 0, result: 0)
		// C		"cz"			"[ab-]z"	       NOMATCH
		XCTAssertMatchesFNMatch("cz", pattern: "[ab-]z", flags: 0, result: NOMATCH)
		// C		"-z"			"[ab-]z"	       0
		XCTAssertMatchesFNMatch("-z", pattern: "[ab-]z", flags: 0, result: 0)
		// C		"az"			"[-a]z"		       0
		XCTAssertMatchesFNMatch("az", pattern: "[-a]z", flags: 0, result: 0)
		// C		"bz"			"[-ab]z"	       0
		XCTAssertMatchesFNMatch("bz", pattern: "[-ab]z", flags: 0, result: 0)
		// C		"cz"			"[-ab]z"	       NOMATCH
		XCTAssertMatchesFNMatch("cz", pattern: "[-ab]z", flags: 0, result: NOMATCH)
		// C		"-z"			"[-ab]z"	       0
		XCTAssertMatchesFNMatch("-z", pattern: "[-ab]z", flags: 0, result: 0)
		// C		"\\"			"[\\\\-a]"	       0
		XCTAssertMatchesFNMatch("\\", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C		"_"			"[\\\\-a]"	       0
		XCTAssertMatchesFNMatch("_", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C		"a"			"[\\\\-a]"	       0
		XCTAssertMatchesFNMatch("a", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C		"-"			"[\\\\-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[\\\\-a]", flags: 0, result: NOMATCH)
		// C		"\\"			"[\\]-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("\\", pattern: "[\\]-a]", flags: 0, result: NOMATCH)
		// C		"_"			"[\\]-a]"	       0
		XCTAssertMatchesFNMatch("_", pattern: "[\\]-a]", flags: 0, result: 0)
		// C		"a"			"[\\]-a]"	       0
		XCTAssertMatchesFNMatch("a", pattern: "[\\]-a]", flags: 0, result: 0)
		// C		"]"			"[\\]-a]"	       0
		XCTAssertMatchesFNMatch("]", pattern: "[\\]-a]", flags: 0, result: 0)
		// C		"-"			"[\\]-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[\\]-a]", flags: 0, result: NOMATCH)
		// C		"\\"			"[!\\\\-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("\\", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C		"_"			"[!\\\\-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("_", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C		"a"			"[!\\\\-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C		"-"			"[!\\\\-a]"	       0
		XCTAssertMatchesFNMatch("-", pattern: "[!\\\\-a]", flags: 0, result: 0)
		// C		"!"			"[\\!-]"	       0
		XCTAssertMatchesFNMatch("!", pattern: "[\\!-]", flags: 0, result: 0)
		// C		"-"			"[\\!-]"	       0
		XCTAssertMatchesFNMatch("-", pattern: "[\\!-]", flags: 0, result: 0)
		// C		"\\"			"[\\!-]"	       NOMATCH
		XCTAssertMatchesFNMatch("\\", pattern: "[\\!-]", flags: 0, result: NOMATCH)
		// C		"Z"			"[Z-\\\\]"	       0
		XCTAssertMatchesFNMatch("Z", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C		"["			"[Z-\\\\]"	       0
		XCTAssertMatchesFNMatch("[", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C		"\\"			"[Z-\\\\]"	       0
		XCTAssertMatchesFNMatch("\\", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C		"-"			"[Z-\\\\]"	       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[Z-\\\\]", flags: 0, result: NOMATCH)
		// C		"Z"			"[Z-\\]]"	       0
		XCTAssertMatchesFNMatch("Z", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C		"["			"[Z-\\]]"	       0
		XCTAssertMatchesFNMatch("[", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C		"\\"			"[Z-\\]]"	       0
		XCTAssertMatchesFNMatch("\\", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C		"]"			"[Z-\\]]"	       0
		XCTAssertMatchesFNMatch("]", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C		"-"			"[Z-\\]]"	       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[Z-\\]]", flags: 0, result: NOMATCH)
	}

	//  B.6 004(C) utf8
	func test_b_6_004_c_utf8() throws {
		// C.UTF-8		 "!#%+,-./01234567889"	"!#%+,-./01234567889"  0
		XCTAssertMatchesFNMatch("!#%+,-./01234567889", pattern: "!#%+,-./01234567889", flags: 0, result: 0)
		// C.UTF-8		 ":;=@ABCDEFGHIJKLMNO"	":;=@ABCDEFGHIJKLMNO"  0
		XCTAssertMatchesFNMatch(":;=@ABCDEFGHIJKLMNO", pattern: ":;=@ABCDEFGHIJKLMNO", flags: 0, result: 0)
		// C.UTF-8		 "PQRSTUVWXYZ]abcdefg"	"PQRSTUVWXYZ]abcdefg"  0
		XCTAssertMatchesFNMatch("PQRSTUVWXYZ]abcdefg", pattern: "PQRSTUVWXYZ]abcdefg", flags: 0, result: 0)
		// C.UTF-8		 "hijklmnopqrstuvwxyz"	"hijklmnopqrstuvwxyz"  0
		XCTAssertMatchesFNMatch("hijklmnopqrstuvwxyz", pattern: "hijklmnopqrstuvwxyz", flags: 0, result: 0)
		// C.UTF-8		 "^_{}~"		"^_{}~"		       0
		XCTAssertMatchesFNMatch("^_{}~", pattern: "^_{}~", flags: 0, result: 0)
	}

	//  B.6 005(C) utf8
	func test_b_6_005_c_utf8() throws {
		// C.UTF-8		 "\"$&'()"		"\\\"\\$\\&\\'\\(\\)"  0
		XCTAssertMatchesFNMatch("\"$&'()", pattern: "\\\"\\$\\&\\'\\(\\)", flags: 0, result: 0)
		// C.UTF-8		 "*?[\\`|"		"\\*\\?\\[\\\\\\`\\|"  0
		XCTAssertMatchesFNMatch("*?[\\`|", pattern: "\\*\\?\\[\\\\\\`\\|", flags: 0, result: 0)
		// C.UTF-8		 "<>"			"\\<\\>"	       0
		XCTAssertMatchesFNMatch("<>", pattern: "\\<\\>", flags: 0, result: 0)
	}

	//  B.6 006(C) utf8
	func test_b_6_006_c_utf8() throws {
		// C.UTF-8		 "?*["			"[?*[][?*[][?*[]"      0
		XCTAssertMatchesFNMatch("?*[", pattern: "[?*[][?*[][?*[]", flags: 0, result: 0)
		// C.UTF-8		 "a/b"			"?/b"		       0
		XCTAssertMatchesFNMatch("a/b", pattern: "?/b", flags: 0, result: 0)
	}

	//  B.6 007(C) utf8
	func test_b_6_007_c_utf8() throws {
		// C.UTF-8		 "a/b"			"a?b"		       0
		XCTAssertMatchesFNMatch("a/b", pattern: "a?b", flags: 0, result: 0)
		// C.UTF-8		 "a/b"			"a/?"		       0
		XCTAssertMatchesFNMatch("a/b", pattern: "a/?", flags: 0, result: 0)
		// C.UTF-8		 "aa/b"			"?/b"		       NOMATCH
		XCTAssertMatchesFNMatch("aa/b", pattern: "?/b", flags: 0, result: NOMATCH)
		// C.UTF-8		 "aa/b"			"a?b"		       NOMATCH
		XCTAssertMatchesFNMatch("aa/b", pattern: "a?b", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a/bb"			"a/?"		       NOMATCH
		XCTAssertMatchesFNMatch("a/bb", pattern: "a/?", flags: 0, result: NOMATCH)
	}

	//  B.6 009(C) utf8
	func test_b_6_009_c_utf8() throws {
		// C.UTF-8		 "abc"			"[abc]"		       NOMATCH
		XCTAssertMatchesFNMatch("abc", pattern: "[abc]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "x"			"[abc]"		       NOMATCH
		XCTAssertMatchesFNMatch("x", pattern: "[abc]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[abc]"		       0
		XCTAssertMatchesFNMatch("a", pattern: "[abc]", flags: 0, result: 0)
		// C.UTF-8		 "["			"[[abc]"	       0
		XCTAssertMatchesFNMatch("[", pattern: "[[abc]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[][abc]"	       0
		XCTAssertMatchesFNMatch("a", pattern: "[][abc]", flags: 0, result: 0)
		// C.UTF-8		 "a]"			"[]a]]"		       0
		XCTAssertMatchesFNMatch("a]", pattern: "[]a]]", flags: 0, result: 0)
	}

	//  B.6 010(C) utf8
	func test_b_6_010_c_utf8() throws {
		// C.UTF-8		 "xyz"			"[!abc]"	       NOMATCH
		XCTAssertMatchesFNMatch("xyz", pattern: "[!abc]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "x"			"[!abc]"	       0
		XCTAssertMatchesFNMatch("x", pattern: "[!abc]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[!abc]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[!abc]", flags: 0, result: NOMATCH)
	}

	//  B.6 011(C) utf8
	func test_b_6_011_c_utf8() throws {
		// C.UTF-8		 "]"			"[][abc]"	       0
		XCTAssertMatchesFNMatch("]", pattern: "[][abc]", flags: 0, result: 0)
		// C.UTF-8		 "abc]"			"[][abc]"	       NOMATCH
		XCTAssertMatchesFNMatch("abc]", pattern: "[][abc]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "[]abc"		"[][]abc"	       NOMATCH
		XCTAssertMatchesFNMatch("[]abc", pattern: "[][]abc", flags: 0, result: NOMATCH)
		// C.UTF-8		 "]"			"[!]]"		       NOMATCH
		XCTAssertMatchesFNMatch("]", pattern: "[!]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "aa]"			"[!]a]"		       NOMATCH
		XCTAssertMatchesFNMatch("aa]", pattern: "[!]a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "]"			"[!a]"		       0
		XCTAssertMatchesFNMatch("]", pattern: "[!a]", flags: 0, result: 0)
		// C.UTF-8		 "]]"			"[!a]]"		       0
		XCTAssertMatchesFNMatch("]]", pattern: "[!a]]", flags: 0, result: 0)
	}

	//  B.6 012(C) utf8
	func test_b_6_012_c_utf8() throws {
		XCTExpectFailure {
			// C.UTF-8		 "a"			"[[.a.]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[.a.]]", flags: 0, result: 0)
			// C.UTF-8		 "-"			"[[.-.]]"	       0
			XCTAssertMatchesFNMatch("-", pattern: "[[.-.]]", flags: 0, result: 0)
			// C.UTF-8		 "-"			"[[.-.][.].]]"	       0
			XCTAssertMatchesFNMatch("-", pattern: "[[.-.][.].]]", flags: 0, result: 0)
			// C.UTF-8		 "-"			"[[.].][.-.]]"	       0
			XCTAssertMatchesFNMatch("-", pattern: "[[.].][.-.]]", flags: 0, result: 0)
			// C.UTF-8		 "-"			"[[.-.][=u=]]"	       0
			XCTAssertMatchesFNMatch("-", pattern: "[[.-.][=u=]]", flags: 0, result: 0)
			// C.UTF-8		 "-"			"[[.-.][:alpha:]]"     0
			XCTAssertMatchesFNMatch("-", pattern: "[[.-.][:alpha:]]", flags: 0, result: 0)
			// C.UTF-8		 "a"			"[![.a.]]"	       NOMATCH
			XCTAssertMatchesFNMatch("a", pattern: "[![.a.]]", flags: 0, result: NOMATCH)
		}
	}

	//  B.6 013(C) utf8
	func test_b_6_013_c_utf8() throws {
		// C.UTF-8		 "a"			"[[.b.]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[.b.]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[.b.][.c.]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[.b.][.c.]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[.b.][=b=]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[.b.][=b=]]", flags: 0, result: NOMATCH)
	}

	//  B.6 015(C) utf8
	func test_b_6_015_c_utf8() throws {
		XCTExpectFailure {
			// C.UTF-8		 "a"			"[[=a=]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=a=]]", flags: 0, result: 0)
			// C.UTF-8		 "b"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0)
			// C.UTF-8		 "b"			"[[=a=][=b=]]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=a=][=b=]]", flags: 0, result: 0)
			// C.UTF-8		 "a"			"[[=a=][=b=]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=a=][=b=]]", flags: 0, result: 0)
			// C.UTF-8		 "a"			"[[=a=][.b.]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=a=][.b.]]", flags: 0, result: 0)
			// C.UTF-8		 "a"			"[[=a=][:digit:]]"     0
			XCTAssertMatchesFNMatch("a", pattern: "[[=a=][:digit:]]", flags: 0, result: 0)
		}
	}

	//  B.6 016(C) utf8
	func test_b_6_016_c_utf8() throws {
		// C.UTF-8		 "="			"[[=a=]b]"	       NOMATCH
		XCTAssertMatchesFNMatch("=", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "]"			"[[=a=]b]"	       NOMATCH
		XCTAssertMatchesFNMatch("]", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[=b=][=c=]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][=c=]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[=b=][.].]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][.].]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[=b=][:digit:]]"     NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][:digit:]]", flags: 0, result: NOMATCH)
	}

	//  B.6 017(C) utf8
	func test_b_6_017_c_utf8() throws {
		XCTExpectFailure {
			// C.UTF-8		 "a"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "a"			"[![:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("a", pattern: "[![:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "-"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "a]a"			"[[:alnum:]]a"	       NOMATCH
			XCTAssertMatchesFNMatch("a]a", pattern: "[[:alnum:]]a", flags: 0, result: NOMATCH)
			// C.UTF-8		 "-"			"[[:alnum:]-]"	       0
			XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]-]", flags: 0, result: 0)
			// C.UTF-8		 "aa"			"[[:alnum:]]a"	       0
			XCTAssertMatchesFNMatch("aa", pattern: "[[:alnum:]]a", flags: 0, result: 0)
			// C.UTF-8		 "-"			"[![:alnum:]]"	       0
			XCTAssertMatchesFNMatch("-", pattern: "[![:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "]"			"[!][:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("]", pattern: "[!][:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "["			"[![:alnum:][]"	       NOMATCH
			XCTAssertMatchesFNMatch("[", pattern: "[![:alnum:][]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "a"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "b"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "c"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("c", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "d"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("d", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "e"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("e", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "f"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("f", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "g"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("g", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "h"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("h", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "i"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("i", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "j"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("j", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "k"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("k", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "l"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("l", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "m"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("m", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "n"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("n", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "o"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("o", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "p"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("p", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "q"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("q", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "r"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("r", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "s"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("s", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "t"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("t", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "u"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("u", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "v"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("v", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "w"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("w", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "x"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("x", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "y"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("y", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "z"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("z", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "A"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("A", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "B"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("B", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "C"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("C", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "D"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("D", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "E"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("E", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "F"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("F", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "G"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("G", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "H"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("H", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "I"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("I", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "J"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("J", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "K"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("K", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "L"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("L", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "M"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("M", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "N"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("N", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "O"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("O", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "P"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("P", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "Q"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("Q", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "R"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("R", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "S"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("S", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "T"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("T", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "U"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("U", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "V"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("V", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "W"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("W", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "X"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("X", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "Y"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("Y", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "Z"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("Z", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "0"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("0", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "1"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("1", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "2"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("2", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "3"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("3", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "4"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("4", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "5"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("5", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "6"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("6", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "7"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("7", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "8"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("8", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "9"			"[[:alnum:]]"	       0
			XCTAssertMatchesFNMatch("9", pattern: "[[:alnum:]]", flags: 0, result: 0)
			// C.UTF-8		 "!"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("!", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "#"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("#", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "%"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("%", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "+"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("+", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 ","			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch(",", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "-"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "."			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch(".", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "/"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("/", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 ":"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch(":", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 ";"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch(";", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "="			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("=", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "@"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("@", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "["			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("[", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "\\"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("\\", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "]"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("]", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "^"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("^", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "_"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("_", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "{"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("{", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "}"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("}", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "~"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("~", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "\""			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("\"", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "$"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("$", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "&"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("&", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "'"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("'", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "("			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("(", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 ")"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch(")", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "*"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("*", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "?"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("?", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "`"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("`", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "|"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("|", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "<"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("<", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 ">"			"[[:alnum:]]"	       NOMATCH
			XCTAssertMatchesFNMatch(">", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "\t"			"[[:cntrl:]]"	       0
			XCTAssertMatchesFNMatch("\t", pattern: "[[:cntrl:]]", flags: 0, result: 0)
			// C.UTF-8		 "t"			"[[:cntrl:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("t", pattern: "[[:cntrl:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "t"			"[[:lower:]]"	       0
			XCTAssertMatchesFNMatch("t", pattern: "[[:lower:]]", flags: 0, result: 0)
			// C.UTF-8		 "\t"			"[[:lower:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("\t", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "T"			"[[:lower:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("T", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "\t"			"[[:space:]]"	       0
			XCTAssertMatchesFNMatch("\t", pattern: "[[:space:]]", flags: 0, result: 0)
			// C.UTF-8		 "t"			"[[:space:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("t", pattern: "[[:space:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "t"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("t", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// C.UTF-8		 "\t"			"[[:alpha:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("\t", pattern: "[[:alpha:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "0"			"[[:digit:]]"	       0
			XCTAssertMatchesFNMatch("0", pattern: "[[:digit:]]", flags: 0, result: 0)
			// C.UTF-8		 "\t"			"[[:digit:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("\t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "t"			"[[:digit:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "\t"			"[[:print:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("\t", pattern: "[[:print:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "t"			"[[:print:]]"	       0
			XCTAssertMatchesFNMatch("t", pattern: "[[:print:]]", flags: 0, result: 0)
			// C.UTF-8		 "T"			"[[:upper:]]"	       0
			XCTAssertMatchesFNMatch("T", pattern: "[[:upper:]]", flags: 0, result: 0)
			// C.UTF-8		 "\t"			"[[:upper:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("\t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "t"			"[[:upper:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "\t"			"[[:blank:]]"	       0
			XCTAssertMatchesFNMatch("\t", pattern: "[[:blank:]]", flags: 0, result: 0)
			// C.UTF-8		 "t"			"[[:blank:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("t", pattern: "[[:blank:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "\t"			"[[:graph:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("\t", pattern: "[[:graph:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "t"			"[[:graph:]]"	       0
			XCTAssertMatchesFNMatch("t", pattern: "[[:graph:]]", flags: 0, result: 0)
			// C.UTF-8		 "."			"[[:punct:]]"	       0
			XCTAssertMatchesFNMatch(".", pattern: "[[:punct:]]", flags: 0, result: 0)
			// C.UTF-8		 "t"			"[[:punct:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "\t"			"[[:punct:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("\t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "0"			"[[:xdigit:]]"	       0
			XCTAssertMatchesFNMatch("0", pattern: "[[:xdigit:]]", flags: 0, result: 0)
			// C.UTF-8		 "\t"			"[[:xdigit:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("\t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "a"			"[[:xdigit:]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[:xdigit:]]", flags: 0, result: 0)
			// C.UTF-8		 "A"			"[[:xdigit:]]"	       0
			XCTAssertMatchesFNMatch("A", pattern: "[[:xdigit:]]", flags: 0, result: 0)
			// C.UTF-8		 "t"			"[[:xdigit:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "a"			"[[alpha]]"	       NOMATCH
			XCTAssertMatchesFNMatch("a", pattern: "[[alpha]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "a"			"[[alpha:]]"	       NOMATCH
			XCTAssertMatchesFNMatch("a", pattern: "[[alpha:]]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "a]"			"[[alpha]]"	       0
			XCTAssertMatchesFNMatch("a]", pattern: "[[alpha]]", flags: 0, result: 0)
			// C.UTF-8		 "a]"			"[[alpha:]]"	       0
			XCTAssertMatchesFNMatch("a]", pattern: "[[alpha:]]", flags: 0, result: 0)
			// C.UTF-8		 "a"			"[[:alpha:][.b.]]"     0
			XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][.b.]]", flags: 0, result: 0)
			// C.UTF-8		 "a"			"[[:alpha:][=b=]]"     0
			XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][=b=]]", flags: 0, result: 0)
			// C.UTF-8		 "a"			"[[:alpha:][:digit:]]" 0
			XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][:digit:]]", flags: 0, result: 0)
			// C.UTF-8		 "a"			"[[:digit:][:alpha:]]" 0
			XCTAssertMatchesFNMatch("a", pattern: "[[:digit:][:alpha:]]", flags: 0, result: 0)
		}
	}

	//  B.6 018(C) utf8
	func test_b_6_018_c_utf8() throws {
		// C.UTF-8		 "a"			"[a-c]"		       0
		XCTAssertMatchesFNMatch("a", pattern: "[a-c]", flags: 0, result: 0)
		// C.UTF-8		 "b"			"[a-c]"		       0
		XCTAssertMatchesFNMatch("b", pattern: "[a-c]", flags: 0, result: 0)
		// C.UTF-8		 "c"			"[a-c]"		       0
		XCTAssertMatchesFNMatch("c", pattern: "[a-c]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[b-c]"		       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[b-c]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "d"			"[b-c]"		       NOMATCH
		XCTAssertMatchesFNMatch("d", pattern: "[b-c]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "B"			"[a-c]"		       NOMATCH
		XCTAssertMatchesFNMatch("B", pattern: "[a-c]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "b"			"[A-C]"		       NOMATCH
		XCTAssertMatchesFNMatch("b", pattern: "[A-C]", flags: 0, result: NOMATCH)
		// C.UTF-8		 ""			"[a-c]"		       NOMATCH
		XCTAssertMatchesFNMatch("", pattern: "[a-c]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "as"			"[a-ca-z]"	       NOMATCH
		XCTAssertMatchesFNMatch("as", pattern: "[a-ca-z]", flags: 0, result: NOMATCH)
		XCTExpectFailure {
			// C.UTF-8		 "a"			"[[.a.]-c]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[.a.]-c]", flags: 0, result: 0)
			// C.UTF-8		 "a"			"[a-[.c.]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[a-[.c.]]", flags: 0, result: 0)
			// C.UTF-8		 "a"			"[[.a.]-[.c.]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
			// C.UTF-8		 "b"			"[[.a.]-c]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[.a.]-c]", flags: 0, result: 0)
			// C.UTF-8		 "b"			"[a-[.c.]]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[a-[.c.]]", flags: 0, result: 0)
			// C.UTF-8		 "b"			"[[.a.]-[.c.]]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
			// C.UTF-8		 "c"			"[[.a.]-c]"	       0
			XCTAssertMatchesFNMatch("c", pattern: "[[.a.]-c]", flags: 0, result: 0)
			// C.UTF-8		 "c"			"[a-[.c.]]"	       0
			XCTAssertMatchesFNMatch("c", pattern: "[a-[.c.]]", flags: 0, result: 0)
			// C.UTF-8		 "c"			"[[.a.]-[.c.]]"	       0
			XCTAssertMatchesFNMatch("c", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
			// C.UTF-8		 "d"			"[[.a.]-c]"	       NOMATCH
			XCTAssertMatchesFNMatch("d", pattern: "[[.a.]-c]", flags: 0, result: NOMATCH)
			// C.UTF-8		 "d"			"[a-[.c.]]"	       NOMATCH
			XCTAssertMatchesFNMatch("d", pattern: "[a-[.c.]]", flags: 0, result: NOMATCH)
		}
		// C.UTF-8		 "d"			"[[.a.]-[.c.]]"	       NOMATCH
		XCTAssertMatchesFNMatch("d", pattern: "[[.a.]-[.c.]]", flags: 0, result: NOMATCH)
	}

	//  B.6 019(C) utf8
	func test_b_6_019_c_utf8() throws {
		// C.UTF-8		 "a"			"[c-a]"		       NOMATCH
		XCTExpectFailure {
			XCTAssertMatchesFNMatch("a", pattern: "[c-a]", flags: 0, result: NOMATCH)
		}
		// C.UTF-8		 "a"			"[[.c.]-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[c-[.a.]]"	       NOMATCH
		XCTExpectFailure {
			XCTAssertMatchesFNMatch("a", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH)
		}
		// C.UTF-8		 "a"			"[[.c.]-[.a.]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "c"			"[c-a]"		       NOMATCH
		XCTExpectFailure {
			XCTAssertMatchesFNMatch("c", pattern: "[c-a]", flags: 0, result: NOMATCH)
		}
		// C.UTF-8		 "c"			"[[.c.]-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("c", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "c"			"[c-[.a.]]"	       NOMATCH
		XCTExpectFailure {
			XCTAssertMatchesFNMatch("c", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH)
		}
		// C.UTF-8		 "c"			"[[.c.]-[.a.]]"	       NOMATCH
		XCTAssertMatchesFNMatch("c", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH)
	}

	//  B.6 020(C) utf8
	func test_b_6_020_c_utf8() throws {
		// C.UTF-8		 "a"			"[a-c0-9]"	       0
		XCTAssertMatchesFNMatch("a", pattern: "[a-c0-9]", flags: 0, result: 0)
		// C.UTF-8		 "d"			"[a-c0-9]"	       NOMATCH
		XCTAssertMatchesFNMatch("d", pattern: "[a-c0-9]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "B"			"[a-c0-9]"	       NOMATCH
		XCTAssertMatchesFNMatch("B", pattern: "[a-c0-9]", flags: 0, result: NOMATCH)
	}

	//  B.6 021(C) utf8
	func test_b_6_021_c_utf8() throws {
		// C.UTF-8		 "-"			"[-a]"		       0
		XCTAssertMatchesFNMatch("-", pattern: "[-a]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[-b]"		       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[-b]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "-"			"[!-a]"		       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[!-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[!-b]"		       0
		XCTAssertMatchesFNMatch("a", pattern: "[!-b]", flags: 0, result: 0)
		// C.UTF-8		 "-"			"[a-c-0-9]"	       0
		XCTAssertMatchesFNMatch("-", pattern: "[a-c-0-9]", flags: 0, result: 0)
		// C.UTF-8		 "b"			"[a-c-0-9]"	       0
		XCTAssertMatchesFNMatch("b", pattern: "[a-c-0-9]", flags: 0, result: 0)
		// C.UTF-8		 "a:"			"a[0-9-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("a:", pattern: "a[0-9-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a:"			"a[09-a]"	       0
		XCTAssertMatchesFNMatch("a:", pattern: "a[09-a]", flags: 0, result: 0)
	}

	//  B.6 024(C) utf8
	func test_b_6_024_c_utf8() throws {
		// C.UTF-8		 ""			"*"		       0
		XCTAssertMatchesFNMatch("", pattern: "*", flags: 0, result: 0)
		// C.UTF-8		 "asd/sdf"		"*"		       0
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "*", flags: 0, result: 0)
	}

	//  B.6 025(C) utf8
	func test_b_6_025_c_utf8() throws {
		// C.UTF-8		 "as"			"[a-c][a-z]"	       0
		XCTAssertMatchesFNMatch("as", pattern: "[a-c][a-z]", flags: 0, result: 0)
		// C.UTF-8		 "as"			"??"		       0
		XCTAssertMatchesFNMatch("as", pattern: "??", flags: 0, result: 0)
	}

	//  B.6 026(C) utf8
	func test_b_6_026_c_utf8() throws {
		// C.UTF-8		 "asd/sdf"		"as*df"		       0
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*df", flags: 0, result: 0)
		// C.UTF-8		 "asd/sdf"		"as*"		       0
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*", flags: 0, result: 0)
		// C.UTF-8		 "asd/sdf"		"*df"		       0
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "*df", flags: 0, result: 0)
		// C.UTF-8		 "asd/sdf"		"as*dg"		       NOMATCH
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*dg", flags: 0, result: NOMATCH)
		// C.UTF-8		 "asdf"			"as*df"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "as*df", flags: 0, result: 0)
		// C.UTF-8		 "asdf"			"as*df?"	       NOMATCH
		XCTAssertMatchesFNMatch("asdf", pattern: "as*df?", flags: 0, result: NOMATCH)
		// C.UTF-8		 "asdf"			"as*??"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "as*??", flags: 0, result: 0)
		// C.UTF-8		 "asdf"			"a*???"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "a*???", flags: 0, result: 0)
		// C.UTF-8		 "asdf"			"*????"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "*????", flags: 0, result: 0)
		// C.UTF-8		 "asdf"			"????*"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "????*", flags: 0, result: 0)
		// C.UTF-8		 "asdf"			"??*?"		       0
		XCTAssertMatchesFNMatch("asdf", pattern: "??*?", flags: 0, result: 0)
	}

	//  B.6 027(C) utf8
	func test_b_6_027_c_utf8() throws {
		// C.UTF-8		 "/"			"/"		       0
		XCTAssertMatchesFNMatch("/", pattern: "/", flags: 0, result: 0)
		// C.UTF-8		 "/"			"/*"		       0
		XCTAssertMatchesFNMatch("/", pattern: "/*", flags: 0, result: 0)
		// C.UTF-8		 "/"			"*/"		       0
		XCTAssertMatchesFNMatch("/", pattern: "*/", flags: 0, result: 0)
		// C.UTF-8		 "/"			"/?"		       NOMATCH
		XCTAssertMatchesFNMatch("/", pattern: "/?", flags: 0, result: NOMATCH)
		// C.UTF-8		 "/"			"?/"		       NOMATCH
		XCTAssertMatchesFNMatch("/", pattern: "?/", flags: 0, result: NOMATCH)
		// C.UTF-8		 "/"			"?"		       0
		XCTAssertMatchesFNMatch("/", pattern: "?", flags: 0, result: 0)
		// C.UTF-8		 "."			"?"		       0
		XCTAssertMatchesFNMatch(".", pattern: "?", flags: 0, result: 0)
		// C.UTF-8		 "/."			"??"		       0
		XCTAssertMatchesFNMatch("/.", pattern: "??", flags: 0, result: 0)
		// C.UTF-8		 "/"			"[!a-c]"	       0
		XCTAssertMatchesFNMatch("/", pattern: "[!a-c]", flags: 0, result: 0)
		// C.UTF-8		 "."			"[!a-c]"	       0
		XCTAssertMatchesFNMatch(".", pattern: "[!a-c]", flags: 0, result: 0)
	}

	//  B.6 029(C) utf8
	func test_b_6_029_c_utf8() throws {
		// C.UTF-8		 "/"			"/"		       0       PATHNAME
		XCTAssertMatchesFNMatch("/", pattern: "/", flags: PATHNAME, result: 0)
		// C.UTF-8		 "//"			"//"		       0       PATHNAME
		XCTAssertMatchesFNMatch("//", pattern: "//", flags: PATHNAME, result: 0)
		// C.UTF-8		 "/.a"			"/*"		       0       PATHNAME
		XCTAssertMatchesFNMatch("/.a", pattern: "/*", flags: PATHNAME, result: 0)
		// C.UTF-8		 "/.a"			"/?a"		       0       PATHNAME
		XCTAssertMatchesFNMatch("/.a", pattern: "/?a", flags: PATHNAME, result: 0)
		// C.UTF-8		 "/.a"			"/[!a-z]a"	       0       PATHNAME
		XCTAssertMatchesFNMatch("/.a", pattern: "/[!a-z]a", flags: PATHNAME, result: 0)
		// C.UTF-8		 "/.a/.b"		"/*/?b"		       0       PATHNAME
		XCTAssertMatchesFNMatch("/.a/.b", pattern: "/*/?b", flags: PATHNAME, result: 0)
	}

	//  B.6 030(C) utf8
	func test_b_6_030_c_utf8() throws {
		// C.UTF-8		 "/"			"?"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("/", pattern: "?", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		 "/"			"*"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("/", pattern: "*", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		 "a/b"			"a?b"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("a/b", pattern: "a?b", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		 "/.a/.b"		"/*b"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("/.a/.b", pattern: "/*b", flags: PATHNAME, result: NOMATCH)
	}

	//  B.6 031(C) utf8
	func test_b_6_031_c_utf8() throws {
		// C.UTF-8		 "/$"			"\\/\\$"	       0
		XCTAssertMatchesFNMatch("/$", pattern: "\\/\\$", flags: 0, result: 0)
		// C.UTF-8		 "/["			"\\/\\["	       0
		XCTAssertMatchesFNMatch("/[", pattern: "\\/\\[", flags: 0, result: 0)
		XCTExpectFailure {
			// C.UTF-8		 "/["			"\\/["		       0
			XCTAssertMatchesFNMatch("/[", pattern: "\\/[", flags: 0, result: 0)
		}
		// C.UTF-8		 "/[]"			"\\/\\[]"	       0
		XCTAssertMatchesFNMatch("/[]", pattern: "\\/\\[]", flags: 0, result: 0)
	}

	//  B.6 032(C) utf8
	func test_b_6_032_c_utf8() throws {
		// C.UTF-8		 "/$"			"\\/\\$"	       NOMATCH NOESCAPE
		XCTExpectFailure {
			XCTAssertMatchesFNMatch("/$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH)
		}
		// C.UTF-8		 "/\\$"			"\\/\\$"	       NOMATCH NOESCAPE
		XCTAssertMatchesFNMatch("/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH)
		// C.UTF-8		 "\\/\\$"		"\\/\\$"	       0       NOESCAPE
		XCTExpectFailure {
			XCTAssertMatchesFNMatch("\\/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: 0)
		}
	}

	//  B.6 033(C) utf8
	func test_b_6_033_c_utf8() throws {
		// C.UTF-8		 ".asd"			".*"		       0       PERIOD
		XCTAssertMatchesFNMatch(".asd", pattern: ".*", flags: PERIOD, result: 0)
		// C.UTF-8		 "/.asd"		"*"		       0       PERIOD
		XCTAssertMatchesFNMatch("/.asd", pattern: "*", flags: PERIOD, result: 0)
		// C.UTF-8		 "/as/.df"		"*/?*f"		       0       PERIOD
		XCTAssertMatchesFNMatch("/as/.df", pattern: "*/?*f", flags: PERIOD, result: 0)
		// C.UTF-8		 "..asd"		".[!a-z]*"	       0       PERIOD
		XCTAssertMatchesFNMatch("..asd", pattern: ".[!a-z]*", flags: PERIOD, result: 0)
	}

	//  B.6 034(C) utf8
	func test_b_6_034_c_utf8() throws {
		XCTExpectFailure {
			// C.UTF-8		 ".asd"			"*"		       NOMATCH PERIOD
			XCTAssertMatchesFNMatch(".asd", pattern: "*", flags: PERIOD, result: NOMATCH)
			// C.UTF-8		 ".asd"			"?asd"		       NOMATCH PERIOD
			XCTAssertMatchesFNMatch(".asd", pattern: "?asd", flags: PERIOD, result: NOMATCH)
			// C.UTF-8		 ".asd"			"[!a-z]*"	       NOMATCH PERIOD
			XCTAssertMatchesFNMatch(".asd", pattern: "[!a-z]*", flags: PERIOD, result: NOMATCH)
		}
	}

	//  B.6 035(C) utf8
	func test_b_6_035_c_utf8() throws {
		// C.UTF-8		 "/."			"/."		       0       PATHNAME|PERIOD
		XCTAssertMatchesFNMatch("/.", pattern: "/.", flags: PATHNAME | PERIOD, result: 0)
		// C.UTF-8		 "/.a./.b."		"/.*/.*"	       0       PATHNAME|PERIOD
		XCTAssertMatchesFNMatch("/.a./.b.", pattern: "/.*/.*", flags: PATHNAME | PERIOD, result: 0)
		// C.UTF-8		 "/.a./.b."		"/.??/.??"	       0       PATHNAME|PERIOD
		XCTAssertMatchesFNMatch("/.a./.b.", pattern: "/.??/.??", flags: PATHNAME | PERIOD, result: 0)
	}

	//  B.6 036(C) utf8
	func test_b_6_036_c_utf8() throws {
		// C.UTF-8		 "/."			"*"		       NOMATCH PATHNAME|PERIOD
		XCTAssertMatchesFNMatch("/.", pattern: "*", flags: PATHNAME | PERIOD, result: NOMATCH)
		XCTExpectFailure {
			// C.UTF-8		 "/."			"/*"		       NOMATCH PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("/.", pattern: "/*", flags: PATHNAME | PERIOD, result: NOMATCH)
			// C.UTF-8		 "/."			"/?"		       NOMATCH PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("/.", pattern: "/?", flags: PATHNAME | PERIOD, result: NOMATCH)
			// C.UTF-8		 "/."			"/[!a-z]"	       NOMATCH PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("/.", pattern: "/[!a-z]", flags: PATHNAME | PERIOD, result: NOMATCH)
			// C.UTF-8		 "/a./.b."		"/*/*"		       NOMATCH PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("/a./.b.", pattern: "/*/*", flags: PATHNAME | PERIOD, result: NOMATCH)
			// C.UTF-8		 "/a./.b."		"/??/???"	       NOMATCH PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("/a./.b.", pattern: "/??/???", flags: PATHNAME | PERIOD, result: NOMATCH)
		}
	}

	//  Some home-grown tests.
	func test_some_home_grown_tests() throws {
		// C.UTF-8		"foobar"		"foo*[abc]z"	       NOMATCH
		XCTAssertMatchesFNMatch("foobar", pattern: "foo*[abc]z", flags: 0, result: NOMATCH)
		// C.UTF-8		"foobaz"		"foo*[abc][xyz]"       0
		XCTAssertMatchesFNMatch("foobaz", pattern: "foo*[abc][xyz]", flags: 0, result: 0)
		// C.UTF-8		"foobaz"		"foo?*[abc][xyz]"      0
		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc][xyz]", flags: 0, result: 0)
		// C.UTF-8		"foobaz"		"foo?*[abc][x/yz]"     0
		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc][x/yz]", flags: 0, result: 0)
		// C.UTF-8		"foobaz"		"foo?*[abc]/[xyz]"     NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc]/[xyz]", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		"a"			"a/"                   NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("a", pattern: "a/", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		"a/"			"a"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("a/", pattern: "a", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		"//a"			"/a"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("//a", pattern: "/a", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		"/a"			"//a"		       NOMATCH PATHNAME
		XCTAssertMatchesFNMatch("/a", pattern: "//a", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		"az"			"[a-]z"		       0
		XCTAssertMatchesFNMatch("az", pattern: "[a-]z", flags: 0, result: 0)
		// C.UTF-8		"bz"			"[ab-]z"	       0
		XCTAssertMatchesFNMatch("bz", pattern: "[ab-]z", flags: 0, result: 0)
		// C.UTF-8		"cz"			"[ab-]z"	       NOMATCH
		XCTAssertMatchesFNMatch("cz", pattern: "[ab-]z", flags: 0, result: NOMATCH)
		// C.UTF-8		"-z"			"[ab-]z"	       0
		XCTAssertMatchesFNMatch("-z", pattern: "[ab-]z", flags: 0, result: 0)
		// C.UTF-8		"az"			"[-a]z"		       0
		XCTAssertMatchesFNMatch("az", pattern: "[-a]z", flags: 0, result: 0)
		// C.UTF-8		"bz"			"[-ab]z"	       0
		XCTAssertMatchesFNMatch("bz", pattern: "[-ab]z", flags: 0, result: 0)
		// C.UTF-8		"cz"			"[-ab]z"	       NOMATCH
		XCTAssertMatchesFNMatch("cz", pattern: "[-ab]z", flags: 0, result: NOMATCH)
		// C.UTF-8		"-z"			"[-ab]z"	       0
		XCTAssertMatchesFNMatch("-z", pattern: "[-ab]z", flags: 0, result: 0)
		// C.UTF-8		"\\"			"[\\\\-a]"	       0
		XCTAssertMatchesFNMatch("\\", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C.UTF-8		"_"			"[\\\\-a]"	       0
		XCTAssertMatchesFNMatch("_", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C.UTF-8		"a"			"[\\\\-a]"	       0
		XCTAssertMatchesFNMatch("a", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C.UTF-8		"-"			"[\\\\-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[\\\\-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"\\"			"[\\]-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("\\", pattern: "[\\]-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"_"			"[\\]-a]"	       0
		XCTAssertMatchesFNMatch("_", pattern: "[\\]-a]", flags: 0, result: 0)
		// C.UTF-8		"a"			"[\\]-a]"	       0
		XCTAssertMatchesFNMatch("a", pattern: "[\\]-a]", flags: 0, result: 0)
		// C.UTF-8		"]"			"[\\]-a]"	       0
		XCTAssertMatchesFNMatch("]", pattern: "[\\]-a]", flags: 0, result: 0)
		// C.UTF-8		"-"			"[\\]-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[\\]-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"\\"			"[!\\\\-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("\\", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"_"			"[!\\\\-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("_", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"a"			"[!\\\\-a]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"-"			"[!\\\\-a]"	       0
		XCTAssertMatchesFNMatch("-", pattern: "[!\\\\-a]", flags: 0, result: 0)
		// C.UTF-8		"!"			"[\\!-]"	       0
		XCTAssertMatchesFNMatch("!", pattern: "[\\!-]", flags: 0, result: 0)
		// C.UTF-8		"-"			"[\\!-]"	       0
		XCTAssertMatchesFNMatch("-", pattern: "[\\!-]", flags: 0, result: 0)
		// C.UTF-8		"\\"			"[\\!-]"	       NOMATCH
		XCTAssertMatchesFNMatch("\\", pattern: "[\\!-]", flags: 0, result: NOMATCH)
		// C.UTF-8		"Z"			"[Z-\\\\]"	       0
		XCTAssertMatchesFNMatch("Z", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C.UTF-8		"["			"[Z-\\\\]"	       0
		XCTAssertMatchesFNMatch("[", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C.UTF-8		"\\"			"[Z-\\\\]"	       0
		XCTAssertMatchesFNMatch("\\", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C.UTF-8		"-"			"[Z-\\\\]"	       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[Z-\\\\]", flags: 0, result: NOMATCH)
		// C.UTF-8		"Z"			"[Z-\\]]"	       0
		XCTAssertMatchesFNMatch("Z", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C.UTF-8		"["			"[Z-\\]]"	       0
		XCTAssertMatchesFNMatch("[", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C.UTF-8		"\\"			"[Z-\\]]"	       0
		XCTAssertMatchesFNMatch("\\", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C.UTF-8		"]"			"[Z-\\]]"	       0
		XCTAssertMatchesFNMatch("]", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C.UTF-8		"-"			"[Z-\\]]"	       NOMATCH
		XCTAssertMatchesFNMatch("-", pattern: "[Z-\\]]", flags: 0, result: NOMATCH)
	}

	//  Character vs bytes
	func test_character_vs_bytes() throws {
		// de_DE.ISO-8859-1 "a"			"[a-z]"		       0
		XCTAssertMatchesFNMatch("a", pattern: "[a-z]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "z"			"[a-z]"		       0
		XCTAssertMatchesFNMatch("z", pattern: "[a-z]", flags: 0, result: 0)
		XCTExpectFailure {
			// de_DE.ISO-8859-1 "\344"			"[a-z]"		       0
			XCTAssertMatchesFNMatch("\u{e4}", pattern: "[a-z]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\366"			"[a-z]"		       0
			XCTAssertMatchesFNMatch("\u{f6}", pattern: "[a-z]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\374"			"[a-z]"		       0
			XCTAssertMatchesFNMatch("\u{fc}", pattern: "[a-z]", flags: 0, result: 0)
		}
		// de_DE.ISO-8859-1 "A"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("A", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "Z"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("Z", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\304"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("\u{c4}", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\326"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("\u{d6}", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\334"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("\u{dc}", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "a"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "z"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("z", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\344"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("\u{e4}", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\366"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("\u{f6}", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\374"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("\u{fc}", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "A"			"[A-Z]"		       0
		XCTAssertMatchesFNMatch("A", pattern: "[A-Z]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "Z"			"[A-Z]"		       0
		XCTAssertMatchesFNMatch("Z", pattern: "[A-Z]", flags: 0, result: 0)
		XCTExpectFailure {
			// de_DE.ISO-8859-1 "\304"			"[A-Z]"		       0
			XCTAssertMatchesFNMatch("\u{c4}", pattern: "[A-Z]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\326"			"[A-Z]"		       0
			XCTAssertMatchesFNMatch("\u{d6}", pattern: "[A-Z]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\334"			"[A-Z]"		       0
			XCTAssertMatchesFNMatch("\u{dc}", pattern: "[A-Z]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "a"			"[[:lower:]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "z"			"[[:lower:]]"	       0
			XCTAssertMatchesFNMatch("z", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[:lower:]]"	       0
			XCTAssertMatchesFNMatch("\u{e4}", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\366"			"[[:lower:]]"	       0
			XCTAssertMatchesFNMatch("\u{f6}", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\374"			"[[:lower:]]"	       0
			XCTAssertMatchesFNMatch("\u{fc}", pattern: "[[:lower:]]", flags: 0, result: 0)
		}
		// de_DE.ISO-8859-1 "A"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("A", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "Z"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("Z", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\304"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\u{c4}", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\326"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\u{d6}", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\334"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\u{dc}", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "a"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "z"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("z", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\344"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\u{e4}", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\366"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\u{f6}", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\374"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("\u{fc}", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		XCTExpectFailure {
			// de_DE.ISO-8859-1 "A"			"[[:upper:]]"	       0
			XCTAssertMatchesFNMatch("A", pattern: "[[:upper:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "Z"			"[[:upper:]]"	       0
			XCTAssertMatchesFNMatch("Z", pattern: "[[:upper:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\304"			"[[:upper:]]"	       0
			XCTAssertMatchesFNMatch("\u{c4}", pattern: "[[:upper:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\326"			"[[:upper:]]"	       0
			XCTAssertMatchesFNMatch("\u{d6}", pattern: "[[:upper:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\334"			"[[:upper:]]"	       0
			XCTAssertMatchesFNMatch("\u{dc}", pattern: "[[:upper:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "a"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "z"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("z", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("\u{e4}", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\366"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("\u{f6}", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\374"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("\u{fc}", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "A"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("A", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "Z"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("Z", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\304"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("\u{c4}", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\326"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("\u{d6}", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\334"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("\u{dc}", pattern: "[[:alpha:]]", flags: 0, result: 0)

			// de_DE.ISO-8859-1 "a"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\342"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e2}", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\340"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e0}", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\341"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e1}", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e4}", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "b"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "c"			"[[=a=]b]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
			// de_DE.ISO-8859-1 "a"			"[[=\342=]b]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\342"			"[[=\342=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e2}", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\340"			"[[=\342=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e0}", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\341"			"[[=\342=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e1}", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[=\342=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e4}", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "b"			"[[=\342=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "c"			"[[=\342=]b]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[=\u{e2}=]b]", flags: 0, result: NOMATCH)
			// de_DE.ISO-8859-1 "a"			"[[=\340=]b]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\342"			"[[=\340=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e2}", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\340"			"[[=\340=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e0}", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\341"			"[[=\340=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e1}", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[=\340=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e4}", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "b"			"[[=\340=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "c"			"[[=\340=]b]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[=\u{e0}=]b]", flags: 0, result: NOMATCH)
			// de_DE.ISO-8859-1 "a"			"[[=\341=]b]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\342"			"[[=\341=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e2}", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\340"			"[[=\341=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e0}", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\341"			"[[=\341=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e1}", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[=\341=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e4}", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "b"			"[[=\341=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "c"			"[[=\341=]b]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[=\u{e1}=]b]", flags: 0, result: NOMATCH)
			// de_DE.ISO-8859-1 "a"			"[[=\344=]b]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\342"			"[[=\344=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e2}", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\340"			"[[=\344=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e0}", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\341"			"[[=\344=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e1}", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[=\344=]b]"	       0
			XCTAssertMatchesFNMatch("\u{e4}", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "b"			"[[=\344=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "c"			"[[=\344=]b]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[=\u{e4}=]b]", flags: 0, result: NOMATCH)

			// de_DE.ISO-8859-1 "aa"			"[[.a.]]a"	       0
			XCTAssertMatchesFNMatch("aa", pattern: "[[.a.]]a", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "ba"			"[[.a.]]a"	       NOMATCH
			XCTAssertMatchesFNMatch("ba", pattern: "[[.a.]]a", flags: 0, result: NOMATCH)
		}
	}

	//  multibyte character set
	func test_multibyte_character_set() throws {
		// en_US.UTF-8	 "a"			"[a-z]"		       0
		XCTAssertMatchesFNMatch("a", pattern: "[a-z]", flags: 0, result: 0)
		// en_US.UTF-8	 "z"			"[a-z]"		       0
		XCTAssertMatchesFNMatch("z", pattern: "[a-z]", flags: 0, result: 0)
		// en_US.UTF-8	 "A"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("A", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// en_US.UTF-8	 "Z"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("Z", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// en_US.UTF-8	 "a"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// en_US.UTF-8	 "z"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("z", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// en_US.UTF-8	 "A"			"[A-Z]"		       0
		XCTAssertMatchesFNMatch("A", pattern: "[A-Z]", flags: 0, result: 0)
		// en_US.UTF-8	 "Z"			"[A-Z]"		       0
		XCTAssertMatchesFNMatch("Z", pattern: "[A-Z]", flags: 0, result: 0)
		// en_US.UTF-8	 "0"			"[0-9]"		       0
		XCTAssertMatchesFNMatch("0", pattern: "[0-9]", flags: 0, result: 0)
		// en_US.UTF-8	 "9"			"[0-9]"		       0
		XCTAssertMatchesFNMatch("9", pattern: "[0-9]", flags: 0, result: 0)
		// de_DE.UTF-8	 "a"			"[a-z]"		       0
		XCTAssertMatchesFNMatch("a", pattern: "[a-z]", flags: 0, result: 0)
		// de_DE.UTF-8	 "z"			"[a-z]"		       0
		XCTAssertMatchesFNMatch("z", pattern: "[a-z]", flags: 0, result: 0)
		XCTExpectFailure {
			// de_DE.UTF-8	 "ä"			"[a-z]"		       0
			XCTAssertMatchesFNMatch("ä", pattern: "[a-z]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ö"			"[a-z]"		       0
			XCTAssertMatchesFNMatch("ö", pattern: "[a-z]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ü"			"[a-z]"		       0
			XCTAssertMatchesFNMatch("ü", pattern: "[a-z]", flags: 0, result: 0)
		}
		// de_DE.UTF-8	 "A"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("A", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Z"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("Z", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ä"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("Ä", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ö"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("Ö", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ü"			"[a-z]"		       NOMATCH
		XCTAssertMatchesFNMatch("Ü", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "a"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "z"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("z", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ä"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("ä", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ö"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("ö", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ü"			"[A-Z]"		       NOMATCH
		XCTAssertMatchesFNMatch("ü", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "A"			"[A-Z]"		       0
		XCTAssertMatchesFNMatch("A", pattern: "[A-Z]", flags: 0, result: 0)
		// de_DE.UTF-8	 "Z"			"[A-Z]"		       0
		XCTAssertMatchesFNMatch("Z", pattern: "[A-Z]", flags: 0, result: 0)
		XCTExpectFailure {
			// de_DE.UTF-8	 "Ä"			"[A-Z]"		       0
			XCTAssertMatchesFNMatch("Ä", pattern: "[A-Z]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Ö"			"[A-Z]"		       0
			XCTAssertMatchesFNMatch("Ö", pattern: "[A-Z]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Ü"			"[A-Z]"		       0
			XCTAssertMatchesFNMatch("Ü", pattern: "[A-Z]", flags: 0, result: 0)
			// de_DE.UTF-8	 "a"			"[[:lower:]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "z"			"[[:lower:]]"	       0
			XCTAssertMatchesFNMatch("z", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[:lower:]]"	       0
			XCTAssertMatchesFNMatch("ä", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ö"			"[[:lower:]]"	       0
			XCTAssertMatchesFNMatch("ö", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ü"			"[[:lower:]]"	       0
			XCTAssertMatchesFNMatch("ü", pattern: "[[:lower:]]", flags: 0, result: 0)
		}
		// de_DE.UTF-8	 "A"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("A", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Z"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("Z", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ä"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("Ä", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ö"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("Ö", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ü"			"[[:lower:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("Ü", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "a"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("a", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "z"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("z", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ä"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("ä", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ö"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("ö", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ü"			"[[:upper:]]"	       NOMATCH
		XCTAssertMatchesFNMatch("ü", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		XCTExpectFailure {
			// de_DE.UTF-8	 "A"			"[[:upper:]]"	       0
			XCTAssertMatchesFNMatch("A", pattern: "[[:upper:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Z"			"[[:upper:]]"	       0
			XCTAssertMatchesFNMatch("Z", pattern: "[[:upper:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Ä"			"[[:upper:]]"	       0
			XCTAssertMatchesFNMatch("Ä", pattern: "[[:upper:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Ö"			"[[:upper:]]"	       0
			XCTAssertMatchesFNMatch("Ö", pattern: "[[:upper:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Ü"			"[[:upper:]]"	       0
			XCTAssertMatchesFNMatch("Ü", pattern: "[[:upper:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "a"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "z"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("z", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("ä", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ö"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("ö", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ü"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("ü", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "A"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("A", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Z"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("Z", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Ä"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("Ä", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Ö"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("Ö", pattern: "[[:alpha:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Ü"			"[[:alpha:]]"	       0
			XCTAssertMatchesFNMatch("Ü", pattern: "[[:alpha:]]", flags: 0, result: 0)

			// de_DE.UTF-8	 "a"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "â"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("â", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "à"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("à", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "á"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("á", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("ä", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "b"			"[[=a=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "c"			"[[=a=]b]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
			// de_DE.UTF-8	 "a"			"[[=â=]b]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "â"			"[[=â=]b]"	       0
			XCTAssertMatchesFNMatch("â", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "à"			"[[=â=]b]"	       0
			XCTAssertMatchesFNMatch("à", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "á"			"[[=â=]b]"	       0
			XCTAssertMatchesFNMatch("á", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[=â=]b]"	       0
			XCTAssertMatchesFNMatch("ä", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "b"			"[[=â=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "c"			"[[=â=]b]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[=â=]b]", flags: 0, result: NOMATCH)
			// de_DE.UTF-8	 "a"			"[[=à=]b]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "â"			"[[=à=]b]"	       0
			XCTAssertMatchesFNMatch("â", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "à"			"[[=à=]b]"	       0
			XCTAssertMatchesFNMatch("à", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "á"			"[[=à=]b]"	       0
			XCTAssertMatchesFNMatch("á", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[=à=]b]"	       0
			XCTAssertMatchesFNMatch("ä", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "b"			"[[=à=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "c"			"[[=à=]b]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[=à=]b]", flags: 0, result: NOMATCH)
			// de_DE.UTF-8	 "a"			"[[=á=]b]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "â"			"[[=á=]b]"	       0
			XCTAssertMatchesFNMatch("â", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "à"			"[[=á=]b]"	       0
			XCTAssertMatchesFNMatch("à", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "á"			"[[=á=]b]"	       0
			XCTAssertMatchesFNMatch("á", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[=á=]b]"	       0
			XCTAssertMatchesFNMatch("ä", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "b"			"[[=á=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "c"			"[[=á=]b]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[=á=]b]", flags: 0, result: NOMATCH)
			// de_DE.UTF-8	 "a"			"[[=ä=]b]"	       0
			XCTAssertMatchesFNMatch("a", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "â"			"[[=ä=]b]"	       0
			XCTAssertMatchesFNMatch("â", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "à"			"[[=ä=]b]"	       0
			XCTAssertMatchesFNMatch("à", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "á"			"[[=ä=]b]"	       0
			XCTAssertMatchesFNMatch("á", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[=ä=]b]"	       0
			XCTAssertMatchesFNMatch("ä", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "b"			"[[=ä=]b]"	       0
			XCTAssertMatchesFNMatch("b", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "c"			"[[=ä=]b]"	       NOMATCH
			XCTAssertMatchesFNMatch("c", pattern: "[[=ä=]b]", flags: 0, result: NOMATCH)

			// de_DE.UTF-8	 "aa"			"[[.a.]]a"	       0
			XCTAssertMatchesFNMatch("aa", pattern: "[[.a.]]a", flags: 0, result: 0)
			// de_DE.UTF-8	 "ba"			"[[.a.]]a"	       NOMATCH
			XCTAssertMatchesFNMatch("ba", pattern: "[[.a.]]a", flags: 0, result: NOMATCH)
		}
	}

	//  GNU extensions.
	func test_gnu_extensions() throws {
		XCTExpectFailure {
			// C		 "x"			"x"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x/y"			"x"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x/y/z"		"x"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y/z", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x"			"*"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x/y"			"*"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x/y/z"		"*"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y/z", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x"			"*x"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0)

			// C		 "x/y"			"*x"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x/y/z"		"*x"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y/z", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x"			"x*"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x/y"			"x*"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x/y/z"		"x*"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y/z", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x"			"a"		       NOMATCH PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
			// C		 "x/y"			"a"		       NOMATCH PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
			// C		 "x/y/z"		"a"		       NOMATCH PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y/z", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
			// C		 "x"			"x/y"		       NOMATCH PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
			// C		 "x/y"			"x/y"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x/y/z"		"x/y"		       0       PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y/z", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: 0)
			// C		 "x"			"x?y"		       NOMATCH PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
			// C		 "x/y"			"x?y"		       NOMATCH PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
			// C		 "x/y/z"		"x?y"		       NOMATCH PATHNAME|LEADING_DIR
			XCTAssertMatchesFNMatch("x/y/z", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
		}
	}

	//  Bug 14185
	func test_bug_14185() throws {
		// en_US.UTF-8	 "\366.csv"		"*.csv"                0
		XCTAssertMatchesFNMatch("\u{f6}.csv", pattern: "*.csv", flags: 0, result: 0)
	}

	//  ksh style matching.
	func test_ksh_style_matching() throws {
		XCTExpectFailure {
			// C		"abcd"			"?@(a|b)*@(c)d"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("abcd", pattern: "?@(a|b)*@(c)d", flags: EXTMATCH, result: 0)
			// C		"/dev/udp/129.22.8.102/45" "/dev/@(tcp|udp)/*/*" 0     PATHNAME|EXTMATCH
			XCTAssertMatchesFNMatch("/dev/udp/129.22.8.102/45", pattern: "/dev/@(tcp|udp)/*/*", flags: PATHNAME | EXTMATCH, result: 0)
			// C		"12"			"[1-9]*([0-9])"        0       EXTMATCH
			XCTAssertMatchesFNMatch("12", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: 0)
			// C		"12abc"			"[1-9]*([0-9])"        NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("12abc", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH)
			// C		"1"			"[1-9]*([0-9])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("1", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: 0)
			// C		"07"			"+([0-7])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("07", pattern: "+([0-7])", flags: EXTMATCH, result: 0)
			// C		"0377"			"+([0-7])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("0377", pattern: "+([0-7])", flags: EXTMATCH, result: 0)
			// C		"09"			"+([0-7])"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("09", pattern: "+([0-7])", flags: EXTMATCH, result: NOMATCH)
			// C		"paragraph"		"para@(chute|graph)"   0       EXTMATCH
			XCTAssertMatchesFNMatch("paragraph", pattern: "para@(chute|graph)", flags: EXTMATCH, result: 0)
			// C		"paramour"		"para@(chute|graph)"   NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("paramour", pattern: "para@(chute|graph)", flags: EXTMATCH, result: NOMATCH)
			// C		"para991"		"para?([345]|99)1"     0       EXTMATCH
			XCTAssertMatchesFNMatch("para991", pattern: "para?([345]|99)1", flags: EXTMATCH, result: 0)
			// C		"para381"		"para?([345]|99)1"     NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("para381", pattern: "para?([345]|99)1", flags: EXTMATCH, result: NOMATCH)
			// C		"paragraph"		"para*([0-9])"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("paragraph", pattern: "para*([0-9])", flags: EXTMATCH, result: NOMATCH)
			// C		"para"			"para*([0-9])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("para", pattern: "para*([0-9])", flags: EXTMATCH, result: 0)
			// C		"para13829383746592"	"para*([0-9])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("para13829383746592", pattern: "para*([0-9])", flags: EXTMATCH, result: 0)
			// C		"paragraph"		"para+([0-9])"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("paragraph", pattern: "para+([0-9])", flags: EXTMATCH, result: NOMATCH)
			// C		"para"			"para+([0-9])"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("para", pattern: "para+([0-9])", flags: EXTMATCH, result: NOMATCH)
			// C		"para987346523"		"para+([0-9])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("para987346523", pattern: "para+([0-9])", flags: EXTMATCH, result: 0)
			// C		"paragraph"		"para!(*.[0-9])"       0       EXTMATCH
			XCTAssertMatchesFNMatch("paragraph", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0)
			// C		"para.38"		"para!(*.[0-9])"       0       EXTMATCH
			XCTAssertMatchesFNMatch("para.38", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0)
			// C		"para.graph"		"para!(*.[0-9])"       0       EXTMATCH
			XCTAssertMatchesFNMatch("para.graph", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0)
			// C		"para39"		"para!(*.[0-9])"       0       EXTMATCH
			XCTAssertMatchesFNMatch("para39", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0)
			// C		""			"*(0|1|3|5|7|9)"       0       EXTMATCH
			XCTAssertMatchesFNMatch("", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: 0)
			// C		"137577991"		"*(0|1|3|5|7|9)"       0       EXTMATCH
			XCTAssertMatchesFNMatch("137577991", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: 0)
			// C		"2468"			"*(0|1|3|5|7|9)"       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("2468", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: NOMATCH)
			// C		"1358"			"*(0|1|3|5|7|9)"       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("1358", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: NOMATCH)
			// C		"file.c"		"*.c?(c)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("file.c", pattern: "*.c?(c)", flags: EXTMATCH, result: 0)
			// C		"file.C"		"*.c?(c)"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("file.C", pattern: "*.c?(c)", flags: EXTMATCH, result: NOMATCH)
			// C		"file.cc"		"*.c?(c)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("file.cc", pattern: "*.c?(c)", flags: EXTMATCH, result: 0)
			// C		"file.ccc"		"*.c?(c)"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("file.ccc", pattern: "*.c?(c)", flags: EXTMATCH, result: NOMATCH)
			// C		"parse.y"		"!(*.c|*.h|Makefile.in|config*|README)" 0 EXTMATCH
			XCTAssertMatchesFNMatch("parse.y", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: 0)
			// C		"shell.c"		"!(*.c|*.h|Makefile.in|config*|README)" NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("shell.c", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: NOMATCH)
			// C		"Makefile"		"!(*.c|*.h|Makefile.in|config*|README)" 0 EXTMATCH
			XCTAssertMatchesFNMatch("Makefile", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: 0)
			// C		"VMS.FILE;1"		"*\;[1-9]*([0-9])"     0       EXTMATCH
			XCTAssertMatchesFNMatch("VMS.FILE;1", pattern: "*;[1-9]*([0-9])", flags: EXTMATCH, result: 0)
			// C		"VMS.FILE;0"		"*\;[1-9]*([0-9])"     NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("VMS.FILE;0", pattern: "*;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH)
			// C		"VMS.FILE;"		"*\;[1-9]*([0-9])"     NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("VMS.FILE;", pattern: "*;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH)
			// C		"VMS.FILE;139"		"*\;[1-9]*([0-9])"     0       EXTMATCH
			XCTAssertMatchesFNMatch("VMS.FILE;139", pattern: "*;[1-9]*([0-9])", flags: EXTMATCH, result: 0)
			// C		"VMS.FILE;1N"		"*\;[1-9]*([0-9])"     NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("VMS.FILE;1N", pattern: "*;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH)
			// C		"abcfefg"		"ab**(e|f)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("abcfefg", pattern: "ab**(e|f)", flags: EXTMATCH, result: 0)
			// C		"abcfefg"		"ab**(e|f)g"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("abcfefg", pattern: "ab**(e|f)g", flags: EXTMATCH, result: 0)
			// C		"ab"			"ab*+(e|f)"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("ab", pattern: "ab*+(e|f)", flags: EXTMATCH, result: NOMATCH)
			// C		"abef"			"ab***ef"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("abef", pattern: "ab***ef", flags: EXTMATCH, result: 0)
			// C		"abef"			"ab**"		       0       EXTMATCH
			XCTAssertMatchesFNMatch("abef", pattern: "ab**", flags: EXTMATCH, result: 0)
			// C		"fofo"			"*(f*(o))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("fofo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0)
			// C		"ffo"			"*(f*(o))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("ffo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0)
			// C		"foooofo"		"*(f*(o))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foooofo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0)
			// C		"foooofof"		"*(f*(o))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foooofof", pattern: "*(f*(o))", flags: EXTMATCH, result: 0)
			// C		"fooofoofofooo"		"*(f*(o))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("fooofoofofooo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0)
			// C		"foooofof"		"*(f+(o))"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("foooofof", pattern: "*(f+(o))", flags: EXTMATCH, result: NOMATCH)
			// C		"xfoooofof"		"*(f*(o))"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("xfoooofof", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH)
			// C		"foooofofx"		"*(f*(o))"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("foooofofx", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH)
			// C		"ofxoofxo"		"*(*(of*(o)x)o)"       0       EXTMATCH
			XCTAssertMatchesFNMatch("ofxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
			// C		"ofooofoofofooo"	"*(f*(o))"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("ofooofoofofooo", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH)
			// C		"foooxfooxfoxfooox"	"*(f*(o)x)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foooxfooxfoxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: 0)
			// C		"foooxfooxofoxfooox"	"*(f*(o)x)"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("foooxfooxofoxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: NOMATCH)
			// C		"foooxfooxfxfooox"	"*(f*(o)x)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foooxfooxfxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: 0)
			// C		"ofxoofxo"		"*(*(of*(o)x)o)"       0       EXTMATCH
			XCTAssertMatchesFNMatch("ofxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
			// C		"ofoooxoofxo"		"*(*(of*(o)x)o)"       0       EXTMATCH
			XCTAssertMatchesFNMatch("ofoooxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
			// C		"ofoooxoofxoofoooxoofxo" "*(*(of*(o)x)o)"      0       EXTMATCH
			XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
			// C		"ofoooxoofxoofoooxoofxoo" "*(*(of*(o)x)o)"     0       EXTMATCH
			XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxoo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
			// C		"ofoooxoofxoofoooxoofxofo" "*(*(of*(o)x)o)"    NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxofo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: NOMATCH)
			// C		"ofoooxoofxoofoooxoofxooofxofxo" "*(*(of*(o)x)o)" 0    EXTMATCH
			XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxooofxofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
			// C		"aac"			"*(@(a))a@(c)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("aac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0)
			// C		"ac"			"*(@(a))a@(c)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("ac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0)
			// C		"c"			"*(@(a))a@(c)"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("c", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: NOMATCH)
			// C		"aaac"			"*(@(a))a@(c)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("aaac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0)
			// C		"baaac"			"*(@(a))a@(c)"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("baaac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: NOMATCH)
			// C		"abcd"			"?@(a|b)*@(c)d"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("abcd", pattern: "?@(a|b)*@(c)d", flags: EXTMATCH, result: 0)
			// C		"abcd"			"@(ab|a*@(b))*(c)d"    0       EXTMATCH
			XCTAssertMatchesFNMatch("abcd", pattern: "@(ab|a*@(b))*(c)d", flags: EXTMATCH, result: 0)
			// C		"acd"			"@(ab|a*(b))*(c)d"     0       EXTMATCH
			XCTAssertMatchesFNMatch("acd", pattern: "@(ab|a*(b))*(c)d", flags: EXTMATCH, result: 0)
			// C		"abbcd"			"@(ab|a*(b))*(c)d"     0       EXTMATCH
			XCTAssertMatchesFNMatch("abbcd", pattern: "@(ab|a*(b))*(c)d", flags: EXTMATCH, result: 0)
			// C		"effgz"			"@(b+(c)d|e*(f)g?|?(h)i@(j|k))" 0 EXTMATCH
			XCTAssertMatchesFNMatch("effgz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0)
			// C		"efgz"			"@(b+(c)d|e*(f)g?|?(h)i@(j|k))" 0 EXTMATCH
			XCTAssertMatchesFNMatch("efgz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0)
			// C		"egz"			"@(b+(c)d|e*(f)g?|?(h)i@(j|k))" 0 EXTMATCH
			XCTAssertMatchesFNMatch("egz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0)
			// C		"egzefffgzbcdij"	"*(b+(c)d|e*(f)g?|?(h)i@(j|k))" 0 EXTMATCH
			XCTAssertMatchesFNMatch("egzefffgzbcdij", pattern: "*(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0)
			// C		"egz"			"@(b+(c)d|e+(f)g?|?(h)i@(j|k))" NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("egz", pattern: "@(b+(c)d|e+(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: NOMATCH)
			// C		"ofoofo"		"*(of+(o))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("ofoofo", pattern: "*(of+(o))", flags: EXTMATCH, result: 0)
			// C		"oxfoxoxfox"		"*(oxf+(ox))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("oxfoxoxfox", pattern: "*(oxf+(ox))", flags: EXTMATCH, result: 0)
			// C		"oxfoxfox"		"*(oxf+(ox))"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("oxfoxfox", pattern: "*(oxf+(ox))", flags: EXTMATCH, result: NOMATCH)
			// C		"ofoofo"		"*(of+(o)|f)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("ofoofo", pattern: "*(of+(o)|f)", flags: EXTMATCH, result: 0)
			// C		"foofoofo"		"@(foo|f|fo)*(f|of+(o))" 0     EXTMATCH
			XCTAssertMatchesFNMatch("foofoofo", pattern: "@(foo|f|fo)*(f|of+(o))", flags: EXTMATCH, result: 0)
			// C		"oofooofo"		"*(of|oof+(o))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("oofooofo", pattern: "*(of|oof+(o))", flags: EXTMATCH, result: 0)
			// C		"fffooofoooooffoofffooofff" "*(*(f)*(o))"      0       EXTMATCH
			XCTAssertMatchesFNMatch("fffooofoooooffoofffooofff", pattern: "*(*(f)*(o))", flags: EXTMATCH, result: 0)
			// C		"fofoofoofofoo"		"*(fo|foo)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("fofoofoofofoo", pattern: "*(fo|foo)", flags: EXTMATCH, result: 0)
			// C		"foo"			"!(x)"		       0       EXTMATCH
			XCTAssertMatchesFNMatch("foo", pattern: "!(x)", flags: EXTMATCH, result: 0)
			// C		"foo"			"!(x)*"		       0       EXTMATCH
			XCTAssertMatchesFNMatch("foo", pattern: "!(x)*", flags: EXTMATCH, result: 0)
			// C		"foo"			"!(foo)"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("foo", pattern: "!(foo)", flags: EXTMATCH, result: NOMATCH)
			// C		"foo"			"!(foo)*"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foo", pattern: "!(foo)*", flags: EXTMATCH, result: 0)
			// C		"foobar"		"!(foo)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foobar", pattern: "!(foo)", flags: EXTMATCH, result: 0)
			// C		"foobar"		"!(foo)*"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foobar", pattern: "!(foo)*", flags: EXTMATCH, result: 0)
			// C		"moo.cow"		"!(*.*).!(*.*)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("moo.cow", pattern: "!(*.*).!(*.*)", flags: EXTMATCH, result: 0)
			// C		"mad.moo.cow"		"!(*.*).!(*.*)"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("mad.moo.cow", pattern: "!(*.*).!(*.*)", flags: EXTMATCH, result: NOMATCH)
			// C		"mucca.pazza"		"mu!(*(c))?.pa!(*(z))?" NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("mucca.pazza", pattern: "mu!(*(c))?.pa!(*(z))?", flags: EXTMATCH, result: NOMATCH)
			// C		"fff"			"!(f)"		       0       EXTMATCH
			XCTAssertMatchesFNMatch("fff", pattern: "!(f)", flags: EXTMATCH, result: 0)
			// C		"fff"			"*(!(f))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("fff", pattern: "*(!(f))", flags: EXTMATCH, result: 0)
			// C		"fff"			"+(!(f))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("fff", pattern: "+(!(f))", flags: EXTMATCH, result: 0)
			// C		"ooo"			"!(f)"		       0       EXTMATCH
			XCTAssertMatchesFNMatch("ooo", pattern: "!(f)", flags: EXTMATCH, result: 0)
			// C		"ooo"			"*(!(f))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("ooo", pattern: "*(!(f))", flags: EXTMATCH, result: 0)
			// C		"ooo"			"+(!(f))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("ooo", pattern: "+(!(f))", flags: EXTMATCH, result: 0)
			// C		"foo"			"!(f)"		       0       EXTMATCH
			XCTAssertMatchesFNMatch("foo", pattern: "!(f)", flags: EXTMATCH, result: 0)
			// C		"foo"			"*(!(f))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foo", pattern: "*(!(f))", flags: EXTMATCH, result: 0)
			// C		"foo"			"+(!(f))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foo", pattern: "+(!(f))", flags: EXTMATCH, result: 0)
			// C		"f"			"!(f)"		       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("f", pattern: "!(f)", flags: EXTMATCH, result: NOMATCH)
			// C		"f"			"*(!(f))"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("f", pattern: "*(!(f))", flags: EXTMATCH, result: NOMATCH)
			// C		"f"			"+(!(f))"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("f", pattern: "+(!(f))", flags: EXTMATCH, result: NOMATCH)
			// C		"foot"			"@(!(z*)|*x)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foot", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0)
			// C		"zoot"			"@(!(z*)|*x)"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("zoot", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: NOMATCH)
			// C		"foox"			"@(!(z*)|*x)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foox", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0)
			// C		"zoox"			"@(!(z*)|*x)"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("zoox", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0)
			// C		"foo"			"*(!(foo))"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foo", pattern: "*(!(foo))", flags: EXTMATCH, result: 0)
			// C		"foob"			"!(foo)b*"	       NOMATCH EXTMATCH
			XCTAssertMatchesFNMatch("foob", pattern: "!(foo)b*", flags: EXTMATCH, result: NOMATCH)
			// C		"foobb"			"!(foo)b*"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("foobb", pattern: "!(foo)b*", flags: EXTMATCH, result: 0)
			// C		"["			"*([a[])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("[", pattern: "*([a[])", flags: EXTMATCH, result: 0)
			// C		"]"			"*([]a[])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("]", pattern: "*([]a[])", flags: EXTMATCH, result: 0)
			// C		"a"			"*([]a[])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("a", pattern: "*([]a[])", flags: EXTMATCH, result: 0)
			// C		"b"			"*([!]a[])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("b", pattern: "*([!]a[])", flags: EXTMATCH, result: 0)
			// C		"["			"*([!]a[]|[[])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("[", pattern: "*([!]a[]|[[])", flags: EXTMATCH, result: 0)
			// C		"]"			"*([!]a[]|[]])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("]", pattern: "*([!]a[]|[]])", flags: EXTMATCH, result: 0)
			// C		"["			"!([!]a[])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("[", pattern: "!([!]a[])", flags: EXTMATCH, result: 0)
			// C		"]"			"!([!]a[])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("]", pattern: "!([!]a[])", flags: EXTMATCH, result: 0)
			// C		")"			"*([)])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch(")", pattern: "*([)])", flags: EXTMATCH, result: 0)
			// C		"*"			"*([*(])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("*", pattern: "*([*(])", flags: EXTMATCH, result: 0)
			// C		"abcd"			"*!(|a)cd"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("abcd", pattern: "*!(|a)cd", flags: EXTMATCH, result: 0)
			// C		"ab/.a"			"+([abc])/*"	       NOMATCH EXTMATCH|PATHNAME|PERIOD
			XCTAssertMatchesFNMatch("ab/.a", pattern: "+([abc])/*", flags: EXTMATCH | PATHNAME | PERIOD, result: NOMATCH)
			// C		""			""		       0
			XCTAssertMatchesFNMatch("", pattern: "", flags: 0, result: 0)
			// C		""			""		       0       EXTMATCH
			XCTAssertMatchesFNMatch("", pattern: "", flags: EXTMATCH, result: 0)
			// C		""			"*([abc])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("", pattern: "*([abc])", flags: EXTMATCH, result: 0)
			// C		""			"?([abc])"	       0       EXTMATCH
			XCTAssertMatchesFNMatch("", pattern: "?([abc])", flags: EXTMATCH, result: 0)
		}
	}
}
