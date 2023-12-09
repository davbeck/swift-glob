import Darwin
import XCTest

@testable import Glob

private let PATHNAME = FNM_PATHNAME
private let PERIOD = FNM_PERIOD
private let NOESCAPE = FNM_NOESCAPE
private let NOMATCH = FNM_NOMATCH
private let LEADING_DIR = FNM_LEADING_DIR
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
		fnmatchResult,
		"matching '\(value)' to pattern '\(pattern)' with flags \(flags) did not match fnmatch result \(expectedResult)",
		file: file,
		line: line
	)
}

final class PatternFNMatchTests: XCTestCase {
	func test() throws {
		// Tests for fnmatch.
		// Copyright (C) 2000-2023 Free Software Foundation, Inc.
		// This file is part of the GNU C Library.
		// Contributes by Ulrich Drepper <drepper@redhat.com>.
		//

		// The GNU C Library is free software; you can redistribute it and/or
		// modify it under the terms of the GNU Lesser General Public
		// License as published by the Free Software Foundation; either
		// version 2.1 of the License, or (at your option) any later version.

		// The GNU C Library is distributed in the hope that it will be useful,
		// but WITHOUT ANY WARRANTY; without even the implied warranty of
		// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
		// Lesser General Public License for more details.

		// You should have received a copy of the GNU Lesser General Public
		// License along with the GNU C Library; if not, see
		// <https://www.gnu.org/licenses/>.

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

		// B.6 004(C)
		XCTAssertMatchesFNMatch("!#%+,-./01234567889", pattern: "!#%+,-./01234567889", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch(":;=@ABCDEFGHIJKLMNO", pattern: ":;=@ABCDEFGHIJKLMNO", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("PQRSTUVWXYZ]abcdefg", pattern: "PQRSTUVWXYZ]abcdefg", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("hijklmnopqrstuvwxyz", pattern: "hijklmnopqrstuvwxyz", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("^_{}~", pattern: "^_{}~", flags: 0, result: 0) // C

		// B.6 005(C)
		XCTAssertMatchesFNMatch("\"$&'()", pattern: "\\\"\\$\\&\\'\\(\\)", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("*?[\\`|", pattern: "\\*\\?\\[\\\\\\`\\|", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("<>", pattern: "\\<\\>", flags: 0, result: 0) // C

		// B.6 006(C)
		XCTAssertMatchesFNMatch("?*[", pattern: "[?*[][?*[][?*[]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a/b", pattern: "?/b", flags: 0, result: 0) // C

		// B.6 007(C)
		XCTAssertMatchesFNMatch("a/b", pattern: "a?b", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a/b", pattern: "a/?", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("aa/b", pattern: "?/b", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("aa/b", pattern: "a?b", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a/bb", pattern: "a/?", flags: 0, result: NOMATCH) // C

		// B.6 009(C)
		XCTAssertMatchesFNMatch("abc", pattern: "[abc]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("x", pattern: "[abc]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[abc]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("[", pattern: "[[abc]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[][abc]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a]", pattern: "[]a]]", flags: 0, result: 0) // C

		// B.6 010(C)
		XCTAssertMatchesFNMatch("xyz", pattern: "[!abc]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("x", pattern: "[!abc]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[!abc]", flags: 0, result: NOMATCH) // C

		// B.6 011(C)
		XCTAssertMatchesFNMatch("]", pattern: "[][abc]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("abc]", pattern: "[][abc]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("[]abc", pattern: "[][]abc", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("]", pattern: "[!]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("aa]", pattern: "[!]a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("]", pattern: "[!a]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("]]", pattern: "[!a]]", flags: 0, result: 0) // C

		// B.6 012(C)
		XCTAssertMatchesFNMatch("a", pattern: "[[.a.]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[[.-.]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[[.-.][.].]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[[.].][.-.]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[[.-.][=u=]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[[.-.][:alpha:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[![.a.]]", flags: 0, result: NOMATCH) // C

		// B.6 013(C)
		XCTAssertMatchesFNMatch("a", pattern: "[[.b.]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[.b.][.c.]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[.b.][=b=]]", flags: 0, result: NOMATCH) // C

		// B.6 015(C)
		XCTAssertMatchesFNMatch("a", pattern: "[[=a=]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("b", pattern: "[[=a=][=b=]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[=a=][=b=]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[=a=][.b.]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[=a=][:digit:]]", flags: 0, result: 0) // C

		// B.6 016(C)
		XCTAssertMatchesFNMatch("=", pattern: "[[=a=]b]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("]", pattern: "[[=a=]b]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][=c=]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][.].]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][:digit:]]", flags: 0, result: NOMATCH) // C

		// B.6 017(C)
		XCTAssertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[![:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a]a", pattern: "[[:alnum:]]a", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]-]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("aa", pattern: "[[:alnum:]]a", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[![:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("]", pattern: "[!][:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("[", pattern: "[![:alnum:][]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("b", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("c", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("d", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("e", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("f", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("g", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("h", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("i", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("j", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("k", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("l", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("m", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("n", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("o", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("p", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("q", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("r", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("s", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("u", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("v", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("w", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("x", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("y", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("z", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("A", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("B", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("C", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("D", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("E", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("F", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("G", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("H", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("I", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("J", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("K", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("L", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("M", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("N", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("O", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("P", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("Q", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("R", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("S", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("T", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("U", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("V", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("W", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("X", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("Y", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("Z", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("0", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("1", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("2", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("3", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("4", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("5", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("6", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("7", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("8", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("9", pattern: "[[:alnum:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("!", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("#", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("%", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("+", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch(",", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch(".", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch(":", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch(";", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("=", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("@", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("[", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("\\", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("]", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("^", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("_", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("{", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("}", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("~", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("\"", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("$", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("&", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("'", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("(", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch(")", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("*", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("?", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("`", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("|", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("<", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch(">", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("\t", pattern: "[[:cntrl:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:cntrl:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:lower:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("\t", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("T", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("\t", pattern: "[[:space:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:space:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:alpha:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("\t", pattern: "[[:alpha:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("0", pattern: "[[:digit:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("\t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("\t", pattern: "[[:print:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:print:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("T", pattern: "[[:upper:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("\t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("\t", pattern: "[[:blank:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:blank:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("\t", pattern: "[[:graph:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:graph:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch(".", pattern: "[[:punct:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("\t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("0", pattern: "[[:xdigit:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("\t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[:xdigit:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("A", pattern: "[[:xdigit:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[alpha]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[alpha:]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a]", pattern: "[[alpha]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a]", pattern: "[[alpha:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][.b.]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][=b=]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][:digit:]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[:digit:][:alpha:]]", flags: 0, result: 0) // C

		// B.6 018(C)
		XCTAssertMatchesFNMatch("a", pattern: "[a-c]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("b", pattern: "[a-c]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("c", pattern: "[a-c]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[b-c]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("d", pattern: "[b-c]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("B", pattern: "[a-c]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("b", pattern: "[A-C]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("", pattern: "[a-c]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("as", pattern: "[a-ca-z]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[.a.]-c]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[a-[.c.]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("b", pattern: "[[.a.]-c]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("b", pattern: "[a-[.c.]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("b", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("c", pattern: "[[.a.]-c]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("c", pattern: "[a-[.c.]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("c", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("d", pattern: "[[.a.]-c]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("d", pattern: "[a-[.c.]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("d", pattern: "[[.a.]-[.c.]]", flags: 0, result: NOMATCH) // C

		// B.6 019(C)
		XCTAssertMatchesFNMatch("a", pattern: "[c-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("c", pattern: "[c-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("c", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("c", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("c", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH) // C

		// B.6 020(C)
		XCTAssertMatchesFNMatch("a", pattern: "[a-c0-9]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("d", pattern: "[a-c0-9]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("B", pattern: "[a-c0-9]", flags: 0, result: NOMATCH) // C

		// B.6 021(C)
		XCTAssertMatchesFNMatch("-", pattern: "[-a]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[-b]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("-", pattern: "[!-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[!-b]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[a-c-0-9]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("b", pattern: "[a-c-0-9]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a:", pattern: "a[0-9-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a:", pattern: "a[09-a]", flags: 0, result: 0) // C

		// B.6 024(C)
		XCTAssertMatchesFNMatch("", pattern: "*", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("asd/sdf", pattern: "*", flags: 0, result: 0) // C

		// B.6 025(C)
		XCTAssertMatchesFNMatch("as", pattern: "[a-c][a-z]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("as", pattern: "??", flags: 0, result: 0) // C

		// B.6 026(C)
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*df", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("asd/sdf", pattern: "*df", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*dg", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("asdf", pattern: "as*df", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("asdf", pattern: "as*df?", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("asdf", pattern: "as*??", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("asdf", pattern: "a*???", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("asdf", pattern: "*????", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("asdf", pattern: "????*", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("asdf", pattern: "??*?", flags: 0, result: 0) // C

		// B.6 027(C)
		XCTAssertMatchesFNMatch("/", pattern: "/", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("/", pattern: "/*", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("/", pattern: "*/", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("/", pattern: "/?", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/", pattern: "?/", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/", pattern: "?", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch(".", pattern: "?", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("/.", pattern: "??", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("/", pattern: "[!a-c]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch(".", pattern: "[!a-c]", flags: 0, result: 0) // C

		// B.6 029(C)
		XCTAssertMatchesFNMatch("/", pattern: "/", flags: PATHNAME, result: 0) // C

		XCTAssertMatchesFNMatch("//", pattern: "//", flags: PATHNAME, result: 0) // C

		XCTAssertMatchesFNMatch("/.a", pattern: "/*", flags: PATHNAME, result: 0) // C

		XCTAssertMatchesFNMatch("/.a", pattern: "/?a", flags: PATHNAME, result: 0) // C

		XCTAssertMatchesFNMatch("/.a", pattern: "/[!a-z]a", flags: PATHNAME, result: 0) // C

		XCTAssertMatchesFNMatch("/.a/.b", pattern: "/*/?b", flags: PATHNAME, result: 0) // C

		// B.6 030(C)
		XCTAssertMatchesFNMatch("/", pattern: "?", flags: PATHNAME, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/", pattern: "*", flags: PATHNAME, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a/b", pattern: "a?b", flags: PATHNAME, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/.a/.b", pattern: "/*b", flags: PATHNAME, result: NOMATCH) // C

		// B.6 031(C)
		XCTAssertMatchesFNMatch("/$", pattern: "\\/\\$", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("/[", pattern: "\\/\\[", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("/[", pattern: "\\/[", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("/[]", pattern: "\\/\\[]", flags: 0, result: 0) // C

		// B.6 032(C)
		XCTAssertMatchesFNMatch("/$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("\\/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: 0) // C

		// B.6 033(C)
		XCTAssertMatchesFNMatch(".asd", pattern: ".*", flags: PERIOD, result: 0) // C

		XCTAssertMatchesFNMatch("/.asd", pattern: "*", flags: PERIOD, result: 0) // C

		XCTAssertMatchesFNMatch("/as/.df", pattern: "*/?*f", flags: PERIOD, result: 0) // C

		XCTAssertMatchesFNMatch("..asd", pattern: ".[!a-z]*", flags: PERIOD, result: 0) // C

		// B.6 034(C)
		XCTAssertMatchesFNMatch(".asd", pattern: "*", flags: PERIOD, result: NOMATCH) // C

		XCTAssertMatchesFNMatch(".asd", pattern: "?asd", flags: PERIOD, result: NOMATCH) // C

		XCTAssertMatchesFNMatch(".asd", pattern: "[!a-z]*", flags: PERIOD, result: NOMATCH) // C

		// B.6 035(C)
		XCTAssertMatchesFNMatch("/.", pattern: "/.", flags: PATHNAME | PERIOD, result: 0) // C

		XCTAssertMatchesFNMatch("/.a./.b.", pattern: "/.*/.*", flags: PATHNAME | PERIOD, result: 0) // C

		XCTAssertMatchesFNMatch("/.a./.b.", pattern: "/.??/.??", flags: PATHNAME | PERIOD, result: 0) // C

		// B.6 036(C)
		XCTAssertMatchesFNMatch("/.", pattern: "*", flags: PATHNAME | PERIOD, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/.", pattern: "/*", flags: PATHNAME | PERIOD, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/.", pattern: "/?", flags: PATHNAME | PERIOD, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/.", pattern: "/[!a-z]", flags: PATHNAME | PERIOD, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/a./.b.", pattern: "/*/*", flags: PATHNAME | PERIOD, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/a./.b.", pattern: "/??/???", flags: PATHNAME | PERIOD, result: NOMATCH) // C

		// Some home-grown tests.
		XCTAssertMatchesFNMatch("foobar", pattern: "foo*[abc]z", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("foobaz", pattern: "foo*[abc][xyz]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc][xyz]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc][x/yz]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc]/[xyz]", flags: PATHNAME, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "a/", flags: PATHNAME, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a/", pattern: "a", flags: PATHNAME, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("//a", pattern: "/a", flags: PATHNAME, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("/a", pattern: "//a", flags: PATHNAME, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("az", pattern: "[a-]z", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("bz", pattern: "[ab-]z", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("cz", pattern: "[ab-]z", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("-z", pattern: "[ab-]z", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("az", pattern: "[-a]z", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("bz", pattern: "[-ab]z", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("cz", pattern: "[-ab]z", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("-z", pattern: "[-ab]z", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("\\", pattern: "[\\\\-a]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("_", pattern: "[\\\\-a]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[\\\\-a]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[\\\\-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("\\", pattern: "[\\]-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("_", pattern: "[\\]-a]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "[\\]-a]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("]", pattern: "[\\]-a]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[\\]-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("\\", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("_", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("a", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("-", pattern: "[!\\\\-a]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("!", pattern: "[\\!-]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[\\!-]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("\\", pattern: "[\\!-]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("Z", pattern: "[Z-\\\\]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("[", pattern: "[Z-\\\\]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("\\", pattern: "[Z-\\\\]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[Z-\\\\]", flags: 0, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("Z", pattern: "[Z-\\]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("[", pattern: "[Z-\\]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("\\", pattern: "[Z-\\]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("]", pattern: "[Z-\\]]", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("-", pattern: "[Z-\\]]", flags: 0, result: NOMATCH) // C

		// B.6 004(C)
		XCTAssertMatchesFNMatch("!#%+,-./01234567889", pattern: "!#%+,-./01234567889", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch(":;=@ABCDEFGHIJKLMNO", pattern: ":;=@ABCDEFGHIJKLMNO", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("PQRSTUVWXYZ]abcdefg", pattern: "PQRSTUVWXYZ]abcdefg", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("hijklmnopqrstuvwxyz", pattern: "hijklmnopqrstuvwxyz", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("^_{}~", pattern: "^_{}~", flags: 0, result: 0) // C.UTF-8

		// B.6 005(C)
		XCTAssertMatchesFNMatch("\"$&'()", pattern: "\\\"\\$\\&\\'\\(\\)", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("*?[\\`|", pattern: "\\*\\?\\[\\\\\\`\\|", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("<>", pattern: "\\<\\>", flags: 0, result: 0) // C.UTF-8

		// B.6 006(C)
		XCTAssertMatchesFNMatch("?*[", pattern: "[?*[][?*[][?*[]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a/b", pattern: "?/b", flags: 0, result: 0) // C.UTF-8

		// B.6 007(C)
		XCTAssertMatchesFNMatch("a/b", pattern: "a?b", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a/b", pattern: "a/?", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("aa/b", pattern: "?/b", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("aa/b", pattern: "a?b", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a/bb", pattern: "a/?", flags: 0, result: NOMATCH) // C.UTF-8

		// B.6 009(C)
		XCTAssertMatchesFNMatch("abc", pattern: "[abc]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("x", pattern: "[abc]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[abc]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("[", pattern: "[[abc]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[][abc]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a]", pattern: "[]a]]", flags: 0, result: 0) // C.UTF-8

		// B.6 010(C)
		XCTAssertMatchesFNMatch("xyz", pattern: "[!abc]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("x", pattern: "[!abc]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[!abc]", flags: 0, result: NOMATCH) // C.UTF-8

		// B.6 011(C)
		XCTAssertMatchesFNMatch("]", pattern: "[][abc]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("abc]", pattern: "[][abc]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("[]abc", pattern: "[][]abc", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("]", pattern: "[!]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("aa]", pattern: "[!]a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("]", pattern: "[!a]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("]]", pattern: "[!a]]", flags: 0, result: 0) // C.UTF-8

		// B.6 012(C)
		XCTAssertMatchesFNMatch("a", pattern: "[[.a.]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[[.-.]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[[.-.][.].]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[[.].][.-.]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[[.-.][=u=]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[[.-.][:alpha:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[![.a.]]", flags: 0, result: NOMATCH) // C.UTF-8

		// B.6 013(C)
		XCTAssertMatchesFNMatch("a", pattern: "[[.b.]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[.b.][.c.]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[.b.][=b=]]", flags: 0, result: NOMATCH) // C.UTF-8

		// B.6 015(C)
		XCTAssertMatchesFNMatch("a", pattern: "[[=a=]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[[=a=][=b=]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[=a=][=b=]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[=a=][.b.]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[=a=][:digit:]]", flags: 0, result: 0) // C.UTF-8

		// B.6 016(C)
		XCTAssertMatchesFNMatch("=", pattern: "[[=a=]b]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("]", pattern: "[[=a=]b]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][=c=]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][.].]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[=b=][:digit:]]", flags: 0, result: NOMATCH) // C.UTF-8

		// B.6 017(C)
		XCTAssertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[![:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a]a", pattern: "[[:alnum:]]a", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]-]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("aa", pattern: "[[:alnum:]]a", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[![:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("]", pattern: "[!][:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("[", pattern: "[![:alnum:][]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("d", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("e", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("f", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("g", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("h", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("i", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("j", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("k", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("l", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("m", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("n", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("o", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("p", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("q", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("r", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("s", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("u", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("v", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("w", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("y", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("z", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("A", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("B", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("C", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("D", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("E", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("F", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("G", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("H", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("I", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("J", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("K", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("L", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("M", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("N", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("O", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("P", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("Q", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("R", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("S", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("T", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("U", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("V", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("W", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("X", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("Y", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("Z", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("0", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("1", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("2", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("3", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("4", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("5", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("6", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("7", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("8", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("9", pattern: "[[:alnum:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("!", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("#", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("%", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("+", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch(",", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch(".", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch(":", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch(";", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("=", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("@", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("[", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("\\", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("]", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("^", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("_", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("{", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("}", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("~", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("\"", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("$", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("&", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("'", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("(", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch(")", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("*", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("?", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("`", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("|", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("<", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch(">", pattern: "[[:alnum:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("\t", pattern: "[[:cntrl:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:cntrl:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:lower:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("\t", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("T", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("\t", pattern: "[[:space:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:space:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:alpha:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("\t", pattern: "[[:alpha:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("0", pattern: "[[:digit:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("\t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:digit:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("\t", pattern: "[[:print:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:print:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("T", pattern: "[[:upper:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("\t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("\t", pattern: "[[:blank:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:blank:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("\t", pattern: "[[:graph:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:graph:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch(".", pattern: "[[:punct:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("\t", pattern: "[[:punct:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("0", pattern: "[[:xdigit:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("\t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[:xdigit:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("A", pattern: "[[:xdigit:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("t", pattern: "[[:xdigit:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[alpha]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[alpha:]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a]", pattern: "[[alpha]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a]", pattern: "[[alpha:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][.b.]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][=b=]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:][:digit:]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[:digit:][:alpha:]]", flags: 0, result: 0) // C.UTF-8

		// B.6 018(C)
		XCTAssertMatchesFNMatch("a", pattern: "[a-c]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[a-c]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[a-c]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[b-c]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("d", pattern: "[b-c]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("B", pattern: "[a-c]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[A-C]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("", pattern: "[a-c]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("as", pattern: "[a-ca-z]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[.a.]-c]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[a-[.c.]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[[.a.]-c]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[a-[.c.]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[[.a.]-c]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[a-[.c.]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[[.a.]-[.c.]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("d", pattern: "[[.a.]-c]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("d", pattern: "[a-[.c.]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("d", pattern: "[[.a.]-[.c.]]", flags: 0, result: NOMATCH) // C.UTF-8

		// B.6 019(C)
		XCTAssertMatchesFNMatch("a", pattern: "[c-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[c-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[[.c.]-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[c-[.a.]]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[[.c.]-[.a.]]", flags: 0, result: NOMATCH) // C.UTF-8

		// B.6 020(C)
		XCTAssertMatchesFNMatch("a", pattern: "[a-c0-9]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("d", pattern: "[a-c0-9]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("B", pattern: "[a-c0-9]", flags: 0, result: NOMATCH) // C.UTF-8

		// B.6 021(C)
		XCTAssertMatchesFNMatch("-", pattern: "[-a]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[-b]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[!-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[!-b]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[a-c-0-9]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[a-c-0-9]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a:", pattern: "a[0-9-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a:", pattern: "a[09-a]", flags: 0, result: 0) // C.UTF-8

		// B.6 024(C)
		XCTAssertMatchesFNMatch("", pattern: "*", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("asd/sdf", pattern: "*", flags: 0, result: 0) // C.UTF-8

		// B.6 025(C)
		XCTAssertMatchesFNMatch("as", pattern: "[a-c][a-z]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("as", pattern: "??", flags: 0, result: 0) // C.UTF-8

		// B.6 026(C)
		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*df", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("asd/sdf", pattern: "*df", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("asd/sdf", pattern: "as*dg", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("asdf", pattern: "as*df", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("asdf", pattern: "as*df?", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("asdf", pattern: "as*??", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("asdf", pattern: "a*???", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("asdf", pattern: "*????", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("asdf", pattern: "????*", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("asdf", pattern: "??*?", flags: 0, result: 0) // C.UTF-8

		// B.6 027(C)
		XCTAssertMatchesFNMatch("/", pattern: "/", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/", pattern: "/*", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/", pattern: "*/", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/", pattern: "/?", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/", pattern: "?/", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/", pattern: "?", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch(".", pattern: "?", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/.", pattern: "??", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/", pattern: "[!a-c]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch(".", pattern: "[!a-c]", flags: 0, result: 0) // C.UTF-8

		// B.6 029(C)
		XCTAssertMatchesFNMatch("/", pattern: "/", flags: PATHNAME, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("//", pattern: "//", flags: PATHNAME, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/.a", pattern: "/*", flags: PATHNAME, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/.a", pattern: "/?a", flags: PATHNAME, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/.a", pattern: "/[!a-z]a", flags: PATHNAME, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/.a/.b", pattern: "/*/?b", flags: PATHNAME, result: 0) // C.UTF-8

		// B.6 030(C)
		XCTAssertMatchesFNMatch("/", pattern: "?", flags: PATHNAME, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/", pattern: "*", flags: PATHNAME, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a/b", pattern: "a?b", flags: PATHNAME, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/.a/.b", pattern: "/*b", flags: PATHNAME, result: NOMATCH) // C.UTF-8

		// B.6 031(C)
		XCTAssertMatchesFNMatch("/$", pattern: "\\/\\$", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/[", pattern: "\\/\\[", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/[", pattern: "\\/[", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/[]", pattern: "\\/\\[]", flags: 0, result: 0) // C.UTF-8

		// B.6 032(C)
		XCTAssertMatchesFNMatch("/$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("\\/\\$", pattern: "\\/\\$", flags: NOESCAPE, result: 0) // C.UTF-8

		// B.6 033(C)
		XCTAssertMatchesFNMatch(".asd", pattern: ".*", flags: PERIOD, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/.asd", pattern: "*", flags: PERIOD, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/as/.df", pattern: "*/?*f", flags: PERIOD, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("..asd", pattern: ".[!a-z]*", flags: PERIOD, result: 0) // C.UTF-8

		// B.6 034(C)
		XCTAssertMatchesFNMatch(".asd", pattern: "*", flags: PERIOD, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch(".asd", pattern: "?asd", flags: PERIOD, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch(".asd", pattern: "[!a-z]*", flags: PERIOD, result: NOMATCH) // C.UTF-8

		// B.6 035(C)
		XCTAssertMatchesFNMatch("/.", pattern: "/.", flags: PATHNAME | PERIOD, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/.a./.b.", pattern: "/.*/.*", flags: PATHNAME | PERIOD, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/.a./.b.", pattern: "/.??/.??", flags: PATHNAME | PERIOD, result: 0) // C.UTF-8

		// B.6 036(C)
		XCTAssertMatchesFNMatch("/.", pattern: "*", flags: PATHNAME | PERIOD, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/.", pattern: "/*", flags: PATHNAME | PERIOD, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/.", pattern: "/?", flags: PATHNAME | PERIOD, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/.", pattern: "/[!a-z]", flags: PATHNAME | PERIOD, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/a./.b.", pattern: "/*/*", flags: PATHNAME | PERIOD, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/a./.b.", pattern: "/??/???", flags: PATHNAME | PERIOD, result: NOMATCH) // C.UTF-8

		// Some home-grown tests.
		XCTAssertMatchesFNMatch("foobar", pattern: "foo*[abc]z", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("foobaz", pattern: "foo*[abc][xyz]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc][xyz]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc][x/yz]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foobaz", pattern: "foo?*[abc]/[xyz]", flags: PATHNAME, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "a/", flags: PATHNAME, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a/", pattern: "a", flags: PATHNAME, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("//a", pattern: "/a", flags: PATHNAME, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("/a", pattern: "//a", flags: PATHNAME, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("az", pattern: "[a-]z", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("bz", pattern: "[ab-]z", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("cz", pattern: "[ab-]z", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("-z", pattern: "[ab-]z", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("az", pattern: "[-a]z", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("bz", pattern: "[-ab]z", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("cz", pattern: "[-ab]z", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("-z", pattern: "[-ab]z", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("\\", pattern: "[\\\\-a]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("_", pattern: "[\\\\-a]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[\\\\-a]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[\\\\-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("\\", pattern: "[\\]-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("_", pattern: "[\\]-a]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[\\]-a]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("]", pattern: "[\\]-a]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[\\]-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("\\", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("_", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[!\\\\-a]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[!\\\\-a]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("!", pattern: "[\\!-]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[\\!-]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("\\", pattern: "[\\!-]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("Z", pattern: "[Z-\\\\]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("[", pattern: "[Z-\\\\]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("\\", pattern: "[Z-\\\\]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[Z-\\\\]", flags: 0, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("Z", pattern: "[Z-\\]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("[", pattern: "[Z-\\]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("\\", pattern: "[Z-\\]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("]", pattern: "[Z-\\]]", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("-", pattern: "[Z-\\]]", flags: 0, result: NOMATCH) // C.UTF-8

		// Following are tests outside the scope of IEEE 2003.2 since they are using
		// locales other than the C locale.  The main focus of the tests is on the
		// handling of ranges and the recognition of character (vs bytes).
		XCTAssertMatchesFNMatch("a", pattern: "[a-z]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("z", pattern: "[a-z]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\344", pattern: "[a-z]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\366", pattern: "[a-z]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\374", pattern: "[a-z]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("A", pattern: "[a-z]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("Z", pattern: "[a-z]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\304", pattern: "[a-z]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\326", pattern: "[a-z]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\334", pattern: "[a-z]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("a", pattern: "[A-Z]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("z", pattern: "[A-Z]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\344", pattern: "[A-Z]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\366", pattern: "[A-Z]", flags: 0, result: NOMATCH)  de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\374", pattern: "[A-Z]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("A", pattern: "[A-Z]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("Z", pattern: "[A-Z]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\304", pattern: "[A-Z]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\326", pattern: "[A-Z]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\334", pattern: "[A-Z]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("a", pattern: "[[:lower:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("z", pattern: "[[:lower:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\344", pattern: "[[:lower:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\366", pattern: "[[:lower:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\374", pattern: "[[:lower:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("A", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("Z", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\304", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\326", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\334", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("a", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("z", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\344", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\366", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\374", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("A", pattern: "[[:upper:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("Z", pattern: "[[:upper:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\304", pattern: "[[:upper:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\326", pattern: "[[:upper:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\334", pattern: "[[:upper:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("z", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\344", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\366", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\374", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("A", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("Z", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\304", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\326", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\334", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("a", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\342", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\340", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\341", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\344", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("c", pattern: "[[=a=]b]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("a", pattern: "[[=\342=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\342", pattern: "[[=\342=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\340", pattern: "[[=\342=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\341", pattern: "[[=\342=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\344", pattern: "[[=\342=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("b", pattern: "[[=\342=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("c", pattern: "[[=\342=]b]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("a", pattern: "[[=\340=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\342", pattern: "[[=\340=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\340", pattern: "[[=\340=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\341", pattern: "[[=\340=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\344", pattern: "[[=\340=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("b", pattern: "[[=\340=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("c", pattern: "[[=\340=]b]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("a", pattern: "[[=\341=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\342", pattern: "[[=\341=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\340", pattern: "[[=\341=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\341", pattern: "[[=\341=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\344", pattern: "[[=\341=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("b", pattern: "[[=\341=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("c", pattern: "[[=\341=]b]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("a", pattern: "[[=\344=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\342", pattern: "[[=\344=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\340", pattern: "[[=\344=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\341", pattern: "[[=\344=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("\344", pattern: "[[=\344=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("b", pattern: "[[=\344=]b]", flags: 0, result: 0) // de_DE.ISO-8859-1

//		XCTAssertMatchesFNMatch("c", pattern: "[[=\344=]b]", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("aa", pattern: "[[.a.]]a", flags: 0, result: 0) // de_DE.ISO-8859-1

		XCTAssertMatchesFNMatch("ba", pattern: "[[.a.]]a", flags: 0, result: NOMATCH) // de_DE.ISO-8859-1

		// And with a multibyte character set.
		XCTAssertMatchesFNMatch("a", pattern: "[a-z]", flags: 0, result: 0) // en_US.UTF-8

		XCTAssertMatchesFNMatch("z", pattern: "[a-z]", flags: 0, result: 0) // en_US.UTF-8

		XCTAssertMatchesFNMatch("A", pattern: "[a-z]", flags: 0, result: NOMATCH) // en_US.UTF-8

		XCTAssertMatchesFNMatch("Z", pattern: "[a-z]", flags: 0, result: NOMATCH) // en_US.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[A-Z]", flags: 0, result: NOMATCH) // en_US.UTF-8

		XCTAssertMatchesFNMatch("z", pattern: "[A-Z]", flags: 0, result: NOMATCH) // en_US.UTF-8

		XCTAssertMatchesFNMatch("A", pattern: "[A-Z]", flags: 0, result: 0) // en_US.UTF-8

		XCTAssertMatchesFNMatch("Z", pattern: "[A-Z]", flags: 0, result: 0) // en_US.UTF-8

		XCTAssertMatchesFNMatch("0", pattern: "[0-9]", flags: 0, result: 0) // en_US.UTF-8

		XCTAssertMatchesFNMatch("9", pattern: "[0-9]", flags: 0, result: 0) // en_US.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[a-z]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("z", pattern: "[a-z]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ä", pattern: "[a-z]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ö", pattern: "[a-z]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ü", pattern: "[a-z]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("A", pattern: "[a-z]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Z", pattern: "[a-z]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ä", pattern: "[a-z]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ö", pattern: "[a-z]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ü", pattern: "[a-z]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[A-Z]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("z", pattern: "[A-Z]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ä", pattern: "[A-Z]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ö", pattern: "[A-Z]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ü", pattern: "[A-Z]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("A", pattern: "[A-Z]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Z", pattern: "[A-Z]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ä", pattern: "[A-Z]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ö", pattern: "[A-Z]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ü", pattern: "[A-Z]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[:lower:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("z", pattern: "[[:lower:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ä", pattern: "[[:lower:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ö", pattern: "[[:lower:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ü", pattern: "[[:lower:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("A", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Z", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ä", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ö", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ü", pattern: "[[:lower:]]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("z", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ä", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ö", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ü", pattern: "[[:upper:]]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("A", pattern: "[[:upper:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Z", pattern: "[[:upper:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ä", pattern: "[[:upper:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ö", pattern: "[[:upper:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ü", pattern: "[[:upper:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("z", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ä", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ö", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ü", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("A", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Z", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ä", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ö", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("Ü", pattern: "[[:alpha:]]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("â", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("à", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("á", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ä", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[[=a=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[[=a=]b]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[=â=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("â", pattern: "[[=â=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("à", pattern: "[[=â=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("á", pattern: "[[=â=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ä", pattern: "[[=â=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[[=â=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[[=â=]b]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[=à=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("â", pattern: "[[=à=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("à", pattern: "[[=à=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("á", pattern: "[[=à=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ä", pattern: "[[=à=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[[=à=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[[=à=]b]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[=á=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("â", pattern: "[[=á=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("à", pattern: "[[=á=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("á", pattern: "[[=á=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ä", pattern: "[[=á=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[[=á=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[[=á=]b]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "[[=ä=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("â", pattern: "[[=ä=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("à", pattern: "[[=ä=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("á", pattern: "[[=ä=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ä", pattern: "[[=ä=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "[[=ä=]b]", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "[[=ä=]b]", flags: 0, result: NOMATCH) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("aa", pattern: "[[.a.]]a", flags: 0, result: 0) // de_DE.UTF-8

		XCTAssertMatchesFNMatch("ba", pattern: "[[.a.]]a", flags: 0, result: NOMATCH) // de_DE.UTF-8

		// Test of GNU extensions.
		XCTAssertMatchesFNMatch("x", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x/y", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x/y/z", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x/y", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x/y/z", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x/y", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x/y/z", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x/y", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x/y/z", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("x/y", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("x/y/z", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("x", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("x/y", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x/y/z", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: 0) // C

		XCTAssertMatchesFNMatch("x", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("x/y", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("x/y/z", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C

		// Duplicate the "Test of GNU extensions." tests but for C.UTF-8.
		XCTAssertMatchesFNMatch("x", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y/z", pattern: "x", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y/z", pattern: "*", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y/z", pattern: "*x", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y/z", pattern: "x*", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y/z", pattern: "a", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("x", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y/z", pattern: "x/y", flags: PATHNAME | LEADING_DIR, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("x", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("x/y/z", pattern: "x?y", flags: PATHNAME | LEADING_DIR, result: NOMATCH) // C.UTF-8

		// Bug 14185
//		XCTAssertMatchesFNMatch("\366.csv", pattern: "*.csv", flags: 0, result: 0) // en_US.UTF-8

		// ksh style matching.
		XCTAssertMatchesFNMatch("abcd", pattern: "?@(a|b)*@(c)d", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("/dev/udp/129.22.8.102/45", pattern: "/dev/@(tcp|udp)/*/*", flags: PATHNAME | EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("12", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("12abc", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("1", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("07", pattern: "+([0-7])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("0377", pattern: "+([0-7])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("09", pattern: "+([0-7])", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("paragraph", pattern: "para@(chute|graph)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("paramour", pattern: "para@(chute|graph)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("para991", pattern: "para?([345]|99)1", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("para381", pattern: "para?([345]|99)1", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("paragraph", pattern: "para*([0-9])", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("para", pattern: "para*([0-9])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("para13829383746592", pattern: "para*([0-9])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("paragraph", pattern: "para+([0-9])", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("para", pattern: "para+([0-9])", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("para987346523", pattern: "para+([0-9])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("paragraph", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("para.38", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("para.graph", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("para39", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("137577991", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("2468", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("1358", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("file.c", pattern: "*.c?(c)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("file.C", pattern: "*.c?(c)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("file.cc", pattern: "*.c?(c)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("file.ccc", pattern: "*.c?(c)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("parse.y", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("shell.c", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("Makefile", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: 0) // C

//		XCTAssertMatchesFNMatch("VMS.FILE;1", pattern: "*\;[1-9]*([0-9])", flags: EXTMATCH, result: 0) // C

//		XCTAssertMatchesFNMatch("VMS.FILE;0", pattern: "*\;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH) // C

//		XCTAssertMatchesFNMatch("VMS.FILE;", pattern: "*\;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH) // C

//		XCTAssertMatchesFNMatch("VMS.FILE;139", pattern: "*\;[1-9]*([0-9])", flags: EXTMATCH, result: 0) // C

//		XCTAssertMatchesFNMatch("VMS.FILE;1N", pattern: "*\;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("abcfefg", pattern: "ab**(e|f)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("abcfefg", pattern: "ab**(e|f)g", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ab", pattern: "ab*+(e|f)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("abef", pattern: "ab***ef", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("abef", pattern: "ab**", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("fofo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ffo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foooofo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foooofof", pattern: "*(f*(o))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("fooofoofofooo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foooofof", pattern: "*(f+(o))", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("xfoooofof", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("foooofofx", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("ofxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ofooofoofofooo", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("foooxfooxfoxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foooxfooxofoxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("foooxfooxfxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ofxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ofoooxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxoo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxofo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxooofxofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("aac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("c", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("aaac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("baaac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("abcd", pattern: "?@(a|b)*@(c)d", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("abcd", pattern: "@(ab|a*@(b))*(c)d", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("acd", pattern: "@(ab|a*(b))*(c)d", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("abbcd", pattern: "@(ab|a*(b))*(c)d", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("effgz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("efgz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("egz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("egzefffgzbcdij", pattern: "*(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("egz", pattern: "@(b+(c)d|e+(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("ofoofo", pattern: "*(of+(o))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("oxfoxoxfox", pattern: "*(oxf+(ox))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("oxfoxfox", pattern: "*(oxf+(ox))", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("ofoofo", pattern: "*(of+(o)|f)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foofoofo", pattern: "@(foo|f|fo)*(f|of+(o))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("oofooofo", pattern: "*(of|oof+(o))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("fffooofoooooffoofffooofff", pattern: "*(*(f)*(o))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("fofoofoofofoo", pattern: "*(fo|foo)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foo", pattern: "!(x)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foo", pattern: "!(x)*", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foo", pattern: "!(foo)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("foo", pattern: "!(foo)*", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foobar", pattern: "!(foo)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foobar", pattern: "!(foo)*", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("moo.cow", pattern: "!(*.*).!(*.*)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("mad.moo.cow", pattern: "!(*.*).!(*.*)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("mucca.pazza", pattern: "mu!(*(c))?.pa!(*(z))?", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("fff", pattern: "!(f)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("fff", pattern: "*(!(f))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("fff", pattern: "+(!(f))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ooo", pattern: "!(f)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ooo", pattern: "*(!(f))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ooo", pattern: "+(!(f))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foo", pattern: "!(f)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foo", pattern: "*(!(f))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foo", pattern: "+(!(f))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("f", pattern: "!(f)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("f", pattern: "*(!(f))", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("f", pattern: "+(!(f))", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("foot", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("zoot", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("foox", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("zoox", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foo", pattern: "*(!(foo))", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("foob", pattern: "!(foo)b*", flags: EXTMATCH, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("foobb", pattern: "!(foo)b*", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("[", pattern: "*([a[])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("]", pattern: "*([]a[])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("a", pattern: "*([]a[])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("b", pattern: "*([!]a[])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("[", pattern: "*([!]a[]|[[])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("]", pattern: "*([!]a[]|[]])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("[", pattern: "!([!]a[])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("]", pattern: "!([!]a[])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch(")", pattern: "*([)])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("*", pattern: "*([*(])", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("abcd", pattern: "*!(|a)cd", flags: EXTMATCH, result: 0) // C

		XCTAssertMatchesFNMatch("ab/.a", pattern: "+([abc])/*", flags: EXTMATCH | PATHNAME | PERIOD, result: NOMATCH) // C

		XCTAssertMatchesFNMatch("", pattern: "", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("", pattern: "", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("", pattern: "*([abc])", flags: 0, result: 0) // C

		XCTAssertMatchesFNMatch("", pattern: "?([abc])", flags: 0, result: 0) // C

		// Duplicate the "ksh style matching." for C.UTF-8.
		XCTAssertMatchesFNMatch("abcd", pattern: "?@(a|b)*@(c)d", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("/dev/udp/129.22.8.102/45", pattern: "/dev/@(tcp|udp)/*/*", flags: PATHNAME | EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("12", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("12abc", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("1", pattern: "[1-9]*([0-9])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("07", pattern: "+([0-7])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("0377", pattern: "+([0-7])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("09", pattern: "+([0-7])", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("paragraph", pattern: "para@(chute|graph)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("paramour", pattern: "para@(chute|graph)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("para991", pattern: "para?([345]|99)1", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("para381", pattern: "para?([345]|99)1", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("paragraph", pattern: "para*([0-9])", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("para", pattern: "para*([0-9])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("para13829383746592", pattern: "para*([0-9])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("paragraph", pattern: "para+([0-9])", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("para", pattern: "para+([0-9])", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("para987346523", pattern: "para+([0-9])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("paragraph", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("para.38", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("para.graph", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("para39", pattern: "para!(*.[0-9])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("", pattern: "*(0|1|3|5|7|9)", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("137577991", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("2468", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("1358", pattern: "*(0|1|3|5|7|9)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("file.c", pattern: "*.c?(c)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("file.C", pattern: "*.c?(c)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("file.cc", pattern: "*.c?(c)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("file.ccc", pattern: "*.c?(c)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("parse.y", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("shell.c", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("Makefile", pattern: "!(*.c|*.h|Makefile.in|config*|README)", flags: EXTMATCH, result: 0) // C.UTF-8

//		XCTAssertMatchesFNMatch("VMS.FILE;1", pattern: "*\;[1-9]*([0-9])", flags: EXTMATCH, result: 0) // C.UTF-8

//		XCTAssertMatchesFNMatch("VMS.FILE;0", pattern: "*\;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

//		XCTAssertMatchesFNMatch("VMS.FILE;", pattern: "*\;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

//		XCTAssertMatchesFNMatch("VMS.FILE;139", pattern: "*\;[1-9]*([0-9])", flags: EXTMATCH, result: 0) // C.UTF-8

//		XCTAssertMatchesFNMatch("VMS.FILE;1N", pattern: "*\;[1-9]*([0-9])", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("abcfefg", pattern: "ab**(e|f)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("abcfefg", pattern: "ab**(e|f)g", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ab", pattern: "ab*+(e|f)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("abef", pattern: "ab***ef", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("abef", pattern: "ab**", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("fofo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ffo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foooofo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foooofof", pattern: "*(f*(o))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("fooofoofofooo", pattern: "*(f*(o))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foooofof", pattern: "*(f+(o))", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("xfoooofof", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("foooofofx", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("ofxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ofooofoofofooo", pattern: "*(f*(o))", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("foooxfooxfoxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foooxfooxofoxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("foooxfooxfxfooox", pattern: "*(f*(o)x)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ofxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ofoooxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxoo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxofo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("ofoooxoofxoofoooxoofxooofxofxo", pattern: "*(*(of*(o)x)o)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("aac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("c", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("aaac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("baaac", pattern: "*(@(a))a@(c)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("abcd", pattern: "?@(a|b)*@(c)d", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("abcd", pattern: "@(ab|a*@(b))*(c)d", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("acd", pattern: "@(ab|a*(b))*(c)d", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("abbcd", pattern: "@(ab|a*(b))*(c)d", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("effgz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("efgz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("egz", pattern: "@(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("egzefffgzbcdij", pattern: "*(b+(c)d|e*(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("egz", pattern: "@(b+(c)d|e+(f)g?|?(h)i@(j|k))", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("ofoofo", pattern: "*(of+(o))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("oxfoxoxfox", pattern: "*(oxf+(ox))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("oxfoxfox", pattern: "*(oxf+(ox))", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("ofoofo", pattern: "*(of+(o)|f)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foofoofo", pattern: "@(foo|f|fo)*(f|of+(o))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("oofooofo", pattern: "*(of|oof+(o))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("fffooofoooooffoofffooofff", pattern: "*(*(f)*(o))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("fofoofoofofoo", pattern: "*(fo|foo)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foo", pattern: "!(x)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foo", pattern: "!(x)*", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foo", pattern: "!(foo)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("foo", pattern: "!(foo)*", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foobar", pattern: "!(foo)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foobar", pattern: "!(foo)*", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("moo.cow", pattern: "!(*.*).!(*.*)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("mad.moo.cow", pattern: "!(*.*).!(*.*)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("mucca.pazza", pattern: "mu!(*(c))?.pa!(*(z))?", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("fff", pattern: "!(f)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("fff", pattern: "*(!(f))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("fff", pattern: "+(!(f))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ooo", pattern: "!(f)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ooo", pattern: "*(!(f))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ooo", pattern: "+(!(f))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foo", pattern: "!(f)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foo", pattern: "*(!(f))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foo", pattern: "+(!(f))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("f", pattern: "!(f)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("f", pattern: "*(!(f))", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("f", pattern: "+(!(f))", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("foot", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("zoot", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("foox", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("zoox", pattern: "@(!(z*)|*x)", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foo", pattern: "*(!(foo))", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("foob", pattern: "!(foo)b*", flags: EXTMATCH, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("foobb", pattern: "!(foo)b*", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("[", pattern: "*([a[])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("]", pattern: "*([]a[])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("a", pattern: "*([]a[])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("b", pattern: "*([!]a[])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("[", pattern: "*([!]a[]|[[])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("]", pattern: "*([!]a[]|[]])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("[", pattern: "!([!]a[])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("]", pattern: "!([!]a[])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch(")", pattern: "*([)])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("*", pattern: "*([*(])", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("abcd", pattern: "*!(|a)cd", flags: EXTMATCH, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("ab/.a", pattern: "+([abc])/*", flags: EXTMATCH | PATHNAME | PERIOD, result: NOMATCH) // C.UTF-8

		XCTAssertMatchesFNMatch("", pattern: "", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("", pattern: "", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("", pattern: "*([abc])", flags: 0, result: 0) // C.UTF-8

		XCTAssertMatchesFNMatch("", pattern: "?([abc])", flags: 0, result: 0) // C.UTF-8
	}
}
