import FNMDefinitions
import Testing

@testable import Glob

private let PATHNAME = FNM_PATHNAME
private let PERIOD = FNM_PERIOD
private let NOESCAPE = FNM_NOESCAPE
private let NOMATCH = FNM_NOMATCH
private let LEADING_DIR = FNM_LEADING_DIR
private let EXTMATCH = FNM_EXTMATCH

private func assertMatchesFNMatch(
	_ value: String,
	pattern: String,
	flags: Int32,
	result expectedResult: Int32,
	sourceLocation: SourceLocation = #_sourceLocation
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

	#expect(
		patternResult == expectedResult,
		"matching '\(value)' to pattern '\(pattern)' with flags \(flags) did not match fnmatch result \(expectedResult)",
		sourceLocation: sourceLocation
	)
}

struct FNMatchTests {
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
	@Test func b_6_004_c() {
		// C		 "!#%+,-./01234567889"	"!#%+,-./01234567889"  0
		assertMatchesFNMatch("!#%+,-./01234567889", pattern: "!#%+,-./01234567889", flags: 0, result: 0)
		// C		 ":;=@ABCDEFGHIJKLMNO"	":;=@ABCDEFGHIJKLMNO"  0
		assertMatchesFNMatch(":;=@ABCDEFGHIJKLMNO", pattern: ":;=@ABCDEFGHIJKLMNO", flags: 0, result: 0)
		// C		 "PQRSTUVWXYZ]abcdefg"	"PQRSTUVWXYZ]abcdefg"  0
		assertMatchesFNMatch("PQRSTUVWXYZ]abcdefg", pattern: "PQRSTUVWXYZ]abcdefg", flags: 0, result: 0)
		// C		 "hijklmnopqrstuvwxyz"	"hijklmnopqrstuvwxyz"  0
		assertMatchesFNMatch("hijklmnopqrstuvwxyz", pattern: "hijklmnopqrstuvwxyz", flags: 0, result: 0)
		// C		 "^_{}~"		"^_{}~"		       0
		assertMatchesFNMatch("^_{}~", pattern: "^_{}~", flags: 0, result: 0)
	}

	//  B.6 005(C)
	@Test func b_6_005_c() {
		// C		 "\"$&'()"		"\\\"\\$\\&\\'\\(\\)"  0
		assertMatchesFNMatch("\"$&'()", pattern: "\\\"\\$\\&\\'\\(\\)", flags: 0, result: 0)
		// C		 "*?[\\`|"		"\\*\\?\\[\\\\\\`\\|"  0
		assertMatchesFNMatch("*?[\\`|", pattern: "\\*\\?\\[\\\\\\`\\|", flags: 0, result: 0)
		// C		 "<>"			"\\<\\>"	       0
		assertMatchesFNMatch("<>", pattern: "\\<\\>", flags: 0, result: 0)
	}

	//  B.6 006(C)
	@Test func b_6_006_c() {
		// C		 "?*["			"[?*[][?*[][?*[]"      0
		assertMatchesFNMatch("?*[", pattern: "[?*[][?*[][?*[]", flags: 0, result: 0)
		// C		 "a/b"			"?/b"		       0
		assertMatchesFNMatch("a/b", pattern: "?/b", flags: 0, result: 0)
	}

	//  B.6 007(C)
	@Test func b_6_007_c() {
		// C		 "a/b"			"a?b"		       0
		assertMatchesFNMatch("a/b", pattern: "a?b", flags: 0, result: 0)
		// C		 "a/b"			"a/?"		       0
		assertMatchesFNMatch("a/b", pattern: "a/?", flags: 0, result: 0)
		// C		 "aa/b"			"?/b"		       NOMATCH
		assertMatchesFNMatch("aa/b", pattern: "?/b", flags: 0, result: NOMATCH)
		// C		 "aa/b"			"a?b"		       NOMATCH
		assertMatchesFNMatch("aa/b", pattern: "a?b", flags: 0, result: NOMATCH)
		// C		 "a/bb"			"a/?"		       NOMATCH
		assertMatchesFNMatch("a/bb", pattern: "a/?", flags: 0, result: NOMATCH)
	}

	//  B.6 009(C)
	@Test func b_6_009_c() {
		// C		 "abc"			"[abc]"		       NOMATCH
		assertMatchesFNMatch("abc", pattern: "[abc]", flags: 0, result: NOMATCH)
		// C		 "x"			"[abc]"		       NOMATCH
		assertMatchesFNMatch("x", pattern: "[abc]", flags: 0, result: NOMATCH)
		// C		 "a"			"[abc]"		       0
		assertMatchesFNMatch("a", pattern: "[abc]", flags: 0, result: 0)
		// C		 "["			"[[abc]"	       0
		assertMatchesFNMatch("[", pattern: "[[abc]", flags: 0, result: 0)
		// C		 "a"			"[][abc]"	       0
		assertMatchesFNMatch("a", pattern: "[][abc]", flags: 0, result: 0)
		// C		 "a]"			"[]a]]"		       0
		assertMatchesFNMatch("a]", pattern: "[]a]]", flags: 0, result: 0)
	}

	//  B.6 010(C)
	@Test func b_6_010_c() {
		// C		 "xyz"			"[!abc]"	       NOMATCH
		assertMatchesFNMatch("xyz", pattern: "[!abc]", flags: 0, result: NOMATCH)
		// C		 "x"			"[!abc]"	       0
		assertMatchesFNMatch("x", pattern: "[!abc]", flags: 0, result: 0)
		// C		 "a"			"[!abc]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[!abc]", flags: 0, result: NOMATCH)
	}

	//  B.6 011(C)
	@Test func b_6_011_c() {
		// C		 "]"			"[][abc]"	       0
		assertMatchesFNMatch("]", pattern: "[][abc]", flags: 0, result: 0)
		// C		 "abc]"			"[][abc]"	       NOMATCH
		assertMatchesFNMatch("abc]", pattern: "[][abc]", flags: 0, result: NOMATCH)
		// C		 "[]abc"		"[][]abc"	       NOMATCH
		assertMatchesFNMatch("[]abc", pattern: "[][]abc", flags: 0, result: NOMATCH)
		// C		 "]"			"[!]]"		       NOMATCH
		assertMatchesFNMatch("]", pattern: "[!]]", flags: 0, result: NOMATCH)
		// C		 "aa]"			"[!]a]"		       NOMATCH
		assertMatchesFNMatch("aa]", pattern: "[!]a]", flags: 0, result: NOMATCH)
		// C		 "]"			"[!a]"		       0
		assertMatchesFNMatch("]", pattern: "[!a]", flags: 0, result: 0)
		// C		 "]]"			"[!a]]"		       0
		assertMatchesFNMatch("]]", pattern: "[!a]]", flags: 0, result: 0)
	}

	//  B.6 012(C)
	@Test func b_6_012_c() {
		// C		 "a"			"[[.a.]]"	       0
		assertMatchesFNMatch("a", pattern: "[[.a.]]", flags: 0, result: 0)
		// C		 "-"			"[[.-.]]"	       0
		assertMatchesFNMatch("-", pattern: "[[.-.]]", flags: 0, result: 0)
		// C		 "-"			"[[.-.][.].]]"	       0
		assertMatchesFNMatch("-", pattern: "[[.-.][.].]]", flags: 0, result: 0)
		// C		 "-"			"[[.].][.-.]]"	       0
		assertMatchesFNMatch("-", pattern: "[[.].][.-.]]", flags: 0, result: 0)
		// C		 "-"			"[[.-.][=u=]]"	       0
		assertMatchesFNMatch("-", pattern: "[[.-.][=u=]]", flags: 0, result: 0)
		// C		 "-"			"[[.-.][:alpha:]]"     0
		assertMatchesFNMatch("-", pattern: "[[.-.][:alpha:]]", flags: 0, result: 0)
		// C		 "a"			"[![.a.]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[![.a.]]", flags: 0, result: NOMATCH)
	}

	//  B.6 013(C)
	@Test func b_6_013_c() {
		// C		 "a"			"[[.b.]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[.b.]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[.b.][.c.]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[.b.][.c.]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[.b.][=b=]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[.b.][=b=]]", flags: 0, result: NOMATCH)
	}

	//  B.6 015(C)
	@Test func b_6_015_c() {
		// C		 "a"			"[[=a=]]"	       0
		assertMatchesFNMatch("a", pattern: "[[=a=]]", flags: 0, result: 0)
		// C		 "b"			"[[=a=]b]"	       0
		assertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0)
		// C		 "b"			"[[=a=][=b=]]"	       0
		assertMatchesFNMatch("b", pattern: "[[=a=][=b=]]", flags: 0, result: 0)
		// C		 "a"			"[[=a=][=b=]]"	       0
		assertMatchesFNMatch("a", pattern: "[[=a=][=b=]]", flags: 0, result: 0)
		// C		 "a"			"[[=a=][.b.]]"	       0
		assertMatchesFNMatch("a", pattern: "[[=a=][.b.]]", flags: 0, result: 0)
		// C		 "a"			"[[=a=][:digit:]]"     0
		assertMatchesFNMatch("a", pattern: "[[=a=][:digit:]]", flags: 0, result: 0)
	}

	//  B.6 016(C)
	@Test func b_6_016_c() {
		// C		 "="			"[[=a=]b]"	       NOMATCH
		assertMatchesFNMatch("=", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
		// C		 "]"			"[[=a=]b]"	       NOMATCH
		assertMatchesFNMatch("]", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[=b=][=c=]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[=b=][=c=]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[=b=][.].]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[=b=][.].]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[=b=][:digit:]]"     NOMATCH
		assertMatchesFNMatch("a", pattern: "[[=b=][:digit:]]", flags: 0, result: NOMATCH)
	}

	//  B.6 017(C)
	@Test func b_6_017_c() {
		// C		 "a"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "a"			"[![:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[![:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "-"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "a]a"			"[[:alnum:]]a"	       NOMATCH
		assertMatchesFNMatch("a]a", pattern: "[[:alnum:]]a", flags: 0, result: NOMATCH)
		// C		 "-"			"[[:alnum:]-]"	       0
		assertMatchesFNMatch("-", pattern: "[[:alnum:]-]", flags: 0, result: 0)
		// C		 "aa"			"[[:alnum:]]a"	       0
		assertMatchesFNMatch("aa", pattern: "[[:alnum:]]a", flags: 0, result: 0)
		// C		 "-"			"[![:alnum:]]"	       0
		assertMatchesFNMatch("-", pattern: "[![:alnum:]]", flags: 0, result: 0)
		// C		 "]"			"[!][:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("]", pattern: "[!][:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "["			"[![:alnum:][]"	       NOMATCH
		assertMatchesFNMatch("[", pattern: "[![:alnum:][]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "b"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("b", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "c"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("c", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "d"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("d", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "e"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("e", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "f"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("f", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "g"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("g", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "h"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("h", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "i"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("i", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "j"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("j", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "k"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("k", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "l"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("l", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "m"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("m", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "n"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("n", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "o"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("o", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "p"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("p", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "q"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("q", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "r"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("r", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "s"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("s", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "t"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("t", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "u"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("u", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "v"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("v", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "w"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("w", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "x"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("x", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "y"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("y", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "z"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("z", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "A"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("A", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "B"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("B", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "C"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("C", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "D"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("D", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "E"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("E", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "F"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("F", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "G"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("G", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "H"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("H", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "I"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("I", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "J"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("J", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "K"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("K", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "L"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("L", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "M"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("M", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "N"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("N", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "O"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("O", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "P"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("P", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "Q"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("Q", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "R"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("R", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "S"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("S", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "T"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("T", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "U"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("U", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "V"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("V", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "W"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("W", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "X"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("X", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "Y"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("Y", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "Z"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("Z", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "0"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("0", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "1"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("1", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "2"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("2", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "3"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("3", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "4"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("4", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "5"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("5", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "6"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("6", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "7"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("7", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "8"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("8", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "9"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("9", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C		 "!"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("!", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "#"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("#", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "%"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("%", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "+"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("+", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 ","			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(",", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "-"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "."			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(".", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "/"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("/", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 ":"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(":", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 ";"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(";", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "="			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("=", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "@"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("@", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "["			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("[", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "\\"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("\\", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "]"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("]", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "^"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("^", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "_"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("_", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "{"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("{", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "}"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("}", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "~"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("~", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "\""			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("\"", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "$"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("$", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "&"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("&", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "'"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("'", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "("			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("(", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 ")"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(")", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "*"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("*", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "?"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("?", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "`"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("`", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "|"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("|", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "<"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("<", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 ">"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(">", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:cntrl:]]"	       0
		assertMatchesFNMatch("\t", pattern: "[[:cntrl:]]", flags: 0, result: 0)
		// C		 "t"			"[[:cntrl:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:cntrl:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:lower:]]"	       0
		assertMatchesFNMatch("t", pattern: "[[:lower:]]", flags: 0, result: 0)
		// C		 "\t"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// C		 "T"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("T", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:space:]]"	       0
		assertMatchesFNMatch("\t", pattern: "[[:space:]]", flags: 0, result: 0)
		// C		 "t"			"[[:space:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:space:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("t", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// C		 "\t"			"[[:alpha:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:alpha:]]", flags: 0, result: NOMATCH)
		// C		 "0"			"[[:digit:]]"	       0
		assertMatchesFNMatch("0", pattern: "[[:digit:]]", flags: 0, result: 0)
		// C		 "\t"			"[[:digit:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:digit:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:print:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:print:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:print:]]"	       0
		assertMatchesFNMatch("t", pattern: "[[:print:]]", flags: 0, result: 0)
		// C		 "T"			"[[:upper:]]"	       0
		assertMatchesFNMatch("T", pattern: "[[:upper:]]", flags: 0, result: 0)
		// C		 "\t"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:blank:]]"	       0
		assertMatchesFNMatch("\t", pattern: "[[:blank:]]", flags: 0, result: 0)
		// C		 "t"			"[[:blank:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:blank:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:graph:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:graph:]]", flags: 0, result: NOMATCH)
		// C		 "t"			"[[:graph:]]"	       0
		assertMatchesFNMatch("t", pattern: "[[:graph:]]", flags: 0, result: 0)
		// C		 "."			"[[:punct:]]"	       0
		assertMatchesFNMatch(".", pattern: "[[:punct:]]", flags: 0, result: 0)
		// C		 "t"			"[[:punct:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH)
		// C		 "\t"			"[[:punct:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH)
		// C		 "0"			"[[:xdigit:]]"	       0
		assertMatchesFNMatch("0", pattern: "[[:xdigit:]]", flags: 0, result: 0)
		// C		 "\t"			"[[:xdigit:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[:xdigit:]]"	       0
		assertMatchesFNMatch("a", pattern: "[[:xdigit:]]", flags: 0, result: 0)
		// C		 "A"			"[[:xdigit:]]"	       0
		assertMatchesFNMatch("A", pattern: "[[:xdigit:]]", flags: 0, result: 0)
		// C		 "t"			"[[:xdigit:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[alpha]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[alpha]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[alpha:]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[alpha:]]", flags: 0, result: NOMATCH)
		// C		 "a]"			"[[alpha]]"	       0
		assertMatchesFNMatch("a]", pattern: "[[alpha]]", flags: 0, result: 0)
		// C		 "a]"			"[[alpha:]]"	       0
		assertMatchesFNMatch("a]", pattern: "[[alpha:]]", flags: 0, result: 0)
		// C		 "a"			"[[:alpha:][.b.]]"     0
		assertMatchesFNMatch("a", pattern: "[[:alpha:][.b.]]", flags: 0, result: 0)
		// C		 "a"			"[[:alpha:][=b=]]"     0
		assertMatchesFNMatch("a", pattern: "[[:alpha:][=b=]]", flags: 0, result: 0)
		// C		 "a"			"[[:alpha:][:digit:]]" 0
		assertMatchesFNMatch("a", pattern: "[[:alpha:][:digit:]]", flags: 0, result: 0)
		// C		 "a"			"[[:digit:][:alpha:]]" 0
		assertMatchesFNMatch("a", pattern: "[[:digit:][:alpha:]]", flags: 0, result: 0)
	}

	//  B.6 018(C)
	@Test func b_6_018_c() {
		// C		 "a"			"[a-c]"		       0
		assertMatchesFNMatch("a", pattern: "[a-c]", flags: 0, result: 0)
		// C		 "b"			"[a-c]"		       0
		assertMatchesFNMatch("b", pattern: "[a-c]", flags: 0, result: 0)
		// C		 "c"			"[a-c]"		       0
		assertMatchesFNMatch("c", pattern: "[a-c]", flags: 0, result: 0)
		// C		 "a"			"[b-c]"		       NOMATCH
		assertMatchesFNMatch("a", pattern: "[b-c]", flags: 0, result: NOMATCH)
		// C		 "d"			"[b-c]"		       NOMATCH
		assertMatchesFNMatch("d", pattern: "[b-c]", flags: 0, result: NOMATCH)
		// C		 "B"			"[a-c]"		       NOMATCH
		assertMatchesFNMatch("B", pattern: "[a-c]", flags: 0, result: NOMATCH)
		// C		 "b"			"[A-C]"		       NOMATCH
		assertMatchesFNMatch("b", pattern: "[A-C]", flags: 0, result: NOMATCH)
		// C		 ""			"[a-c]"		       NOMATCH
		assertMatchesFNMatch("", pattern: "[a-c]", flags: 0, result: NOMATCH)
		// C		 "as"			"[a-ca-z]"	       NOMATCH
		assertMatchesFNMatch("as", pattern: "[a-ca-z]", flags: 0, result: NOMATCH)

		// C		 "a"			"[[.a.]-c]"	       0
		assertMatchesFNMatch("a", pattern: "[[.a.]-c]", flags: 0, result: 0)
		// C		 "a"			"[a-[.c.]]"	       0
		assertMatchesFNMatch("a", pattern: "[a-[.c.]]", flags: 0, result: 0)
		// C		 "a"			"[[.a.]-[.c.]]"	       0
		assertMatchesFNMatch("a", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
		// C		 "b"			"[[.a.]-c]"	       0
		assertMatchesFNMatch("b", pattern: "[[.a.]-c]", flags: 0, result: 0)
		// C		 "b"			"[a-[.c.]]"	       0
		assertMatchesFNMatch("b", pattern: "[a-[.c.]]", flags: 0, result: 0)
		// C		 "b"			"[[.a.]-[.c.]]"	       0
		assertMatchesFNMatch("b", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
		// C		 "c"			"[[.a.]-c]"	       0
		assertMatchesFNMatch("c", pattern: "[[.a.]-c]", flags: 0, result: 0)
		// C		 "c"			"[a-[.c.]]"	       0
		assertMatchesFNMatch("c", pattern: "[a-[.c.]]", flags: 0, result: 0)
		// C		 "c"			"[[.a.]-[.c.]]"	       0
		assertMatchesFNMatch("c", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
		// C		 "d"			"[[.a.]-c]"	       NOMATCH
		assertMatchesFNMatch("d", pattern: "[[.a.]-c]", flags: 0, result: NOMATCH)
		// C		 "d"			"[a-[.c.]]"	       NOMATCH
		assertMatchesFNMatch("d", pattern: "[a-[.c.]]", flags: 0, result: NOMATCH)
		// C		 "d"			"[[.a.]-[.c.]]"	       NOMATCH
		assertMatchesFNMatch("d", pattern: "[[.a.]-[.c.]]", flags: 0, result: NOMATCH)
	}

	//  B.6 019(C)
	@Test func b_6_019_c() {
		// C		 "a"			"[c-a]"		       NOMATCH
		assertMatchesFNMatch("a", pattern: "[c-a]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[.c.]-a]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH)
		// C		 "a"			"[c-[.a.]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH)
		// C		 "a"			"[[.c.]-[.a.]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH)
		// C		 "c"			"[c-a]"		       NOMATCH
		assertMatchesFNMatch("c", pattern: "[c-a]", flags: 0, result: NOMATCH)
		// C		 "c"			"[[.c.]-a]"	       NOMATCH
		assertMatchesFNMatch("c", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH)
		// C		 "c"			"[c-[.a.]]"	       NOMATCH
		assertMatchesFNMatch("c", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH)
		// C		 "c"			"[[.c.]-[.a.]]"	       NOMATCH
		assertMatchesFNMatch("c", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH)
	}

	//  B.6 020(C)
	@Test func b_6_020_c() {
		// C		 "a"			"[a-c0-9]"	       0
		assertMatchesFNMatch("a", pattern: "[a-c0-9]", flags: 0, result: 0)
		// C		 "d"			"[a-c0-9]"	       NOMATCH
		assertMatchesFNMatch("d", pattern: "[a-c0-9]", flags: 0, result: NOMATCH)
		// C		 "B"			"[a-c0-9]"	       NOMATCH
		assertMatchesFNMatch("B", pattern: "[a-c0-9]", flags: 0, result: NOMATCH)
	}

	//  B.6 021(C)
	@Test func b_6_021_c() {
		// C		 "-"			"[-a]"		       0
		assertMatchesFNMatch("-", pattern: "[-a]", flags: 0, result: 0)
		// C		 "a"			"[-b]"		       NOMATCH
		assertMatchesFNMatch("a", pattern: "[-b]", flags: 0, result: NOMATCH)
		// C		 "-"			"[!-a]"		       NOMATCH
		assertMatchesFNMatch("-", pattern: "[!-a]", flags: 0, result: NOMATCH)
		// C		 "a"			"[!-b]"		       0
		assertMatchesFNMatch("a", pattern: "[!-b]", flags: 0, result: 0)
		// C		 "-"			"[a-c-0-9]"	       0
		assertMatchesFNMatch("-", pattern: "[a-c-0-9]", flags: 0, result: 0)
		// C		 "b"			"[a-c-0-9]"	       0
		assertMatchesFNMatch("b", pattern: "[a-c-0-9]", flags: 0, result: 0)
		// C		 "a:"			"a[0-9-a]"	       NOMATCH
		assertMatchesFNMatch("a:", pattern: "a[0-9-a]", flags: 0, result: NOMATCH)
		// C		 "a:"			"a[09-a]"	       0
		assertMatchesFNMatch("a:", pattern: "a[09-a]", flags: 0, result: 0)
	}

	//  B.6 024(C)
	@Test func b_6_024_c() {
		// C		 ""			"*"		       0
		assertMatchesFNMatch("", pattern: "*", flags: 0, result: 0)
		// C		 "asd/sdf"		"*"		       0
		assertMatchesFNMatch("asd/sdf", pattern: "*", flags: 0, result: 0)
	}

	//  B.6 025(C)
	@Test func b_6_025_c() {
		// C		 "as"			"[a-c][a-z]"	       0
		assertMatchesFNMatch("as", pattern: "[a-c][a-z]", flags: 0, result: 0)
		// C		 "as"			"??"		       0
		assertMatchesFNMatch("as", pattern: "??", flags: 0, result: 0)
	}

	//  B.6 026(C)
	@Test func b_6_026_c() {
		// C		 "asd/sdf"		"as*df"		       0
		assertMatchesFNMatch("asd/sdf", pattern: "as*df", flags: 0, result: 0)
		// C		 "asd/sdf"		"as*"		       0
		assertMatchesFNMatch("asd/sdf", pattern: "as*", flags: 0, result: 0)
		// C		 "asd/sdf"		"*df"		       0
		assertMatchesFNMatch("asd/sdf", pattern: "*df", flags: 0, result: 0)
		// C		 "asd/sdf"		"as*dg"		       NOMATCH
		assertMatchesFNMatch("asd/sdf", pattern: "as*dg", flags: 0, result: NOMATCH)
		// C		 "asdf"			"as*df"		       0
		assertMatchesFNMatch("asdf", pattern: "as*df", flags: 0, result: 0)
		// C		 "asdf"			"as*df?"	       NOMATCH
		assertMatchesFNMatch("asdf", pattern: "as*df?", flags: 0, result: NOMATCH)
		// C		 "asdf"			"as*??"		       0
		assertMatchesFNMatch("asdf", pattern: "as*??", flags: 0, result: 0)
		// C		 "asdf"			"a*???"		       0
		assertMatchesFNMatch("asdf", pattern: "a*???", flags: 0, result: 0)
		// C		 "asdf"			"*????"		       0
		assertMatchesFNMatch("asdf", pattern: "*????", flags: 0, result: 0)
		// C		 "asdf"			"????*"		       0
		assertMatchesFNMatch("asdf", pattern: "????*", flags: 0, result: 0)
		// C		 "asdf"			"??*?"		       0
		assertMatchesFNMatch("asdf", pattern: "??*?", flags: 0, result: 0)
	}

	//  B.6 027(C)
	@Test func b_6_027_c() {
		// C		 "/"			"/"		       0
		assertMatchesFNMatch("/", pattern: "/", flags: 0, result: 0)
		// C		 "/"			"/*"		       0
		assertMatchesFNMatch("/", pattern: "/*", flags: 0, result: 0)
		// C		 "/"			"*/"		       0
		assertMatchesFNMatch("/", pattern: "*/", flags: 0, result: 0)
		// C		 "/"			"/?"		       NOMATCH
		assertMatchesFNMatch("/", pattern: "/?", flags: 0, result: NOMATCH)
		// C		 "/"			"?/"		       NOMATCH
		assertMatchesFNMatch("/", pattern: "?/", flags: 0, result: NOMATCH)
		// C		 "/"			"?"		       0
		assertMatchesFNMatch("/", pattern: "?", flags: 0, result: 0)
		// C		 "."			"?"		       0
		assertMatchesFNMatch(".", pattern: "?", flags: 0, result: 0)
		// C		 "/."			"??"		       0
		assertMatchesFNMatch("/.", pattern: "??", flags: 0, result: 0)
		// C		 "/"			"[!a-c]"	       0
		assertMatchesFNMatch("/", pattern: "[!a-c]", flags: 0, result: 0)
		// C		 "."			"[!a-c]"	       0
		assertMatchesFNMatch(".", pattern: "[!a-c]", flags: 0, result: 0)
	}

	//  B.6 029(C)
	@Test func b_6_029_c() {
		// C		 "/"			"/"		       0       PATHNAME
		assertMatchesFNMatch("/", pattern: "/", flags: PATHNAME, result: 0)
		// C		 "//"			"//"		       0       PATHNAME
		assertMatchesFNMatch("//", pattern: "//", flags: PATHNAME, result: 0)
		// C		 "/.a"			"/*"		       0       PATHNAME
		assertMatchesFNMatch("/.a", pattern: "/*", flags: PATHNAME, result: 0)
		// C		 "/.a"			"/?a"		       0       PATHNAME
		assertMatchesFNMatch("/.a", pattern: "/?a", flags: PATHNAME, result: 0)
		// C		 "/.a"			"/[!a-z]a"	       0       PATHNAME
		assertMatchesFNMatch("/.a", pattern: "/[!a-z]a", flags: PATHNAME, result: 0)
		// C		 "/.a/.b"		"/*/?b"		       0       PATHNAME
		assertMatchesFNMatch("/.a/.b", pattern: "/*/?b", flags: PATHNAME, result: 0)
	}

	//  B.6 030(C)
	@Test func b_6_030_c() {
		// C		 "/"			"?"		       NOMATCH PATHNAME
		assertMatchesFNMatch("/", pattern: "?", flags: PATHNAME, result: NOMATCH)
		// C		 "/"			"*"		       NOMATCH PATHNAME
		assertMatchesFNMatch("/", pattern: "*", flags: PATHNAME, result: NOMATCH)
		// C		 "a/b"			"a?b"		       NOMATCH PATHNAME
		assertMatchesFNMatch("a/b", pattern: "a?b", flags: PATHNAME, result: NOMATCH)
		// C		 "/.a/.b"		"/*b"		       NOMATCH PATHNAME
		assertMatchesFNMatch("/.a/.b", pattern: "/*b", flags: PATHNAME, result: NOMATCH)
	}

	//  B.6 031(C)
	@Test func b_6_031_c() {
		// C		 "/$"			"\\/\\$"	       0
		assertMatchesFNMatch("/$", pattern: "\\/\\$", flags: 0, result: 0)
		// C		 "/["			"\\/\\["	       0
		assertMatchesFNMatch("/[", pattern: "\\/\\[", flags: 0, result: 0)
		// C		 "/["			"\\/["		       0
		withKnownIssue {
			// Apple's implimentation of fnmatch doesn't produce this result
			assertMatchesFNMatch("/[", pattern: "\\/[", flags: 0, result: 0)
		}
		// C		 "/[]"			"\\/\\[]"	       0
		assertMatchesFNMatch("/[]", pattern: "\\/\\[]", flags: 0, result: 0)
	}

	//  B.6 032(C)
	@Test func b_6_032_c() {
		// C		 "/$"			"\\/\\$"	       NOMATCH NOESCAPE
		assertMatchesFNMatch("/$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH)
		// C		 "/\\$"			"\\/\\$"	       NOMATCH NOESCAPE
		assertMatchesFNMatch("/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH)
		// C		 "\\/\\$"		"\\/\\$"	       0       NOESCAPE
		assertMatchesFNMatch("\\/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: 0)
	}

	//  B.6 033(C)
	@Test func b_6_033_c() {
		// C		 ".asd"			".*"		       0       PERIOD
		assertMatchesFNMatch(".asd", pattern: ".*", flags: PERIOD, result: 0)
		// C		 "/.asd"		"*"		       0       PERIOD
		assertMatchesFNMatch("/.asd", pattern: "*", flags: PERIOD, result: 0)
		// C		 "/as/.df"		"*/?*f"		       0       PERIOD
		assertMatchesFNMatch("/as/.df", pattern: "*/?*f", flags: PERIOD, result: 0)
		// C		 "..asd"		".[!a-z]*"	       0       PERIOD
		assertMatchesFNMatch("..asd", pattern: ".[!a-z]*", flags: PERIOD, result: 0)
	}

	//  B.6 034(C)
	@Test func b_6_034_c() {
		// we need to somehow apply requiresExplicitLeadingPeriods only for . after path separators or at the beginning
		// C		 ".asd"			"*"		       NOMATCH PERIOD
		assertMatchesFNMatch(".asd", pattern: "*", flags: PERIOD, result: NOMATCH)
		// C		 ".asd"			"?asd"		       NOMATCH PERIOD
		assertMatchesFNMatch(".asd", pattern: "?asd", flags: PERIOD, result: NOMATCH)
		// C		 ".asd"			"[!a-z]*"	       NOMATCH PERIOD
		assertMatchesFNMatch(".asd", pattern: "[!a-z]*", flags: PERIOD, result: NOMATCH)
	}

	//  B.6 035(C)
	@Test func b_6_035_c() {
		// C		 "/."			"/."		       0       PATHNAME|PERIOD
		assertMatchesFNMatch("/.", pattern: "/.", flags: PATHNAME | PERIOD, result: 0)
		// C		 "/.a./.b."		"/.*/.*"	       0       PATHNAME|PERIOD
		assertMatchesFNMatch("/.a./.b.", pattern: "/.*/.*", flags: PATHNAME | PERIOD, result: 0)
		// C		 "/.a./.b."		"/.??/.??"	       0       PATHNAME|PERIOD
		assertMatchesFNMatch("/.a./.b.", pattern: "/.??/.??", flags: PATHNAME | PERIOD, result: 0)
	}

	//  B.6 036(C)
	@Test func b_6_036_c() {
		// C		 "/."			"*"		       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/.", pattern: "*", flags: PATHNAME | PERIOD, result: NOMATCH)
		// C		 "/."			"/*"		       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/.", pattern: "/*", flags: PATHNAME | PERIOD, result: NOMATCH)
		// C		 "/."			"/?"		       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/.", pattern: "/?", flags: PATHNAME | PERIOD, result: NOMATCH)
		// C		 "/."			"/[!a-z]"	       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/.", pattern: "/[!a-z]", flags: PATHNAME | PERIOD, result: NOMATCH)
		// C		 "/a./.b."		"/*/*"		       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/a./.b.", pattern: "/*/*", flags: PATHNAME | PERIOD, result: NOMATCH)
		// C		 "/a./.b."		"/??/???"	       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/a./.b.", pattern: "/??/???", flags: PATHNAME | PERIOD, result: NOMATCH)
	}

	//  Some home-grown tests utf8
	@Test func some_home_grown_tests_utf8() {
		// C		"foobar"		"foo*[abc]z"	       NOMATCH
		assertMatchesFNMatch("foobar", pattern: "foo*[abc]z", flags: 0, result: NOMATCH)
		// C		"foobaz"		"foo*[abc][xyz]"       0
		assertMatchesFNMatch("foobaz", pattern: "foo*[abc][xyz]", flags: 0, result: 0)
		// C		"foobaz"		"foo?*[abc][xyz]"      0
		assertMatchesFNMatch("foobaz", pattern: "foo?*[abc][xyz]", flags: 0, result: 0)
		// C		"foobaz"		"foo?*[abc][x/yz]"     0
		assertMatchesFNMatch("foobaz", pattern: "foo?*[abc][x/yz]", flags: 0, result: 0)
		// C		"foobaz"		"foo?*[abc]/[xyz]"     NOMATCH PATHNAME
		assertMatchesFNMatch("foobaz", pattern: "foo?*[abc]/[xyz]", flags: PATHNAME, result: NOMATCH)
		// C		"a"			"a/"                   NOMATCH PATHNAME
		assertMatchesFNMatch("a", pattern: "a/", flags: PATHNAME, result: NOMATCH)
		// C		"a/"			"a"		       NOMATCH PATHNAME
		assertMatchesFNMatch("a/", pattern: "a", flags: PATHNAME, result: NOMATCH)
		// C		"//a"			"/a"		       NOMATCH PATHNAME
		assertMatchesFNMatch("//a", pattern: "/a", flags: PATHNAME, result: NOMATCH)
		// C		"/a"			"//a"		       NOMATCH PATHNAME
		assertMatchesFNMatch("/a", pattern: "//a", flags: PATHNAME, result: NOMATCH)
		// C		"az"			"[a-]z"		       0
		assertMatchesFNMatch("az", pattern: "[a-]z", flags: 0, result: 0)
		// C		"bz"			"[ab-]z"	       0
		assertMatchesFNMatch("bz", pattern: "[ab-]z", flags: 0, result: 0)
		// C		"cz"			"[ab-]z"	       NOMATCH
		assertMatchesFNMatch("cz", pattern: "[ab-]z", flags: 0, result: NOMATCH)
		// C		"-z"			"[ab-]z"	       0
		assertMatchesFNMatch("-z", pattern: "[ab-]z", flags: 0, result: 0)
		// C		"az"			"[-a]z"		       0
		assertMatchesFNMatch("az", pattern: "[-a]z", flags: 0, result: 0)
		// C		"bz"			"[-ab]z"	       0
		assertMatchesFNMatch("bz", pattern: "[-ab]z", flags: 0, result: 0)
		// C		"cz"			"[-ab]z"	       NOMATCH
		assertMatchesFNMatch("cz", pattern: "[-ab]z", flags: 0, result: NOMATCH)
		// C		"-z"			"[-ab]z"	       0
		assertMatchesFNMatch("-z", pattern: "[-ab]z", flags: 0, result: 0)
		// C		"\\"			"[\\\\-a]"	       0
		assertMatchesFNMatch("\\", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C		"_"			"[\\\\-a]"	       0
		assertMatchesFNMatch("_", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C		"a"			"[\\\\-a]"	       0
		assertMatchesFNMatch("a", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C		"-"			"[\\\\-a]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[\\\\-a]", flags: 0, result: NOMATCH)
		// C		"\\"			"[\\]-a]"	       NOMATCH
		assertMatchesFNMatch("\\", pattern: "[\\]-a]", flags: 0, result: NOMATCH)
		// C		"_"			"[\\]-a]"	       0
		assertMatchesFNMatch("_", pattern: "[\\]-a]", flags: 0, result: 0)
		// C		"a"			"[\\]-a]"	       0
		assertMatchesFNMatch("a", pattern: "[\\]-a]", flags: 0, result: 0)
		// C		"]"			"[\\]-a]"	       0
		assertMatchesFNMatch("]", pattern: "[\\]-a]", flags: 0, result: 0)
		// C		"-"			"[\\]-a]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[\\]-a]", flags: 0, result: NOMATCH)
		// C		"\\"			"[!\\\\-a]"	       NOMATCH
		assertMatchesFNMatch("\\", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C		"_"			"[!\\\\-a]"	       NOMATCH
		assertMatchesFNMatch("_", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C		"a"			"[!\\\\-a]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C		"-"			"[!\\\\-a]"	       0
		assertMatchesFNMatch("-", pattern: "[!\\\\-a]", flags: 0, result: 0)
		// C		"!"			"[\\!-]"	       0
		assertMatchesFNMatch("!", pattern: "[\\!-]", flags: 0, result: 0)
		// C		"-"			"[\\!-]"	       0
		assertMatchesFNMatch("-", pattern: "[\\!-]", flags: 0, result: 0)
		// C		"\\"			"[\\!-]"	       NOMATCH
		assertMatchesFNMatch("\\", pattern: "[\\!-]", flags: 0, result: NOMATCH)
		// C		"Z"			"[Z-\\\\]"	       0
		assertMatchesFNMatch("Z", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C		"["			"[Z-\\\\]"	       0
		assertMatchesFNMatch("[", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C		"\\"			"[Z-\\\\]"	       0
		assertMatchesFNMatch("\\", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C		"-"			"[Z-\\\\]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[Z-\\\\]", flags: 0, result: NOMATCH)
		// C		"Z"			"[Z-\\]]"	       0
		assertMatchesFNMatch("Z", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C		"["			"[Z-\\]]"	       0
		assertMatchesFNMatch("[", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C		"\\"			"[Z-\\]]"	       0
		assertMatchesFNMatch("\\", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C		"]"			"[Z-\\]]"	       0
		assertMatchesFNMatch("]", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C		"-"			"[Z-\\]]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[Z-\\]]", flags: 0, result: NOMATCH)
	}

	//  B.6 004(C) utf8
	@Test func b_6_004_c_utf8() {
		// C.UTF-8		 "!#%+,-./01234567889"	"!#%+,-./01234567889"  0
		assertMatchesFNMatch("!#%+,-./01234567889", pattern: "!#%+,-./01234567889", flags: 0, result: 0)
		// C.UTF-8		 ":;=@ABCDEFGHIJKLMNO"	":;=@ABCDEFGHIJKLMNO"  0
		assertMatchesFNMatch(":;=@ABCDEFGHIJKLMNO", pattern: ":;=@ABCDEFGHIJKLMNO", flags: 0, result: 0)
		// C.UTF-8		 "PQRSTUVWXYZ]abcdefg"	"PQRSTUVWXYZ]abcdefg"  0
		assertMatchesFNMatch("PQRSTUVWXYZ]abcdefg", pattern: "PQRSTUVWXYZ]abcdefg", flags: 0, result: 0)
		// C.UTF-8		 "hijklmnopqrstuvwxyz"	"hijklmnopqrstuvwxyz"  0
		assertMatchesFNMatch("hijklmnopqrstuvwxyz", pattern: "hijklmnopqrstuvwxyz", flags: 0, result: 0)
		// C.UTF-8		 "^_{}~"		"^_{}~"		       0
		assertMatchesFNMatch("^_{}~", pattern: "^_{}~", flags: 0, result: 0)
	}

	//  B.6 005(C) utf8
	@Test func b_6_005_c_utf8() {
		// C.UTF-8		 "\"$&'()"		"\\\"\\$\\&\\'\\(\\)"  0
		assertMatchesFNMatch("\"$&'()", pattern: "\\\"\\$\\&\\'\\(\\)", flags: 0, result: 0)
		// C.UTF-8		 "*?[\\`|"		"\\*\\?\\[\\\\\\`\\|"  0
		assertMatchesFNMatch("*?[\\`|", pattern: "\\*\\?\\[\\\\\\`\\|", flags: 0, result: 0)
		// C.UTF-8		 "<>"			"\\<\\>"	       0
		assertMatchesFNMatch("<>", pattern: "\\<\\>", flags: 0, result: 0)
	}

	//  B.6 006(C) utf8
	@Test func b_6_006_c_utf8() {
		// C.UTF-8		 "?*["			"[?*[][?*[][?*[]"      0
		assertMatchesFNMatch("?*[", pattern: "[?*[][?*[][?*[]", flags: 0, result: 0)
		// C.UTF-8		 "a/b"			"?/b"		       0
		assertMatchesFNMatch("a/b", pattern: "?/b", flags: 0, result: 0)
	}

	//  B.6 007(C) utf8
	@Test func b_6_007_c_utf8() {
		// C.UTF-8		 "a/b"			"a?b"		       0
		assertMatchesFNMatch("a/b", pattern: "a?b", flags: 0, result: 0)
		// C.UTF-8		 "a/b"			"a/?"		       0
		assertMatchesFNMatch("a/b", pattern: "a/?", flags: 0, result: 0)
		// C.UTF-8		 "aa/b"			"?/b"		       NOMATCH
		assertMatchesFNMatch("aa/b", pattern: "?/b", flags: 0, result: NOMATCH)
		// C.UTF-8		 "aa/b"			"a?b"		       NOMATCH
		assertMatchesFNMatch("aa/b", pattern: "a?b", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a/bb"			"a/?"		       NOMATCH
		assertMatchesFNMatch("a/bb", pattern: "a/?", flags: 0, result: NOMATCH)
	}

	//  B.6 009(C) utf8
	@Test func b_6_009_c_utf8() {
		// C.UTF-8		 "abc"			"[abc]"		       NOMATCH
		assertMatchesFNMatch("abc", pattern: "[abc]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "x"			"[abc]"		       NOMATCH
		assertMatchesFNMatch("x", pattern: "[abc]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[abc]"		       0
		assertMatchesFNMatch("a", pattern: "[abc]", flags: 0, result: 0)
		// C.UTF-8		 "["			"[[abc]"	       0
		assertMatchesFNMatch("[", pattern: "[[abc]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[][abc]"	       0
		assertMatchesFNMatch("a", pattern: "[][abc]", flags: 0, result: 0)
		// C.UTF-8		 "a]"			"[]a]]"		       0
		assertMatchesFNMatch("a]", pattern: "[]a]]", flags: 0, result: 0)
	}

	//  B.6 010(C) utf8
	@Test func b_6_010_c_utf8() {
		// C.UTF-8		 "xyz"			"[!abc]"	       NOMATCH
		assertMatchesFNMatch("xyz", pattern: "[!abc]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "x"			"[!abc]"	       0
		assertMatchesFNMatch("x", pattern: "[!abc]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[!abc]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[!abc]", flags: 0, result: NOMATCH)
	}

	//  B.6 011(C) utf8
	@Test func b_6_011_c_utf8() {
		// C.UTF-8		 "]"			"[][abc]"	       0
		assertMatchesFNMatch("]", pattern: "[][abc]", flags: 0, result: 0)
		// C.UTF-8		 "abc]"			"[][abc]"	       NOMATCH
		assertMatchesFNMatch("abc]", pattern: "[][abc]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "[]abc"		"[][]abc"	       NOMATCH
		assertMatchesFNMatch("[]abc", pattern: "[][]abc", flags: 0, result: NOMATCH)
		// C.UTF-8		 "]"			"[!]]"		       NOMATCH
		assertMatchesFNMatch("]", pattern: "[!]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "aa]"			"[!]a]"		       NOMATCH
		assertMatchesFNMatch("aa]", pattern: "[!]a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "]"			"[!a]"		       0
		assertMatchesFNMatch("]", pattern: "[!a]", flags: 0, result: 0)
		// C.UTF-8		 "]]"			"[!a]]"		       0
		assertMatchesFNMatch("]]", pattern: "[!a]]", flags: 0, result: 0)
	}

	//  B.6 012(C) utf8
	@Test func b_6_012_c_utf8() {
		// C.UTF-8		 "a"			"[[.a.]]"	       0
		assertMatchesFNMatch("a", pattern: "[[.a.]]", flags: 0, result: 0)
		// C.UTF-8		 "-"			"[[.-.]]"	       0
		assertMatchesFNMatch("-", pattern: "[[.-.]]", flags: 0, result: 0)
		// C.UTF-8		 "-"			"[[.-.][.].]]"	       0
		assertMatchesFNMatch("-", pattern: "[[.-.][.].]]", flags: 0, result: 0)
		// C.UTF-8		 "-"			"[[.].][.-.]]"	       0
		assertMatchesFNMatch("-", pattern: "[[.].][.-.]]", flags: 0, result: 0)
		// C.UTF-8		 "-"			"[[.-.][=u=]]"	       0
		assertMatchesFNMatch("-", pattern: "[[.-.][=u=]]", flags: 0, result: 0)
		// C.UTF-8		 "-"			"[[.-.][:alpha:]]"     0
		assertMatchesFNMatch("-", pattern: "[[.-.][:alpha:]]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[![.a.]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[![.a.]]", flags: 0, result: NOMATCH)
	}

	//  B.6 013(C) utf8
	@Test func b_6_013_c_utf8() {
		// C.UTF-8		 "a"			"[[.b.]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[.b.]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[.b.][.c.]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[.b.][.c.]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[.b.][=b=]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[.b.][=b=]]", flags: 0, result: NOMATCH)
	}

	//  B.6 015(C) utf8
	@Test func b_6_015_c_utf8() {
		// C.UTF-8		 "a"			"[[=a=]]"	       0
		assertMatchesFNMatch("a", pattern: "[[=a=]]", flags: 0, result: 0)
		// C.UTF-8		 "b"			"[[=a=]b]"	       0
		assertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0)
		// C.UTF-8		 "b"			"[[=a=][=b=]]"	       0
		assertMatchesFNMatch("b", pattern: "[[=a=][=b=]]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[[=a=][=b=]]"	       0
		assertMatchesFNMatch("a", pattern: "[[=a=][=b=]]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[[=a=][.b.]]"	       0
		assertMatchesFNMatch("a", pattern: "[[=a=][.b.]]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[[=a=][:digit:]]"     0
		assertMatchesFNMatch("a", pattern: "[[=a=][:digit:]]", flags: 0, result: 0)
	}

	//  B.6 016(C) utf8
	@Test func b_6_016_c_utf8() {
		// C.UTF-8		 "="			"[[=a=]b]"	       NOMATCH
		assertMatchesFNMatch("=", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "]"			"[[=a=]b]"	       NOMATCH
		assertMatchesFNMatch("]", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[=b=][=c=]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[=b=][=c=]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[=b=][.].]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[=b=][.].]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[=b=][:digit:]]"     NOMATCH
		assertMatchesFNMatch("a", pattern: "[[=b=][:digit:]]", flags: 0, result: NOMATCH)
	}

	//  B.6 017(C) utf8
	@Test func b_6_017_c_utf8() {
		// C.UTF-8		 "a"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[![:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[![:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "-"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a]a"			"[[:alnum:]]a"	       NOMATCH
		assertMatchesFNMatch("a]a", pattern: "[[:alnum:]]a", flags: 0, result: NOMATCH)
		// C.UTF-8		 "-"			"[[:alnum:]-]"	       0
		assertMatchesFNMatch("-", pattern: "[[:alnum:]-]", flags: 0, result: 0)
		// C.UTF-8		 "aa"			"[[:alnum:]]a"	       0
		assertMatchesFNMatch("aa", pattern: "[[:alnum:]]a", flags: 0, result: 0)
		// C.UTF-8		 "-"			"[![:alnum:]]"	       0
		assertMatchesFNMatch("-", pattern: "[![:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "]"			"[!][:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("]", pattern: "[!][:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "["			"[![:alnum:][]"	       NOMATCH
		assertMatchesFNMatch("[", pattern: "[![:alnum:][]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "b"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("b", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "c"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("c", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "d"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("d", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "e"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("e", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "f"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("f", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "g"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("g", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "h"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("h", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "i"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("i", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "j"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("j", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "k"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("k", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "l"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("l", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "m"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("m", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "n"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("n", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "o"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("o", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "p"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("p", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "q"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("q", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "r"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("r", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "s"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("s", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "t"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("t", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "u"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("u", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "v"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("v", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "w"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("w", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "x"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("x", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "y"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("y", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "z"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("z", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "A"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("A", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "B"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("B", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "C"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("C", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "D"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("D", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "E"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("E", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "F"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("F", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "G"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("G", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "H"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("H", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "I"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("I", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "J"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("J", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "K"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("K", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "L"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("L", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "M"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("M", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "N"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("N", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "O"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("O", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "P"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("P", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "Q"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("Q", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "R"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("R", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "S"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("S", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "T"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("T", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "U"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("U", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "V"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("V", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "W"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("W", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "X"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("X", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "Y"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("Y", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "Z"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("Z", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "0"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("0", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "1"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("1", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "2"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("2", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "3"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("3", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "4"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("4", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "5"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("5", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "6"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("6", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "7"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("7", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "8"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("8", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "9"			"[[:alnum:]]"	       0
		assertMatchesFNMatch("9", pattern: "[[:alnum:]]", flags: 0, result: 0)
		// C.UTF-8		 "!"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("!", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "#"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("#", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "%"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("%", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "+"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("+", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 ","			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(",", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "-"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "."			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(".", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "/"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("/", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 ":"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(":", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 ";"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(";", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "="			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("=", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "@"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("@", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "["			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("[", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "\\"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("\\", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "]"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("]", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "^"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("^", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "_"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("_", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "{"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("{", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "}"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("}", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "~"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("~", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "\""			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("\"", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "$"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("$", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "&"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("&", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "'"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("'", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "("			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("(", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 ")"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(")", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "*"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("*", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "?"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("?", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "`"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("`", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "|"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("|", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "<"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch("<", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 ">"			"[[:alnum:]]"	       NOMATCH
		assertMatchesFNMatch(">", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "\t"			"[[:cntrl:]]"	       0
		assertMatchesFNMatch("\t", pattern: "[[:cntrl:]]", flags: 0, result: 0)
		// C.UTF-8		 "t"			"[[:cntrl:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:cntrl:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "t"			"[[:lower:]]"	       0
		assertMatchesFNMatch("t", pattern: "[[:lower:]]", flags: 0, result: 0)
		// C.UTF-8		 "\t"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "T"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("T", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "\t"			"[[:space:]]"	       0
		assertMatchesFNMatch("\t", pattern: "[[:space:]]", flags: 0, result: 0)
		// C.UTF-8		 "t"			"[[:space:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:space:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "t"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("t", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// C.UTF-8		 "\t"			"[[:alpha:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:alpha:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "0"			"[[:digit:]]"	       0
		assertMatchesFNMatch("0", pattern: "[[:digit:]]", flags: 0, result: 0)
		// C.UTF-8		 "\t"			"[[:digit:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "t"			"[[:digit:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "\t"			"[[:print:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:print:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "t"			"[[:print:]]"	       0
		assertMatchesFNMatch("t", pattern: "[[:print:]]", flags: 0, result: 0)
		// C.UTF-8		 "T"			"[[:upper:]]"	       0
		assertMatchesFNMatch("T", pattern: "[[:upper:]]", flags: 0, result: 0)
		// C.UTF-8		 "\t"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "t"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "\t"			"[[:blank:]]"	       0
		assertMatchesFNMatch("\t", pattern: "[[:blank:]]", flags: 0, result: 0)
		// C.UTF-8		 "t"			"[[:blank:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:blank:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "\t"			"[[:graph:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:graph:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "t"			"[[:graph:]]"	       0
		assertMatchesFNMatch("t", pattern: "[[:graph:]]", flags: 0, result: 0)
		// C.UTF-8		 "."			"[[:punct:]]"	       0
		assertMatchesFNMatch(".", pattern: "[[:punct:]]", flags: 0, result: 0)
		// C.UTF-8		 "t"			"[[:punct:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "\t"			"[[:punct:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "0"			"[[:xdigit:]]"	       0
		assertMatchesFNMatch("0", pattern: "[[:xdigit:]]", flags: 0, result: 0)
		// C.UTF-8		 "\t"			"[[:xdigit:]]"	       NOMATCH
		assertMatchesFNMatch("\t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[:xdigit:]]"	       0
		assertMatchesFNMatch("a", pattern: "[[:xdigit:]]", flags: 0, result: 0)
		// C.UTF-8		 "A"			"[[:xdigit:]]"	       0
		assertMatchesFNMatch("A", pattern: "[[:xdigit:]]", flags: 0, result: 0)
		// C.UTF-8		 "t"			"[[:xdigit:]]"	       NOMATCH
		assertMatchesFNMatch("t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[alpha]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[alpha]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[alpha:]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[alpha:]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a]"			"[[alpha]]"	       0
		assertMatchesFNMatch("a]", pattern: "[[alpha]]", flags: 0, result: 0)
		// C.UTF-8		 "a]"			"[[alpha:]]"	       0
		assertMatchesFNMatch("a]", pattern: "[[alpha:]]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[[:alpha:][.b.]]"     0
		assertMatchesFNMatch("a", pattern: "[[:alpha:][.b.]]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[[:alpha:][=b=]]"     0
		assertMatchesFNMatch("a", pattern: "[[:alpha:][=b=]]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[[:alpha:][:digit:]]" 0
		assertMatchesFNMatch("a", pattern: "[[:alpha:][:digit:]]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[[:digit:][:alpha:]]" 0
		assertMatchesFNMatch("a", pattern: "[[:digit:][:alpha:]]", flags: 0, result: 0)
	}

	//  B.6 018(C) utf8
	@Test func b_6_018_c_utf8() {
		// C.UTF-8		 "a"			"[a-c]"		       0
		assertMatchesFNMatch("a", pattern: "[a-c]", flags: 0, result: 0)
		// C.UTF-8		 "b"			"[a-c]"		       0
		assertMatchesFNMatch("b", pattern: "[a-c]", flags: 0, result: 0)
		// C.UTF-8		 "c"			"[a-c]"		       0
		assertMatchesFNMatch("c", pattern: "[a-c]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[b-c]"		       NOMATCH
		assertMatchesFNMatch("a", pattern: "[b-c]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "d"			"[b-c]"		       NOMATCH
		assertMatchesFNMatch("d", pattern: "[b-c]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "B"			"[a-c]"		       NOMATCH
		assertMatchesFNMatch("B", pattern: "[a-c]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "b"			"[A-C]"		       NOMATCH
		assertMatchesFNMatch("b", pattern: "[A-C]", flags: 0, result: NOMATCH)
		// C.UTF-8		 ""			"[a-c]"		       NOMATCH
		assertMatchesFNMatch("", pattern: "[a-c]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "as"			"[a-ca-z]"	       NOMATCH
		assertMatchesFNMatch("as", pattern: "[a-ca-z]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[.a.]-c]"	       0
		assertMatchesFNMatch("a", pattern: "[[.a.]-c]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[a-[.c.]]"	       0
		assertMatchesFNMatch("a", pattern: "[a-[.c.]]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[[.a.]-[.c.]]"	       0
		assertMatchesFNMatch("a", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
		// C.UTF-8		 "b"			"[[.a.]-c]"	       0
		assertMatchesFNMatch("b", pattern: "[[.a.]-c]", flags: 0, result: 0)
		// C.UTF-8		 "b"			"[a-[.c.]]"	       0
		assertMatchesFNMatch("b", pattern: "[a-[.c.]]", flags: 0, result: 0)
		// C.UTF-8		 "b"			"[[.a.]-[.c.]]"	       0
		assertMatchesFNMatch("b", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
		// C.UTF-8		 "c"			"[[.a.]-c]"	       0
		assertMatchesFNMatch("c", pattern: "[[.a.]-c]", flags: 0, result: 0)
		// C.UTF-8		 "c"			"[a-[.c.]]"	       0
		assertMatchesFNMatch("c", pattern: "[a-[.c.]]", flags: 0, result: 0)
		// C.UTF-8		 "c"			"[[.a.]-[.c.]]"	       0
		assertMatchesFNMatch("c", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0)
		// C.UTF-8		 "d"			"[[.a.]-c]"	       NOMATCH
		assertMatchesFNMatch("d", pattern: "[[.a.]-c]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "d"			"[a-[.c.]]"	       NOMATCH
		assertMatchesFNMatch("d", pattern: "[a-[.c.]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "d"			"[[.a.]-[.c.]]"	       NOMATCH
		assertMatchesFNMatch("d", pattern: "[[.a.]-[.c.]]", flags: 0, result: NOMATCH)
	}

	//  B.6 019(C) utf8
	@Test func b_6_019_c_utf8() {
		// C.UTF-8		 "a"			"[c-a]"		       NOMATCH
		assertMatchesFNMatch("a", pattern: "[c-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[.c.]-a]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[c-[.a.]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[[.c.]-[.a.]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "c"			"[c-a]"		       NOMATCH
		assertMatchesFNMatch("c", pattern: "[c-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "c"			"[[.c.]-a]"	       NOMATCH
		assertMatchesFNMatch("c", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "c"			"[c-[.a.]]"	       NOMATCH
		assertMatchesFNMatch("c", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "c"			"[[.c.]-[.a.]]"	       NOMATCH
		assertMatchesFNMatch("c", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH)
	}

	//  B.6 020(C) utf8
	@Test func b_6_020_c_utf8() {
		// C.UTF-8		 "a"			"[a-c0-9]"	       0
		assertMatchesFNMatch("a", pattern: "[a-c0-9]", flags: 0, result: 0)
		// C.UTF-8		 "d"			"[a-c0-9]"	       NOMATCH
		assertMatchesFNMatch("d", pattern: "[a-c0-9]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "B"			"[a-c0-9]"	       NOMATCH
		assertMatchesFNMatch("B", pattern: "[a-c0-9]", flags: 0, result: NOMATCH)
	}

	//  B.6 021(C) utf8
	@Test func b_6_021_c_utf8() {
		// C.UTF-8		 "-"			"[-a]"		       0
		assertMatchesFNMatch("-", pattern: "[-a]", flags: 0, result: 0)
		// C.UTF-8		 "a"			"[-b]"		       NOMATCH
		assertMatchesFNMatch("a", pattern: "[-b]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "-"			"[!-a]"		       NOMATCH
		assertMatchesFNMatch("-", pattern: "[!-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a"			"[!-b]"		       0
		assertMatchesFNMatch("a", pattern: "[!-b]", flags: 0, result: 0)
		// C.UTF-8		 "-"			"[a-c-0-9]"	       0
		assertMatchesFNMatch("-", pattern: "[a-c-0-9]", flags: 0, result: 0)
		// C.UTF-8		 "b"			"[a-c-0-9]"	       0
		assertMatchesFNMatch("b", pattern: "[a-c-0-9]", flags: 0, result: 0)
		// C.UTF-8		 "a:"			"a[0-9-a]"	       NOMATCH
		assertMatchesFNMatch("a:", pattern: "a[0-9-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		 "a:"			"a[09-a]"	       0
		assertMatchesFNMatch("a:", pattern: "a[09-a]", flags: 0, result: 0)
	}

	//  B.6 024(C) utf8
	@Test func b_6_024_c_utf8() {
		// C.UTF-8		 ""			"*"		       0
		assertMatchesFNMatch("", pattern: "*", flags: 0, result: 0)
		// C.UTF-8		 "asd/sdf"		"*"		       0
		assertMatchesFNMatch("asd/sdf", pattern: "*", flags: 0, result: 0)
	}

	//  B.6 025(C) utf8
	@Test func b_6_025_c_utf8() {
		// C.UTF-8		 "as"			"[a-c][a-z]"	       0
		assertMatchesFNMatch("as", pattern: "[a-c][a-z]", flags: 0, result: 0)
		// C.UTF-8		 "as"			"??"		       0
		assertMatchesFNMatch("as", pattern: "??", flags: 0, result: 0)
	}

	//  B.6 026(C) utf8
	@Test func b_6_026_c_utf8() {
		// C.UTF-8		 "asd/sdf"		"as*df"		       0
		assertMatchesFNMatch("asd/sdf", pattern: "as*df", flags: 0, result: 0)
		// C.UTF-8		 "asd/sdf"		"as*"		       0
		assertMatchesFNMatch("asd/sdf", pattern: "as*", flags: 0, result: 0)
		// C.UTF-8		 "asd/sdf"		"*df"		       0
		assertMatchesFNMatch("asd/sdf", pattern: "*df", flags: 0, result: 0)
		// C.UTF-8		 "asd/sdf"		"as*dg"		       NOMATCH
		assertMatchesFNMatch("asd/sdf", pattern: "as*dg", flags: 0, result: NOMATCH)
		// C.UTF-8		 "asdf"			"as*df"		       0
		assertMatchesFNMatch("asdf", pattern: "as*df", flags: 0, result: 0)
		// C.UTF-8		 "asdf"			"as*df?"	       NOMATCH
		assertMatchesFNMatch("asdf", pattern: "as*df?", flags: 0, result: NOMATCH)
		// C.UTF-8		 "asdf"			"as*??"		       0
		assertMatchesFNMatch("asdf", pattern: "as*??", flags: 0, result: 0)
		// C.UTF-8		 "asdf"			"a*???"		       0
		assertMatchesFNMatch("asdf", pattern: "a*???", flags: 0, result: 0)
		// C.UTF-8		 "asdf"			"*????"		       0
		assertMatchesFNMatch("asdf", pattern: "*????", flags: 0, result: 0)
		// C.UTF-8		 "asdf"			"????*"		       0
		assertMatchesFNMatch("asdf", pattern: "????*", flags: 0, result: 0)
		// C.UTF-8		 "asdf"			"??*?"		       0
		assertMatchesFNMatch("asdf", pattern: "??*?", flags: 0, result: 0)
	}

	//  B.6 027(C) utf8
	@Test func b_6_027_c_utf8() {
		// C.UTF-8		 "/"			"/"		       0
		assertMatchesFNMatch("/", pattern: "/", flags: 0, result: 0)
		// C.UTF-8		 "/"			"/*"		       0
		assertMatchesFNMatch("/", pattern: "/*", flags: 0, result: 0)
		// C.UTF-8		 "/"			"*/"		       0
		assertMatchesFNMatch("/", pattern: "*/", flags: 0, result: 0)
		// C.UTF-8		 "/"			"/?"		       NOMATCH
		assertMatchesFNMatch("/", pattern: "/?", flags: 0, result: NOMATCH)
		// C.UTF-8		 "/"			"?/"		       NOMATCH
		assertMatchesFNMatch("/", pattern: "?/", flags: 0, result: NOMATCH)
		// C.UTF-8		 "/"			"?"		       0
		assertMatchesFNMatch("/", pattern: "?", flags: 0, result: 0)
		// C.UTF-8		 "."			"?"		       0
		assertMatchesFNMatch(".", pattern: "?", flags: 0, result: 0)
		// C.UTF-8		 "/."			"??"		       0
		assertMatchesFNMatch("/.", pattern: "??", flags: 0, result: 0)
		// C.UTF-8		 "/"			"[!a-c]"	       0
		assertMatchesFNMatch("/", pattern: "[!a-c]", flags: 0, result: 0)
		// C.UTF-8		 "."			"[!a-c]"	       0
		assertMatchesFNMatch(".", pattern: "[!a-c]", flags: 0, result: 0)
	}

	//  B.6 029(C) utf8
	@Test func b_6_029_c_utf8() {
		// C.UTF-8		 "/"			"/"		       0       PATHNAME
		assertMatchesFNMatch("/", pattern: "/", flags: PATHNAME, result: 0)
		// C.UTF-8		 "//"			"//"		       0       PATHNAME
		assertMatchesFNMatch("//", pattern: "//", flags: PATHNAME, result: 0)
		// C.UTF-8		 "/.a"			"/*"		       0       PATHNAME
		assertMatchesFNMatch("/.a", pattern: "/*", flags: PATHNAME, result: 0)
		// C.UTF-8		 "/.a"			"/?a"		       0       PATHNAME
		assertMatchesFNMatch("/.a", pattern: "/?a", flags: PATHNAME, result: 0)
		// C.UTF-8		 "/.a"			"/[!a-z]a"	       0       PATHNAME
		assertMatchesFNMatch("/.a", pattern: "/[!a-z]a", flags: PATHNAME, result: 0)
		// C.UTF-8		 "/.a/.b"		"/*/?b"		       0       PATHNAME
		assertMatchesFNMatch("/.a/.b", pattern: "/*/?b", flags: PATHNAME, result: 0)
	}

	//  B.6 030(C) utf8
	@Test func b_6_030_c_utf8() {
		// C.UTF-8		 "/"			"?"		       NOMATCH PATHNAME
		assertMatchesFNMatch("/", pattern: "?", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		 "/"			"*"		       NOMATCH PATHNAME
		assertMatchesFNMatch("/", pattern: "*", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		 "a/b"			"a?b"		       NOMATCH PATHNAME
		assertMatchesFNMatch("a/b", pattern: "a?b", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		 "/.a/.b"		"/*b"		       NOMATCH PATHNAME
		assertMatchesFNMatch("/.a/.b", pattern: "/*b", flags: PATHNAME, result: NOMATCH)
	}

	//  B.6 031(C) utf8
	@Test func b_6_031_c_utf8() {
		// C.UTF-8		 "/$"			"\\/\\$"	       0
		assertMatchesFNMatch("/$", pattern: "\\/\\$", flags: 0, result: 0)
		// C.UTF-8		 "/["			"\\/\\["	       0
		assertMatchesFNMatch("/[", pattern: "\\/\\[", flags: 0, result: 0)
		withKnownIssue {
			// C.UTF-8		 "/["			"\\/["		       0
			assertMatchesFNMatch("/[", pattern: "\\/[", flags: 0, result: 0)
		}
		// C.UTF-8		 "/[]"			"\\/\\[]"	       0
		assertMatchesFNMatch("/[]", pattern: "\\/\\[]", flags: 0, result: 0)
	}

	//  B.6 032(C) utf8
	@Test func b_6_032_c_utf8() {
		// C.UTF-8		 "/$"			"\\/\\$"	       NOMATCH NOESCAPE
		assertMatchesFNMatch("/$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH)
		// C.UTF-8		 "/\\$"			"\\/\\$"	       NOMATCH NOESCAPE
		assertMatchesFNMatch("/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH)
		// C.UTF-8		 "\\/\\$"		"\\/\\$"	       0       NOESCAPE
		assertMatchesFNMatch("\\/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: 0)
	}

	//  B.6 033(C) utf8
	@Test func b_6_033_c_utf8() {
		// C.UTF-8		 ".asd"			".*"		       0       PERIOD
		assertMatchesFNMatch(".asd", pattern: ".*", flags: PERIOD, result: 0)
		// C.UTF-8		 "/.asd"		"*"		       0       PERIOD
		assertMatchesFNMatch("/.asd", pattern: "*", flags: PERIOD, result: 0)
		// C.UTF-8		 "/as/.df"		"*/?*f"		       0       PERIOD
		assertMatchesFNMatch("/as/.df", pattern: "*/?*f", flags: PERIOD, result: 0)
		// C.UTF-8		 "..asd"		".[!a-z]*"	       0       PERIOD
		assertMatchesFNMatch("..asd", pattern: ".[!a-z]*", flags: PERIOD, result: 0)
	}

	//  B.6 034(C) utf8
	@Test func b_6_034_c_utf8() {
		// C.UTF-8		 ".asd"			"*"		       NOMATCH PERIOD
		assertMatchesFNMatch(".asd", pattern: "*", flags: PERIOD, result: NOMATCH)
		// C.UTF-8		 ".asd"			"?asd"		       NOMATCH PERIOD
		assertMatchesFNMatch(".asd", pattern: "?asd", flags: PERIOD, result: NOMATCH)
		// C.UTF-8		 ".asd"			"[!a-z]*"	       NOMATCH PERIOD
		assertMatchesFNMatch(".asd", pattern: "[!a-z]*", flags: PERIOD, result: NOMATCH)
	}

	//  B.6 035(C) utf8
	@Test func b_6_035_c_utf8() {
		// C.UTF-8		 "/."			"/."		       0       PATHNAME|PERIOD
		assertMatchesFNMatch("/.", pattern: "/.", flags: PATHNAME | PERIOD, result: 0)
		// C.UTF-8		 "/.a./.b."		"/.*/.*"	       0       PATHNAME|PERIOD
		assertMatchesFNMatch("/.a./.b.", pattern: "/.*/.*", flags: PATHNAME | PERIOD, result: 0)
		// C.UTF-8		 "/.a./.b."		"/.??/.??"	       0       PATHNAME|PERIOD
		assertMatchesFNMatch("/.a./.b.", pattern: "/.??/.??", flags: PATHNAME | PERIOD, result: 0)
	}

	//  B.6 036(C) utf8
	@Test func b_6_036_c_utf8() {
		// C.UTF-8		 "/."			"*"		       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/.", pattern: "*", flags: PATHNAME | PERIOD, result: NOMATCH)
		// C.UTF-8		 "/."			"/*"		       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/.", pattern: "/*", flags: PATHNAME | PERIOD, result: NOMATCH)
		// C.UTF-8		 "/."			"/?"		       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/.", pattern: "/?", flags: PATHNAME | PERIOD, result: NOMATCH)
		// C.UTF-8		 "/."			"/[!a-z]"	       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/.", pattern: "/[!a-z]", flags: PATHNAME | PERIOD, result: NOMATCH)
		// C.UTF-8		 "/a./.b."		"/*/*"		       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/a./.b.", pattern: "/*/*", flags: PATHNAME | PERIOD, result: NOMATCH)
		// C.UTF-8		 "/a./.b."		"/??/???"	       NOMATCH PATHNAME|PERIOD
		assertMatchesFNMatch("/a./.b.", pattern: "/??/???", flags: PATHNAME | PERIOD, result: NOMATCH)
	}

	//  Some home-grown tests.
	@Test func some_home_grown_tests() {
		// C.UTF-8		"foobar"		"foo*[abc]z"	       NOMATCH
		assertMatchesFNMatch("foobar", pattern: "foo*[abc]z", flags: 0, result: NOMATCH)
		// C.UTF-8		"foobaz"		"foo*[abc][xyz]"       0
		assertMatchesFNMatch("foobaz", pattern: "foo*[abc][xyz]", flags: 0, result: 0)
		// C.UTF-8		"foobaz"		"foo?*[abc][xyz]"      0
		assertMatchesFNMatch("foobaz", pattern: "foo?*[abc][xyz]", flags: 0, result: 0)
		// C.UTF-8		"foobaz"		"foo?*[abc][x/yz]"     0
		assertMatchesFNMatch("foobaz", pattern: "foo?*[abc][x/yz]", flags: 0, result: 0)
		// C.UTF-8		"foobaz"		"foo?*[abc]/[xyz]"     NOMATCH PATHNAME
		assertMatchesFNMatch("foobaz", pattern: "foo?*[abc]/[xyz]", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		"a"			"a/"                   NOMATCH PATHNAME
		assertMatchesFNMatch("a", pattern: "a/", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		"a/"			"a"		       NOMATCH PATHNAME
		assertMatchesFNMatch("a/", pattern: "a", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		"//a"			"/a"		       NOMATCH PATHNAME
		assertMatchesFNMatch("//a", pattern: "/a", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		"/a"			"//a"		       NOMATCH PATHNAME
		assertMatchesFNMatch("/a", pattern: "//a", flags: PATHNAME, result: NOMATCH)
		// C.UTF-8		"az"			"[a-]z"		       0
		assertMatchesFNMatch("az", pattern: "[a-]z", flags: 0, result: 0)
		// C.UTF-8		"bz"			"[ab-]z"	       0
		assertMatchesFNMatch("bz", pattern: "[ab-]z", flags: 0, result: 0)
		// C.UTF-8		"cz"			"[ab-]z"	       NOMATCH
		assertMatchesFNMatch("cz", pattern: "[ab-]z", flags: 0, result: NOMATCH)
		// C.UTF-8		"-z"			"[ab-]z"	       0
		assertMatchesFNMatch("-z", pattern: "[ab-]z", flags: 0, result: 0)
		// C.UTF-8		"az"			"[-a]z"		       0
		assertMatchesFNMatch("az", pattern: "[-a]z", flags: 0, result: 0)
		// C.UTF-8		"bz"			"[-ab]z"	       0
		assertMatchesFNMatch("bz", pattern: "[-ab]z", flags: 0, result: 0)
		// C.UTF-8		"cz"			"[-ab]z"	       NOMATCH
		assertMatchesFNMatch("cz", pattern: "[-ab]z", flags: 0, result: NOMATCH)
		// C.UTF-8		"-z"			"[-ab]z"	       0
		assertMatchesFNMatch("-z", pattern: "[-ab]z", flags: 0, result: 0)
		// C.UTF-8		"\\"			"[\\\\-a]"	       0
		assertMatchesFNMatch("\\", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C.UTF-8		"_"			"[\\\\-a]"	       0
		assertMatchesFNMatch("_", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C.UTF-8		"a"			"[\\\\-a]"	       0
		assertMatchesFNMatch("a", pattern: "[\\\\-a]", flags: 0, result: 0)
		// C.UTF-8		"-"			"[\\\\-a]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[\\\\-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"\\"			"[\\]-a]"	       NOMATCH
		assertMatchesFNMatch("\\", pattern: "[\\]-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"_"			"[\\]-a]"	       0
		assertMatchesFNMatch("_", pattern: "[\\]-a]", flags: 0, result: 0)
		// C.UTF-8		"a"			"[\\]-a]"	       0
		assertMatchesFNMatch("a", pattern: "[\\]-a]", flags: 0, result: 0)
		// C.UTF-8		"]"			"[\\]-a]"	       0
		assertMatchesFNMatch("]", pattern: "[\\]-a]", flags: 0, result: 0)
		// C.UTF-8		"-"			"[\\]-a]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[\\]-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"\\"			"[!\\\\-a]"	       NOMATCH
		assertMatchesFNMatch("\\", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"_"			"[!\\\\-a]"	       NOMATCH
		assertMatchesFNMatch("_", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"a"			"[!\\\\-a]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH)
		// C.UTF-8		"-"			"[!\\\\-a]"	       0
		assertMatchesFNMatch("-", pattern: "[!\\\\-a]", flags: 0, result: 0)
		// C.UTF-8		"!"			"[\\!-]"	       0
		assertMatchesFNMatch("!", pattern: "[\\!-]", flags: 0, result: 0)
		// C.UTF-8		"-"			"[\\!-]"	       0
		assertMatchesFNMatch("-", pattern: "[\\!-]", flags: 0, result: 0)
		// C.UTF-8		"\\"			"[\\!-]"	       NOMATCH
		assertMatchesFNMatch("\\", pattern: "[\\!-]", flags: 0, result: NOMATCH)
		// C.UTF-8		"Z"			"[Z-\\\\]"	       0
		assertMatchesFNMatch("Z", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C.UTF-8		"["			"[Z-\\\\]"	       0
		assertMatchesFNMatch("[", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C.UTF-8		"\\"			"[Z-\\\\]"	       0
		assertMatchesFNMatch("\\", pattern: "[Z-\\\\]", flags: 0, result: 0)
		// C.UTF-8		"-"			"[Z-\\\\]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[Z-\\\\]", flags: 0, result: NOMATCH)
		// C.UTF-8		"Z"			"[Z-\\]]"	       0
		assertMatchesFNMatch("Z", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C.UTF-8		"["			"[Z-\\]]"	       0
		assertMatchesFNMatch("[", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C.UTF-8		"\\"			"[Z-\\]]"	       0
		assertMatchesFNMatch("\\", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C.UTF-8		"]"			"[Z-\\]]"	       0
		assertMatchesFNMatch("]", pattern: "[Z-\\]]", flags: 0, result: 0)
		// C.UTF-8		"-"			"[Z-\\]]"	       NOMATCH
		assertMatchesFNMatch("-", pattern: "[Z-\\]]", flags: 0, result: NOMATCH)
	}

	//  Character vs bytes
	@Test func character_vs_bytes() {
		// de_DE.ISO-8859-1 "a"			"[a-z]"		       0
		assertMatchesFNMatch("a", pattern: "[a-z]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "z"			"[a-z]"		       0
		assertMatchesFNMatch("z", pattern: "[a-z]", flags: 0, result: 0)
		withKnownIssue {
			// de_DE.ISO-8859-1 "\344"			"[a-z]"		       0
			assertMatchesFNMatch("\u{e4}", pattern: "[a-z]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\366"			"[a-z]"		       0
			assertMatchesFNMatch("\u{f6}", pattern: "[a-z]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\374"			"[a-z]"		       0
			assertMatchesFNMatch("\u{fc}", pattern: "[a-z]", flags: 0, result: 0)
		}
		// de_DE.ISO-8859-1 "A"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("A", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "Z"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("Z", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\304"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("\u{c4}", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\326"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("\u{d6}", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\334"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("\u{dc}", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "a"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("a", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "z"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("z", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\344"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("\u{e4}", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\366"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("\u{f6}", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\374"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("\u{fc}", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "A"			"[A-Z]"		       0
		assertMatchesFNMatch("A", pattern: "[A-Z]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "Z"			"[A-Z]"		       0
		assertMatchesFNMatch("Z", pattern: "[A-Z]", flags: 0, result: 0)
		withKnownIssue {
			// de_DE.ISO-8859-1 "\304"			"[A-Z]"		       0
			assertMatchesFNMatch("\u{c4}", pattern: "[A-Z]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\326"			"[A-Z]"		       0
			assertMatchesFNMatch("\u{d6}", pattern: "[A-Z]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\334"			"[A-Z]"		       0
			assertMatchesFNMatch("\u{dc}", pattern: "[A-Z]", flags: 0, result: 0)
		}
		// de_DE.ISO-8859-1 "a"			"[[:lower:]]"	       0
		assertMatchesFNMatch("a", pattern: "[[:lower:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "z"			"[[:lower:]]"	       0
		assertMatchesFNMatch("z", pattern: "[[:lower:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\344"			"[[:lower:]]"	       0
		assertMatchesFNMatch("\u{e4}", pattern: "[[:lower:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\366"			"[[:lower:]]"	       0
		assertMatchesFNMatch("\u{f6}", pattern: "[[:lower:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\374"			"[[:lower:]]"	       0
		assertMatchesFNMatch("\u{fc}", pattern: "[[:lower:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "A"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("A", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "Z"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("Z", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\304"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("\u{c4}", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\326"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("\u{d6}", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\334"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("\u{dc}", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "a"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "z"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("z", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\344"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("\u{e4}", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\366"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("\u{f6}", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "\374"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("\u{fc}", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.ISO-8859-1 "A"			"[[:upper:]]"	       0
		assertMatchesFNMatch("A", pattern: "[[:upper:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "Z"			"[[:upper:]]"	       0
		assertMatchesFNMatch("Z", pattern: "[[:upper:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\304"			"[[:upper:]]"	       0
		assertMatchesFNMatch("\u{c4}", pattern: "[[:upper:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\326"			"[[:upper:]]"	       0
		assertMatchesFNMatch("\u{d6}", pattern: "[[:upper:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\334"			"[[:upper:]]"	       0
		assertMatchesFNMatch("\u{dc}", pattern: "[[:upper:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "a"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("a", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "z"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("z", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\344"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("\u{e4}", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\366"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("\u{f6}", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\374"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("\u{fc}", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "A"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("A", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "Z"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("Z", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\304"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("\u{c4}", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\326"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("\u{d6}", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.ISO-8859-1 "\334"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("\u{dc}", pattern: "[[:alpha:]]", flags: 0, result: 0)

		withKnownIssue {
			// de_DE.ISO-8859-1 "a"			"[[=a=]b]"	       0
			assertMatchesFNMatch("a", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\342"			"[[=a=]b]"	       0
			assertMatchesFNMatch("\u{e2}", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\340"			"[[=a=]b]"	       0
			assertMatchesFNMatch("\u{e0}", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\341"			"[[=a=]b]"	       0
			assertMatchesFNMatch("\u{e1}", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[=a=]b]"	       0
			assertMatchesFNMatch("\u{e4}", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "b"			"[[=a=]b]"	       0
			assertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "c"			"[[=a=]b]"	       NOMATCH
			assertMatchesFNMatch("c", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
			// de_DE.ISO-8859-1 "a"			"[[=\342=]b]"	       0
			assertMatchesFNMatch("a", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\342"			"[[=\342=]b]"	       0
			assertMatchesFNMatch("\u{e2}", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\340"			"[[=\342=]b]"	       0
			assertMatchesFNMatch("\u{e0}", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\341"			"[[=\342=]b]"	       0
			assertMatchesFNMatch("\u{e1}", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[=\342=]b]"	       0
			assertMatchesFNMatch("\u{e4}", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "b"			"[[=\342=]b]"	       0
			assertMatchesFNMatch("b", pattern: "[[=\u{e2}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "c"			"[[=\342=]b]"	       NOMATCH
			assertMatchesFNMatch("c", pattern: "[[=\u{e2}=]b]", flags: 0, result: NOMATCH)
			// de_DE.ISO-8859-1 "a"			"[[=\340=]b]"	       0
			assertMatchesFNMatch("a", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\342"			"[[=\340=]b]"	       0
			assertMatchesFNMatch("\u{e2}", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\340"			"[[=\340=]b]"	       0
			assertMatchesFNMatch("\u{e0}", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\341"			"[[=\340=]b]"	       0
			assertMatchesFNMatch("\u{e1}", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[=\340=]b]"	       0
			assertMatchesFNMatch("\u{e4}", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "b"			"[[=\340=]b]"	       0
			assertMatchesFNMatch("b", pattern: "[[=\u{e0}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "c"			"[[=\340=]b]"	       NOMATCH
			assertMatchesFNMatch("c", pattern: "[[=\u{e0}=]b]", flags: 0, result: NOMATCH)
			// de_DE.ISO-8859-1 "a"			"[[=\341=]b]"	       0
			assertMatchesFNMatch("a", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\342"			"[[=\341=]b]"	       0
			assertMatchesFNMatch("\u{e2}", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\340"			"[[=\341=]b]"	       0
			assertMatchesFNMatch("\u{e0}", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\341"			"[[=\341=]b]"	       0
			assertMatchesFNMatch("\u{e1}", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[=\341=]b]"	       0
			assertMatchesFNMatch("\u{e4}", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "b"			"[[=\341=]b]"	       0
			assertMatchesFNMatch("b", pattern: "[[=\u{e1}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "c"			"[[=\341=]b]"	       NOMATCH
			assertMatchesFNMatch("c", pattern: "[[=\u{e1}=]b]", flags: 0, result: NOMATCH)
			// de_DE.ISO-8859-1 "a"			"[[=\344=]b]"	       0
			assertMatchesFNMatch("a", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\342"			"[[=\344=]b]"	       0
			assertMatchesFNMatch("\u{e2}", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\340"			"[[=\344=]b]"	       0
			assertMatchesFNMatch("\u{e0}", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\341"			"[[=\344=]b]"	       0
			assertMatchesFNMatch("\u{e1}", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "\344"			"[[=\344=]b]"	       0
			assertMatchesFNMatch("\u{e4}", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "b"			"[[=\344=]b]"	       0
			assertMatchesFNMatch("b", pattern: "[[=\u{e4}=]b]", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "c"			"[[=\344=]b]"	       NOMATCH
			assertMatchesFNMatch("c", pattern: "[[=\u{e4}=]b]", flags: 0, result: NOMATCH)

			// de_DE.ISO-8859-1 "aa"			"[[.a.]]a"	       0
			assertMatchesFNMatch("aa", pattern: "[[.a.]]a", flags: 0, result: 0)
			// de_DE.ISO-8859-1 "ba"			"[[.a.]]a"	       NOMATCH
			assertMatchesFNMatch("ba", pattern: "[[.a.]]a", flags: 0, result: NOMATCH)
		}
	}

	//  multibyte character set
	@Test func multibyte_character_set() {
		// en_US.UTF-8	 "a"			"[a-z]"		       0
		assertMatchesFNMatch("a", pattern: "[a-z]", flags: 0, result: 0)
		// en_US.UTF-8	 "z"			"[a-z]"		       0
		assertMatchesFNMatch("z", pattern: "[a-z]", flags: 0, result: 0)
		// en_US.UTF-8	 "A"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("A", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// en_US.UTF-8	 "Z"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("Z", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// en_US.UTF-8	 "a"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("a", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// en_US.UTF-8	 "z"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("z", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// en_US.UTF-8	 "A"			"[A-Z]"		       0
		assertMatchesFNMatch("A", pattern: "[A-Z]", flags: 0, result: 0)
		// en_US.UTF-8	 "Z"			"[A-Z]"		       0
		assertMatchesFNMatch("Z", pattern: "[A-Z]", flags: 0, result: 0)
		// en_US.UTF-8	 "0"			"[0-9]"		       0
		assertMatchesFNMatch("0", pattern: "[0-9]", flags: 0, result: 0)
		// en_US.UTF-8	 "9"			"[0-9]"		       0
		assertMatchesFNMatch("9", pattern: "[0-9]", flags: 0, result: 0)
		// de_DE.UTF-8	 "a"			"[a-z]"		       0
		assertMatchesFNMatch("a", pattern: "[a-z]", flags: 0, result: 0)
		// de_DE.UTF-8	 "z"			"[a-z]"		       0
		assertMatchesFNMatch("z", pattern: "[a-z]", flags: 0, result: 0)
		withKnownIssue {
			// de_DE.UTF-8	 "ä"			"[a-z]"		       0
			assertMatchesFNMatch("ä", pattern: "[a-z]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ö"			"[a-z]"		       0
			assertMatchesFNMatch("ö", pattern: "[a-z]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ü"			"[a-z]"		       0
			assertMatchesFNMatch("ü", pattern: "[a-z]", flags: 0, result: 0)
		}
		// de_DE.UTF-8	 "A"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("A", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Z"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("Z", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ä"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("Ä", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ö"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("Ö", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ü"			"[a-z]"		       NOMATCH
		assertMatchesFNMatch("Ü", pattern: "[a-z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "a"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("a", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "z"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("z", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ä"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("ä", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ö"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("ö", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ü"			"[A-Z]"		       NOMATCH
		assertMatchesFNMatch("ü", pattern: "[A-Z]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "A"			"[A-Z]"		       0
		assertMatchesFNMatch("A", pattern: "[A-Z]", flags: 0, result: 0)
		// de_DE.UTF-8	 "Z"			"[A-Z]"		       0
		assertMatchesFNMatch("Z", pattern: "[A-Z]", flags: 0, result: 0)
		withKnownIssue {
			// de_DE.UTF-8	 "Ä"			"[A-Z]"		       0
			assertMatchesFNMatch("Ä", pattern: "[A-Z]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Ö"			"[A-Z]"		       0
			assertMatchesFNMatch("Ö", pattern: "[A-Z]", flags: 0, result: 0)
			// de_DE.UTF-8	 "Ü"			"[A-Z]"		       0
			assertMatchesFNMatch("Ü", pattern: "[A-Z]", flags: 0, result: 0)
			// de_DE.UTF-8	 "a"			"[[:lower:]]"	       0
			assertMatchesFNMatch("a", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "z"			"[[:lower:]]"	       0
			assertMatchesFNMatch("z", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[:lower:]]"	       0
			assertMatchesFNMatch("ä", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ö"			"[[:lower:]]"	       0
			assertMatchesFNMatch("ö", pattern: "[[:lower:]]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ü"			"[[:lower:]]"	       0
			assertMatchesFNMatch("ü", pattern: "[[:lower:]]", flags: 0, result: 0)
		}
		// de_DE.UTF-8	 "A"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("A", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Z"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("Z", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ä"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("Ä", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ö"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("Ö", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "Ü"			"[[:lower:]]"	       NOMATCH
		assertMatchesFNMatch("Ü", pattern: "[[:lower:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "a"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("a", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "z"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("z", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ä"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("ä", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ö"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("ö", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "ü"			"[[:upper:]]"	       NOMATCH
		assertMatchesFNMatch("ü", pattern: "[[:upper:]]", flags: 0, result: NOMATCH)
		// de_DE.UTF-8	 "A"			"[[:upper:]]"	       0
		assertMatchesFNMatch("A", pattern: "[[:upper:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "Z"			"[[:upper:]]"	       0
		assertMatchesFNMatch("Z", pattern: "[[:upper:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "Ä"			"[[:upper:]]"	       0
		assertMatchesFNMatch("Ä", pattern: "[[:upper:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "Ö"			"[[:upper:]]"	       0
		assertMatchesFNMatch("Ö", pattern: "[[:upper:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "Ü"			"[[:upper:]]"	       0
		assertMatchesFNMatch("Ü", pattern: "[[:upper:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "a"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("a", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "z"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("z", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "ä"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("ä", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "ö"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("ö", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "ü"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("ü", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "A"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("A", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "Z"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("Z", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "Ä"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("Ä", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "Ö"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("Ö", pattern: "[[:alpha:]]", flags: 0, result: 0)
		// de_DE.UTF-8	 "Ü"			"[[:alpha:]]"	       0
		assertMatchesFNMatch("Ü", pattern: "[[:alpha:]]", flags: 0, result: 0)

		withKnownIssue {
			// de_DE.UTF-8	 "a"			"[[=a=]b]"	       0
			assertMatchesFNMatch("a", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "â"			"[[=a=]b]"	       0
			assertMatchesFNMatch("â", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "à"			"[[=a=]b]"	       0
			assertMatchesFNMatch("à", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "á"			"[[=a=]b]"	       0
			assertMatchesFNMatch("á", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[=a=]b]"	       0
			assertMatchesFNMatch("ä", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "b"			"[[=a=]b]"	       0
			assertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "c"			"[[=a=]b]"	       NOMATCH
			assertMatchesFNMatch("c", pattern: "[[=a=]b]", flags: 0, result: NOMATCH)
			// de_DE.UTF-8	 "a"			"[[=â=]b]"	       0
			assertMatchesFNMatch("a", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "â"			"[[=â=]b]"	       0
			assertMatchesFNMatch("â", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "à"			"[[=â=]b]"	       0
			assertMatchesFNMatch("à", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "á"			"[[=â=]b]"	       0
			assertMatchesFNMatch("á", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[=â=]b]"	       0
			assertMatchesFNMatch("ä", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "b"			"[[=â=]b]"	       0
			assertMatchesFNMatch("b", pattern: "[[=â=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "c"			"[[=â=]b]"	       NOMATCH
			assertMatchesFNMatch("c", pattern: "[[=â=]b]", flags: 0, result: NOMATCH)
			// de_DE.UTF-8	 "a"			"[[=à=]b]"	       0
			assertMatchesFNMatch("a", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "â"			"[[=à=]b]"	       0
			assertMatchesFNMatch("â", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "à"			"[[=à=]b]"	       0
			assertMatchesFNMatch("à", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "á"			"[[=à=]b]"	       0
			assertMatchesFNMatch("á", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[=à=]b]"	       0
			assertMatchesFNMatch("ä", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "b"			"[[=à=]b]"	       0
			assertMatchesFNMatch("b", pattern: "[[=à=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "c"			"[[=à=]b]"	       NOMATCH
			assertMatchesFNMatch("c", pattern: "[[=à=]b]", flags: 0, result: NOMATCH)
			// de_DE.UTF-8	 "a"			"[[=á=]b]"	       0
			assertMatchesFNMatch("a", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "â"			"[[=á=]b]"	       0
			assertMatchesFNMatch("â", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "à"			"[[=á=]b]"	       0
			assertMatchesFNMatch("à", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "á"			"[[=á=]b]"	       0
			assertMatchesFNMatch("á", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[=á=]b]"	       0
			assertMatchesFNMatch("ä", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "b"			"[[=á=]b]"	       0
			assertMatchesFNMatch("b", pattern: "[[=á=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "c"			"[[=á=]b]"	       NOMATCH
			assertMatchesFNMatch("c", pattern: "[[=á=]b]", flags: 0, result: NOMATCH)
			// de_DE.UTF-8	 "a"			"[[=ä=]b]"	       0
			assertMatchesFNMatch("a", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "â"			"[[=ä=]b]"	       0
			assertMatchesFNMatch("â", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "à"			"[[=ä=]b]"	       0
			assertMatchesFNMatch("à", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "á"			"[[=ä=]b]"	       0
			assertMatchesFNMatch("á", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "ä"			"[[=ä=]b]"	       0
			assertMatchesFNMatch("ä", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "b"			"[[=ä=]b]"	       0
			assertMatchesFNMatch("b", pattern: "[[=ä=]b]", flags: 0, result: 0)
			// de_DE.UTF-8	 "c"			"[[=ä=]b]"	       NOMATCH
			assertMatchesFNMatch("c", pattern: "[[=ä=]b]", flags: 0, result: NOMATCH)

			// de_DE.UTF-8	 "aa"			"[[.a.]]a"	       0
			assertMatchesFNMatch("aa", pattern: "[[.a.]]a", flags: 0, result: 0)
			// de_DE.UTF-8	 "ba"			"[[.a.]]a"	       NOMATCH
			assertMatchesFNMatch("ba", pattern: "[[.a.]]a", flags: 0, result: NOMATCH)
		}
	}

	//  GNU extensions.
	@Test func gnu_extensions() {
		// C		 "x"			"x"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x/y"			"x"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x/y/z"		"x"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y/z", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x"			"*"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x/y"			"*"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x/y/z"		"*"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y/z", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x"			"*x"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0)

		// C		 "x/y"			"*x"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x/y/z"		"*x"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y/z", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x"			"x*"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x/y"			"x*"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x/y/z"		"x*"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y/z", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x"			"a"		       NOMATCH PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
		// C		 "x/y"			"a"		       NOMATCH PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
		// C		 "x/y/z"		"a"		       NOMATCH PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y/z", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
		// C		 "x"			"x/y"		       NOMATCH PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
		// C		 "x/y"			"x/y"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x/y/z"		"x/y"		       0       PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y/z", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: 0)
		// C		 "x"			"x?y"		       NOMATCH PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
		// C		 "x/y"			"x?y"		       NOMATCH PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
		// C		 "x/y/z"		"x?y"		       NOMATCH PATHNAME|LEADING_DIR
		assertMatchesFNMatch("x/y/z", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH)
	}

	//  Bug 14185
	@Test func bug_14185() {
		// en_US.UTF-8	 "\366.csv"		"*.csv"                0
		assertMatchesFNMatch("\u{f6}.csv", pattern: "*.csv", flags: 0, result: 0)
	}

	//  ksh style matching.
	@Test func ksh_style_matching() {
		// C		"abcd"			"?@(a|b)*@(c)d"	       0       EXTMATCH
		assertMatchesFNMatch("abcd", pattern: "?@(a|b)*@(c)d", flags: EXTMATCH, result: 0)
		// C		"/dev/udp/129.22.8.102/45" "/dev/@(tcp|udp)/*/*" 0     PATHNAME|EXTMATCH
		assertMatchesFNMatch("/dev/udp/129.22.8.102/45", pattern: "/dev/@(tcp|udp)/*/*", flags: PATHNAME | EXTMATCH, result: 0)
		// C		"12"			"[1-9]*([0-9])"        0       EXTMATCH
		assertMatchesFNMatch("12", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: 0)
		// C		"12abc"			"[1-9]*([0-9])"        NOMATCH EXTMATCH
		assertMatchesFNMatch("12abc", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH)
		// C		"1"			"[1-9]*([0-9])"	       0       EXTMATCH
		assertMatchesFNMatch("1", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: 0)
		// C		"07"			"+([0-7])"	       0       EXTMATCH
		assertMatchesFNMatch("07", pattern: "+([0-7])", flags: EXTMATCH, result: 0)
		// C		"0377"			"+([0-7])"	       0       EXTMATCH
		assertMatchesFNMatch("0377", pattern: "+([0-7])", flags: EXTMATCH, result: 0)
		// C		"09"			"+([0-7])"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("09", pattern: "+([0-7])", flags: EXTMATCH, result: NOMATCH)
		// C		"paragraph"		"para@(chute|graph)"   0       EXTMATCH
		assertMatchesFNMatch("paragraph", pattern: "para@(chute|graph)", flags: EXTMATCH, result: 0)
		// C		"paramour"		"para@(chute|graph)"   NOMATCH EXTMATCH
		assertMatchesFNMatch("paramour", pattern: "para@(chute|graph)", flags: EXTMATCH, result: NOMATCH)
		// C		"para991"		"para?([345]|99)1"     0       EXTMATCH
		assertMatchesFNMatch("para991", pattern: "para?([345]|99)1", flags: EXTMATCH, result: 0)
		// C		"para381"		"para?([345]|99)1"     NOMATCH EXTMATCH
		assertMatchesFNMatch("para381", pattern: "para?([345]|99)1", flags: EXTMATCH, result: NOMATCH)
		// C		"paragraph"		"para*([0-9])"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("paragraph", pattern: "para*([0-9])", flags: EXTMATCH, result: NOMATCH)
		// C		"para"			"para*([0-9])"	       0       EXTMATCH
		assertMatchesFNMatch("para", pattern: "para*([0-9])", flags: EXTMATCH, result: 0)
		// C		"para13829383746592"	"para*([0-9])"	       0       EXTMATCH
		assertMatchesFNMatch("para13829383746592", pattern: "para*([0-9])", flags: EXTMATCH, result: 0)
		// C		"paragraph"		"para+([0-9])"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("paragraph", pattern: "para+([0-9])", flags: EXTMATCH, result: NOMATCH)
		// C		"para"			"para+([0-9])"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("para", pattern: "para+([0-9])", flags: EXTMATCH, result: NOMATCH)
		// C		"para987346523"		"para+([0-9])"	       0       EXTMATCH
		assertMatchesFNMatch("para987346523", pattern: "para+([0-9])", flags: EXTMATCH, result: 0)
		// C		"paragraph"		"para!(*.[0-9])"       0       EXTMATCH
		assertMatchesFNMatch("paragraph", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0)
		// C		"para.38"		"para!(*.[0-9])"       0       EXTMATCH
		assertMatchesFNMatch("para.38", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0)
		// C		"para.graph"		"para!(*.[0-9])"       0       EXTMATCH
		assertMatchesFNMatch("para.graph", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0)
		// C		"para39"		"para!(*.[0-9])"       0       EXTMATCH
		assertMatchesFNMatch("para39", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0)
		// C		""			"*(0|1|3|5|7|9)"       0       EXTMATCH
		assertMatchesFNMatch("", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: 0)
		// C		"137577991"		"*(0|1|3|5|7|9)"       0       EXTMATCH
		assertMatchesFNMatch("137577991", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: 0)
		// C		"2468"			"*(0|1|3|5|7|9)"       NOMATCH EXTMATCH
		assertMatchesFNMatch("2468", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: NOMATCH)
		// C		"1358"			"*(0|1|3|5|7|9)"       NOMATCH EXTMATCH
		assertMatchesFNMatch("1358", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: NOMATCH)
		// C		"file.c"		"*.c?(c)"	       0       EXTMATCH
		assertMatchesFNMatch("file.c", pattern: "*.c?(c)", flags: EXTMATCH, result: 0)
		// C		"file.C"		"*.c?(c)"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("file.C", pattern: "*.c?(c)", flags: EXTMATCH, result: NOMATCH)
		// C		"file.cc"		"*.c?(c)"	       0       EXTMATCH
		assertMatchesFNMatch("file.cc", pattern: "*.c?(c)", flags: EXTMATCH, result: 0)
		// C		"file.ccc"		"*.c?(c)"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("file.ccc", pattern: "*.c?(c)", flags: EXTMATCH, result: NOMATCH)
		// C		"parse.y"		"!(*.c|*.h|Makefile.in|config*|README)" 0 EXTMATCH
		assertMatchesFNMatch("parse.y", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: 0)
		// C		"shell.c"		"!(*.c|*.h|Makefile.in|config*|README)" NOMATCH EXTMATCH
		assertMatchesFNMatch("shell.c", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: NOMATCH)
		// C		"Makefile"		"!(*.c|*.h|Makefile.in|config*|README)" 0 EXTMATCH
		assertMatchesFNMatch("Makefile", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: 0)
		// C		"VMS.FILE;1"		"*\;[1-9]*([0-9])"     0       EXTMATCH
		assertMatchesFNMatch("VMS.FILE;1", pattern: "*;[1-9]*([0-9])", flags: EXTMATCH, result: 0)
		// C		"VMS.FILE;0"		"*\;[1-9]*([0-9])"     NOMATCH EXTMATCH
		assertMatchesFNMatch("VMS.FILE;0", pattern: "*;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH)
		// C		"VMS.FILE;"		"*\;[1-9]*([0-9])"     NOMATCH EXTMATCH
		assertMatchesFNMatch("VMS.FILE;", pattern: "*;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH)
		// C		"VMS.FILE;139"		"*\;[1-9]*([0-9])"     0       EXTMATCH
		assertMatchesFNMatch("VMS.FILE;139", pattern: "*;[1-9]*([0-9])", flags: EXTMATCH, result: 0)
		// C		"VMS.FILE;1N"		"*\;[1-9]*([0-9])"     NOMATCH EXTMATCH
		assertMatchesFNMatch("VMS.FILE;1N", pattern: "*;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH)
		// C		"abcfefg"		"ab**(e|f)"	       0       EXTMATCH
		assertMatchesFNMatch("abcfefg", pattern: "ab**(e|f)", flags: EXTMATCH, result: 0)
		// C		"abcfefg"		"ab**(e|f)g"	       0       EXTMATCH
		assertMatchesFNMatch("abcfefg", pattern: "ab**(e|f)g", flags: EXTMATCH, result: 0)
		// C		"ab"			"ab*+(e|f)"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("ab", pattern: "ab*+(e|f)", flags: EXTMATCH, result: NOMATCH)
		// C		"abef"			"ab***ef"	       0       EXTMATCH
		assertMatchesFNMatch("abef", pattern: "ab***ef", flags: EXTMATCH, result: 0)
		// C		"abef"			"ab**"		       0       EXTMATCH
		assertMatchesFNMatch("abef", pattern: "ab**", flags: EXTMATCH, result: 0)
		// C		"fofo"			"*(f*(o))"	       0       EXTMATCH
		assertMatchesFNMatch("fofo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0)
		// C		"ffo"			"*(f*(o))"	       0       EXTMATCH
		assertMatchesFNMatch("ffo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0)
		// C		"foooofo"		"*(f*(o))"	       0       EXTMATCH
		assertMatchesFNMatch("foooofo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0)
		// C		"foooofof"		"*(f*(o))"	       0       EXTMATCH
		assertMatchesFNMatch("foooofof", pattern: "*(f*(o))", flags: EXTMATCH, result: 0)
		// C		"fooofoofofooo"		"*(f*(o))"	       0       EXTMATCH
		assertMatchesFNMatch("fooofoofofooo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0)
		// C		"foooofof"		"*(f+(o))"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("foooofof", pattern: "*(f+(o))", flags: EXTMATCH, result: NOMATCH)
		// C		"xfoooofof"		"*(f*(o))"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("xfoooofof", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH)
		// C		"foooofofx"		"*(f*(o))"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("foooofofx", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH)
		// C		"ofxoofxo"		"*(*(of*(o)x)o)"       0       EXTMATCH
		assertMatchesFNMatch("ofxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
		// C		"ofooofoofofooo"	"*(f*(o))"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("ofooofoofofooo", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH)
		// C		"foooxfooxfoxfooox"	"*(f*(o)x)"	       0       EXTMATCH
		assertMatchesFNMatch("foooxfooxfoxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: 0)
		// C		"foooxfooxofoxfooox"	"*(f*(o)x)"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("foooxfooxofoxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: NOMATCH)
		// C		"foooxfooxfxfooox"	"*(f*(o)x)"	       0       EXTMATCH
		assertMatchesFNMatch("foooxfooxfxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: 0)
		// C		"ofxoofxo"		"*(*(of*(o)x)o)"       0       EXTMATCH
		assertMatchesFNMatch("ofxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
		// C		"ofoooxoofxo"		"*(*(of*(o)x)o)"       0       EXTMATCH
		assertMatchesFNMatch("ofoooxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
		// C		"ofoooxoofxoofoooxoofxo" "*(*(of*(o)x)o)"      0       EXTMATCH
		assertMatchesFNMatch("ofoooxoofxoofoooxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
		// C		"ofoooxoofxoofoooxoofxoo" "*(*(of*(o)x)o)"     0       EXTMATCH
		assertMatchesFNMatch("ofoooxoofxoofoooxoofxoo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
		// C		"ofoooxoofxoofoooxoofxofo" "*(*(of*(o)x)o)"    NOMATCH EXTMATCH
		assertMatchesFNMatch("ofoooxoofxoofoooxoofxofo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: NOMATCH)
		// C		"ofoooxoofxoofoooxoofxooofxofxo" "*(*(of*(o)x)o)" 0    EXTMATCH
		assertMatchesFNMatch("ofoooxoofxoofoooxoofxooofxofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0)
		// C		"aac"			"*(@(a))a@(c)"	       0       EXTMATCH
		assertMatchesFNMatch("aac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0)
		// C		"ac"			"*(@(a))a@(c)"	       0       EXTMATCH
		assertMatchesFNMatch("ac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0)
		// C		"c"			"*(@(a))a@(c)"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("c", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: NOMATCH)
		// C		"aaac"			"*(@(a))a@(c)"	       0       EXTMATCH
		assertMatchesFNMatch("aaac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0)
		// C		"baaac"			"*(@(a))a@(c)"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("baaac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: NOMATCH)
		// C		"abcd"			"?@(a|b)*@(c)d"	       0       EXTMATCH
		assertMatchesFNMatch("abcd", pattern: "?@(a|b)*@(c)d", flags: EXTMATCH, result: 0)
		// C		"abcd"			"@(ab|a*@(b))*(c)d"    0       EXTMATCH
		assertMatchesFNMatch("abcd", pattern: "@(ab|a*@(b))*(c)d", flags: EXTMATCH, result: 0)
		// C		"acd"			"@(ab|a*(b))*(c)d"     0       EXTMATCH
		assertMatchesFNMatch("acd", pattern: "@(ab|a*(b))*(c)d", flags: EXTMATCH, result: 0)
		// C		"abbcd"			"@(ab|a*(b))*(c)d"     0       EXTMATCH
		assertMatchesFNMatch("abbcd", pattern: "@(ab|a*(b))*(c)d", flags: EXTMATCH, result: 0)
		// C		"effgz"			"@(b+(c)d|e*(f)g?|?(h)i@(j|k))" 0 EXTMATCH
		assertMatchesFNMatch("effgz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0)
		// C		"efgz"			"@(b+(c)d|e*(f)g?|?(h)i@(j|k))" 0 EXTMATCH
		assertMatchesFNMatch("efgz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0)
		// C		"egz"			"@(b+(c)d|e*(f)g?|?(h)i@(j|k))" 0 EXTMATCH
		assertMatchesFNMatch("egz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0)
		// C		"egzefffgzbcdij"	"*(b+(c)d|e*(f)g?|?(h)i@(j|k))" 0 EXTMATCH
		assertMatchesFNMatch("egzefffgzbcdij", pattern: "*(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0)
		// C		"egz"			"@(b+(c)d|e+(f)g?|?(h)i@(j|k))" NOMATCH EXTMATCH
		assertMatchesFNMatch("egz", pattern: "@(b+(c)d|e+(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: NOMATCH)
		// C		"ofoofo"		"*(of+(o))"	       0       EXTMATCH
		withKnownIssue {
			assertMatchesFNMatch("ofoofo", pattern: "*(of+(o))", flags: EXTMATCH, result: 0)
		}
		// C		"oxfoxoxfox"		"*(oxf+(ox))"	       0       EXTMATCH
		withKnownIssue {
			assertMatchesFNMatch("oxfoxoxfox", pattern: "*(oxf+(ox))", flags: EXTMATCH, result: 0)
		}
		// C		"oxfoxfox"		"*(oxf+(ox))"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("oxfoxfox", pattern: "*(oxf+(ox))", flags: EXTMATCH, result: NOMATCH)
		withKnownIssue {
			// C		"ofoofo"		"*(of+(o)|f)"	       0       EXTMATCH
			assertMatchesFNMatch("ofoofo", pattern: "*(of+(o)|f)", flags: EXTMATCH, result: 0)
			// C		"foofoofo"		"@(foo|f|fo)*(f|of+(o))" 0     EXTMATCH
			assertMatchesFNMatch("foofoofo", pattern: "@(foo|f|fo)*(f|of+(o))", flags: EXTMATCH, result: 0)
			// C		"oofooofo"		"*(of|oof+(o))"	       0       EXTMATCH
			assertMatchesFNMatch("oofooofo", pattern: "*(of|oof+(o))", flags: EXTMATCH, result: 0)
		}
		// C		"fffooofoooooffoofffooofff" "*(*(f)*(o))"      0       EXTMATCH
		assertMatchesFNMatch("fffooofoooooffoofffooofff", pattern: "*(*(f)*(o))", flags: EXTMATCH, result: 0)
		// C		"fofoofoofofoo"		"*(fo|foo)"	       0       EXTMATCH
		assertMatchesFNMatch("fofoofoofofoo", pattern: "*(fo|foo)", flags: EXTMATCH, result: 0)
		// C		"foo"			"!(x)"		       0       EXTMATCH
		assertMatchesFNMatch("foo", pattern: "!(x)", flags: EXTMATCH, result: 0)
		// C		"foo"			"!(x)*"		       0       EXTMATCH
		assertMatchesFNMatch("foo", pattern: "!(x)*", flags: EXTMATCH, result: 0)
		// C		"foo"			"!(foo)"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("foo", pattern: "!(foo)", flags: EXTMATCH, result: NOMATCH)
		// C		"foo"			"!(foo)*"	       0       EXTMATCH
		assertMatchesFNMatch("foo", pattern: "!(foo)*", flags: EXTMATCH, result: 0)
		// C		"foobar"		"!(foo)"	       0       EXTMATCH
		assertMatchesFNMatch("foobar", pattern: "!(foo)", flags: EXTMATCH, result: 0)
		// C		"foobar"		"!(foo)*"	       0       EXTMATCH
		assertMatchesFNMatch("foobar", pattern: "!(foo)*", flags: EXTMATCH, result: 0)
		// C		"moo.cow"		"!(*.*).!(*.*)"	       0       EXTMATCH
		assertMatchesFNMatch("moo.cow", pattern: "!(*.*).!(*.*)", flags: EXTMATCH, result: 0)
		// C		"mad.moo.cow"		"!(*.*).!(*.*)"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("mad.moo.cow", pattern: "!(*.*).!(*.*)", flags: EXTMATCH, result: NOMATCH)
		// C		"mucca.pazza"		"mu!(*(c))?.pa!(*(z))?" NOMATCH EXTMATCH
		assertMatchesFNMatch("mucca.pazza", pattern: "mu!(*(c))?.pa!(*(z))?", flags: EXTMATCH, result: NOMATCH)
		// C		"fff"			"!(f)"		       0       EXTMATCH
		assertMatchesFNMatch("fff", pattern: "!(f)", flags: EXTMATCH, result: 0)
		// C		"fff"			"*(!(f))"	       0       EXTMATCH
		assertMatchesFNMatch("fff", pattern: "*(!(f))", flags: EXTMATCH, result: 0)
		// C		"fff"			"+(!(f))"	       0       EXTMATCH
		assertMatchesFNMatch("fff", pattern: "+(!(f))", flags: EXTMATCH, result: 0)
		// C		"ooo"			"!(f)"		       0       EXTMATCH
		assertMatchesFNMatch("ooo", pattern: "!(f)", flags: EXTMATCH, result: 0)
		// C		"ooo"			"*(!(f))"	       0       EXTMATCH
		assertMatchesFNMatch("ooo", pattern: "*(!(f))", flags: EXTMATCH, result: 0)
		// C		"ooo"			"+(!(f))"	       0       EXTMATCH
		assertMatchesFNMatch("ooo", pattern: "+(!(f))", flags: EXTMATCH, result: 0)
		// C		"foo"			"!(f)"		       0       EXTMATCH
		assertMatchesFNMatch("foo", pattern: "!(f)", flags: EXTMATCH, result: 0)
		// C		"foo"			"*(!(f))"	       0       EXTMATCH
		assertMatchesFNMatch("foo", pattern: "*(!(f))", flags: EXTMATCH, result: 0)
		// C		"foo"			"+(!(f))"	       0       EXTMATCH
		assertMatchesFNMatch("foo", pattern: "+(!(f))", flags: EXTMATCH, result: 0)
		// C		"f"			"!(f)"		       NOMATCH EXTMATCH
		assertMatchesFNMatch("f", pattern: "!(f)", flags: EXTMATCH, result: NOMATCH)
		// C		"f"			"*(!(f))"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("f", pattern: "*(!(f))", flags: EXTMATCH, result: NOMATCH)
		// C		"f"			"+(!(f))"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("f", pattern: "+(!(f))", flags: EXTMATCH, result: NOMATCH)
		// C		"foot"			"@(!(z*)|*x)"	       0       EXTMATCH
		assertMatchesFNMatch("foot", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0)
		// C		"zoot"			"@(!(z*)|*x)"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("zoot", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: NOMATCH)
		// C		"foox"			"@(!(z*)|*x)"	       0       EXTMATCH
		assertMatchesFNMatch("foox", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0)
		// C		"zoox"			"@(!(z*)|*x)"	       0       EXTMATCH
		assertMatchesFNMatch("zoox", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0)
		// C		"foo"			"*(!(foo))"	       0       EXTMATCH
		assertMatchesFNMatch("foo", pattern: "*(!(foo))", flags: EXTMATCH, result: 0)
		// C		"foob"			"!(foo)b*"	       NOMATCH EXTMATCH
		assertMatchesFNMatch("foob", pattern: "!(foo)b*", flags: EXTMATCH, result: NOMATCH)
		// C		"foobb"			"!(foo)b*"	       0       EXTMATCH
		assertMatchesFNMatch("foobb", pattern: "!(foo)b*", flags: EXTMATCH, result: 0)
		// C		"["			"*([a[])"	       0       EXTMATCH
		assertMatchesFNMatch("[", pattern: "*([a[])", flags: EXTMATCH, result: 0)
		// C		"]"			"*([]a[])"	       0       EXTMATCH
		assertMatchesFNMatch("]", pattern: "*([]a[])", flags: EXTMATCH, result: 0)
		// C		"a"			"*([]a[])"	       0       EXTMATCH
		assertMatchesFNMatch("a", pattern: "*([]a[])", flags: EXTMATCH, result: 0)
		// C		"b"			"*([!]a[])"	       0       EXTMATCH
		assertMatchesFNMatch("b", pattern: "*([!]a[])", flags: EXTMATCH, result: 0)
		// C		"["			"*([!]a[]|[[])"	       0       EXTMATCH
		assertMatchesFNMatch("[", pattern: "*([!]a[]|[[])", flags: EXTMATCH, result: 0)
		// C		"]"			"*([!]a[]|[]])"	       0       EXTMATCH
		assertMatchesFNMatch("]", pattern: "*([!]a[]|[]])", flags: EXTMATCH, result: 0)
		// C		"["			"!([!]a[])"	       0       EXTMATCH
		assertMatchesFNMatch("[", pattern: "!([!]a[])", flags: EXTMATCH, result: 0)
		// C		"]"			"!([!]a[])"	       0       EXTMATCH
		assertMatchesFNMatch("]", pattern: "!([!]a[])", flags: EXTMATCH, result: 0)
		// C		")"			"*([)])"	       0       EXTMATCH
		assertMatchesFNMatch(")", pattern: "*([)])", flags: EXTMATCH, result: 0)
		// C		"*"			"*([*(])"	       0       EXTMATCH
		assertMatchesFNMatch("*", pattern: "*([*(])", flags: EXTMATCH, result: 0)
		// C		"abcd"			"*!(|a)cd"	       0       EXTMATCH
		assertMatchesFNMatch("abcd", pattern: "*!(|a)cd", flags: EXTMATCH, result: 0)
		// C		"ab/.a"			"+([abc])/*"	       NOMATCH EXTMATCH|PATHNAME|PERIOD
		assertMatchesFNMatch("ab/.a", pattern: "+([abc])/*", flags: EXTMATCH | PATHNAME | PERIOD, result: NOMATCH)
		// C		""			""		       0
		assertMatchesFNMatch("", pattern: "", flags: 0, result: 0)
		// C		""			""		       0       EXTMATCH
		assertMatchesFNMatch("", pattern: "", flags: EXTMATCH, result: 0)
		// C		""			"*([abc])"	       0       EXTMATCH
		assertMatchesFNMatch("", pattern: "*([abc])", flags: EXTMATCH, result: 0)
		// C		""			"?([abc])"	       0       EXTMATCH
		assertMatchesFNMatch("", pattern: "?([abc])", flags: EXTMATCH, result: 0)
	}

	@Test func other() {
		assertMatchesFNMatch("abc2/", pattern: "*", flags: PATHNAME, result: NOMATCH)
		#expect(fnmatch("*", "abc2/", PATHNAME) == NOMATCH)
		assertMatchesFNMatch("abc2/", pattern: "*/", flags: PATHNAME, result: 0)
		#expect(fnmatch("*/", "abc2/", PATHNAME) == 0)
	}
}
