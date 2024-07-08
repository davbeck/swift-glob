import XCTest

@testable import Glob

// from https://github.com/microsoft/vscode/blob/main/src/vs/base/test/common/glob.test.ts

final class PatternVSCodeTests: XCTestCase {
	func test_simple() throws {
		try XCTAssertMatches("node_modules", pattern: "node_modules", options: .vscode)
		try XCTAssertDoesNotMatch("node_module", pattern: "node_modules", options: .vscode)
		try XCTAssertDoesNotMatch("/node_modules", pattern: "node_modules", options: .vscode)
		try XCTAssertDoesNotMatch("test/node_modules", pattern: "node_modules", options: .vscode)
		try XCTAssertMatches("test.txt", pattern: "test.txt", options: .vscode)
		try XCTAssertDoesNotMatch("test?txt", pattern: "test.txt", options: .vscode)
		try XCTAssertDoesNotMatch("/text.txt", pattern: "test.txt", options: .vscode)
		try XCTAssertDoesNotMatch("test/test.txt", pattern: "test.txt", options: .vscode)
		try XCTAssertMatches("test(.txt", pattern: "test(.txt", options: .vscode)
		try XCTAssertDoesNotMatch("test?txt", pattern: "test(.txt", options: .vscode)
		try XCTAssertMatches("qunit", pattern: "qunit", options: .vscode)
		try XCTAssertDoesNotMatch("qunit.css", pattern: "qunit", options: .vscode)
		try XCTAssertDoesNotMatch("test/qunit", pattern: "qunit", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("/DNXConsoleApp/Program.cs", pattern: "/DNXConsoleApp/**/*.cs", options: .vscode)
		}
		try XCTAssertMatches("/DNXConsoleApp/foo/Program.cs", pattern: "/DNXConsoleApp/**/*.cs", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("C:\\DNXConsoleApp\\Program.cs", pattern: "C:/DNXConsoleApp/**/*.cs", options: .vscode)
		}
		try XCTExpectFailure {
			try XCTAssertMatches("C:\\DNXConsoleApp\\foo\\Program.cs", pattern: "C:/DNXConsoleApp/**/*.cs", options: .vscode)
		}
		try XCTAssertMatches("", pattern: "*", options: .vscode)
	}

	func test_dotHidden() throws {
		try XCTAssertMatches(".git", pattern: ".*", options: .vscode)
		try XCTAssertMatches(".hidden.txt", pattern: ".*", options: .vscode)
		try XCTAssertDoesNotMatch("git", pattern: ".*", options: .vscode)
		try XCTAssertDoesNotMatch("hidden.txt", pattern: ".*", options: .vscode)
		try XCTAssertDoesNotMatch("path/.git", pattern: ".*", options: .vscode)
		try XCTAssertDoesNotMatch("path/.hidden.txt", pattern: ".*", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches(".git", pattern: "**/.*", options: .vscode)
		}
		try XCTAssertMatches("/.git", pattern: "**/.*", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches(".hidden.txt", pattern: "**/.*", options: .vscode)
		}
		try XCTAssertDoesNotMatch("git", pattern: "**/.*", options: .vscode)
		try XCTAssertDoesNotMatch("hidden.txt", pattern: "**/.*", options: .vscode)
		try XCTAssertMatches("path/.git", pattern: "**/.*", options: .vscode)
		try XCTAssertMatches("path/.hidden.txt", pattern: "**/.*", options: .vscode)
		try XCTAssertMatches("/path/.git", pattern: "**/.*", options: .vscode)
		try XCTAssertMatches("/path/.hidden.txt", pattern: "**/.*", options: .vscode)
		try XCTAssertDoesNotMatch("path/git", pattern: "**/.*", options: .vscode)
		try XCTAssertDoesNotMatch("pat.h/hidden.txt", pattern: "**/.*", options: .vscode)
		try XCTAssertMatches("._git", pattern: "._*", options: .vscode)
		try XCTAssertMatches("._hidden.txt", pattern: "._*", options: .vscode)
		try XCTAssertDoesNotMatch("git", pattern: "._*", options: .vscode)
		try XCTAssertDoesNotMatch("hidden.txt", pattern: "._*", options: .vscode)
		try XCTAssertDoesNotMatch("path/._git", pattern: "._*", options: .vscode)
		try XCTAssertDoesNotMatch("path/._hidden.txt", pattern: "._*", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("._git", pattern: "**/._*", options: .vscode)
		}
		try XCTExpectFailure {
			try XCTAssertMatches("._hidden.txt", pattern: "**/._*", options: .vscode)
		}
		try XCTAssertDoesNotMatch("git", pattern: "**/._*", options: .vscode)
		try XCTAssertDoesNotMatch("hidden._txt", pattern: "**/._*", options: .vscode)
		try XCTAssertMatches("path/._git", pattern: "**/._*", options: .vscode)
		try XCTAssertMatches("path/._hidden.txt", pattern: "**/._*", options: .vscode)
		try XCTAssertMatches("/path/._git", pattern: "**/._*", options: .vscode)
		try XCTAssertMatches("/path/._hidden.txt", pattern: "**/._*", options: .vscode)
		try XCTAssertDoesNotMatch("path/git", pattern: "**/._*", options: .vscode)
		try XCTAssertDoesNotMatch("pat.h/hidden._txt", pattern: "**/._*", options: .vscode)
	}

	func test_filePattern() throws {
		try XCTAssertMatches("foo.js", pattern: "*.js", options: .vscode)
		try XCTAssertDoesNotMatch("folder/foo.js", pattern: "*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/node_modules/foo.js", pattern: "*.js", options: .vscode)
		try XCTAssertDoesNotMatch("foo.jss", pattern: "*.js", options: .vscode)
		try XCTAssertDoesNotMatch("some.js/test", pattern: "*.js", options: .vscode)
		try XCTAssertMatches("html.js", pattern: "html.*", options: .vscode)
		try XCTAssertMatches("html.txt", pattern: "html.*", options: .vscode)
		try XCTAssertDoesNotMatch("htm.txt", pattern: "html.*", options: .vscode)
		try XCTAssertMatches("html.js", pattern: "*.*", options: .vscode)
		try XCTAssertMatches("html.txt", pattern: "*.*", options: .vscode)
		try XCTAssertMatches("htm.txt", pattern: "*.*", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertDoesNotMatch("folder/foo.js", pattern: "*.*", options: .vscode)
		}
		try XCTExpectFailure {
			try XCTAssertDoesNotMatch("/node_modules/foo.js", pattern: "*.*", options: .vscode)
		}
		try XCTAssertMatches("node_modules/test/foo.js", pattern: "node_modules/test/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("folder/foo.js", pattern: "node_modules/test/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/node_module/test/foo.js", pattern: "node_modules/test/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("foo.jss", pattern: "node_modules/test/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("some.js/test", pattern: "node_modules/test/*.js", options: .vscode)
	}

	func test_star() throws {
		try XCTAssertMatches("node_modules", pattern: "node*modules", options: .vscode)
		try XCTAssertMatches("node_super_modules", pattern: "node*modules", options: .vscode)
		try XCTAssertDoesNotMatch("node_module", pattern: "node*modules", options: .vscode)
		try XCTAssertDoesNotMatch("/node_modules", pattern: "node*modules", options: .vscode)
		try XCTAssertDoesNotMatch("test/node_modules", pattern: "node*modules", options: .vscode)
		try XCTAssertMatches("html.js", pattern: "*", options: .vscode)
		try XCTAssertMatches("html.txt", pattern: "*", options: .vscode)
		try XCTAssertMatches("htm.txt", pattern: "*", options: .vscode)
		try XCTAssertDoesNotMatch("folder/foo.js", pattern: "*", options: .vscode)
		try XCTAssertDoesNotMatch("/node_modules/foo.js", pattern: "*", options: .vscode)
	}

	func test_fileFolderMatch() throws {
		try XCTExpectFailure {
			try XCTAssertMatches("node_modules", pattern: "**/node_modules/**", options: .vscode)
		}
		try XCTExpectFailure {
			try XCTAssertMatches("node_modules/", pattern: "**/node_modules/**", options: .vscode)
		}
		try XCTExpectFailure {
			try XCTAssertMatches("a/node_modules", pattern: "**/node_modules/**", options: .vscode)
		}
		try XCTAssertMatches("a/node_modules/", pattern: "**/node_modules/**", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("node_modules/foo", pattern: "**/node_modules/**", options: .vscode)
		}
		try XCTAssertMatches("foo/node_modules/foo/bar", pattern: "**/node_modules/**", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("/node_modules", pattern: "**/node_modules/**", options: .vscode)
		}
		try XCTAssertMatches("/node_modules/", pattern: "**/node_modules/**", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("/a/node_modules", pattern: "**/node_modules/**", options: .vscode)
		}
		try XCTAssertMatches("/a/node_modules/", pattern: "**/node_modules/**", options: .vscode)
		try XCTAssertMatches("/node_modules/foo", pattern: "**/node_modules/**", options: .vscode)
		try XCTAssertMatches("/foo/node_modules/foo/bar", pattern: "**/node_modules/**", options: .vscode)
	}

	func test_questionmark() throws {
		try XCTAssertMatches("node_modules", pattern: "node?modules", options: .vscode)
		try XCTAssertDoesNotMatch("node_super_modules", pattern: "node?modules", options: .vscode)
		try XCTAssertDoesNotMatch("node_module", pattern: "node?modules", options: .vscode)
		try XCTAssertDoesNotMatch("/node_modules", pattern: "node?modules", options: .vscode)
		try XCTAssertDoesNotMatch("test/node_modules", pattern: "node?modules", options: .vscode)
		try XCTAssertMatches("h", pattern: "?", options: .vscode)
		try XCTAssertDoesNotMatch("html.txt", pattern: "?", options: .vscode)
		try XCTAssertDoesNotMatch("htm.txt", pattern: "?", options: .vscode)
		try XCTAssertDoesNotMatch("folder/foo.js", pattern: "?", options: .vscode)
		try XCTAssertDoesNotMatch("/node_modules/foo.js", pattern: "?", options: .vscode)
	}

	func test_globstar() throws {
		try XCTExpectFailure {
			try XCTAssertMatches("foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTAssertMatches("/foo.js", pattern: "**/*.js", options: .vscode)
		try XCTAssertMatches("folder/foo.js", pattern: "**/*.js", options: .vscode)
		try XCTAssertMatches("/node_modules/foo.js", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("foo.jss", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("some.js/test", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/some.js/test", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("\\some.js\\test", pattern: "**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("project.json", pattern: "**/project.json", options: .vscode)
		}
		try XCTAssertMatches("/project.json", pattern: "**/project.json", options: .vscode)
		try XCTAssertMatches("some/folder/project.json", pattern: "**/project.json", options: .vscode)
		try XCTAssertMatches("/some/folder/project.json", pattern: "**/project.json", options: .vscode)
		try XCTAssertDoesNotMatch("some/folder/file_project.json", pattern: "**/project.json", options: .vscode)
		try XCTAssertDoesNotMatch("some/folder/fileproject.json", pattern: "**/project.json", options: .vscode)
		try XCTAssertDoesNotMatch("some/rrproject.json", pattern: "**/project.json", options: .vscode)
		try XCTAssertDoesNotMatch("some\\rrproject.json", pattern: "**/project.json", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("test", pattern: "test/**", options: .vscode)
		}
		try XCTAssertMatches("test/foo", pattern: "test/**", options: .vscode)
		try XCTAssertMatches("test/foo/", pattern: "test/**", options: .vscode)
		try XCTAssertMatches("test/foo.js", pattern: "test/**", options: .vscode)
		try XCTAssertMatches("test/other/foo.js", pattern: "test/**", options: .vscode)
		try XCTAssertDoesNotMatch("est/other/foo.js", pattern: "test/**", options: .vscode)
		try XCTAssertMatches("/", pattern: "**", options: .vscode)
		try XCTAssertMatches("foo.js", pattern: "**", options: .vscode)
		try XCTAssertMatches("folder/foo.js", pattern: "**", options: .vscode)
		try XCTAssertMatches("folder/foo/", pattern: "**", options: .vscode)
		try XCTAssertMatches("/node_modules/foo.js", pattern: "**", options: .vscode)
		try XCTAssertMatches("foo.jss", pattern: "**", options: .vscode)
		try XCTAssertMatches("some.js/test", pattern: "**", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("test/foo.js", pattern: "test/**/*.js", options: .vscode)
		}
		try XCTAssertMatches("test/other/foo.js", pattern: "test/**/*.js", options: .vscode)
		try XCTAssertMatches("test/other/more/foo.js", pattern: "test/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("test/foo.ts", pattern: "test/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("test/other/foo.ts", pattern: "test/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("test/other/more/foo.ts", pattern: "test/**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("foo.js", pattern: "**/**/*.js", options: .vscode)
			try XCTAssertMatches("/foo.js", pattern: "**/**/*.js", options: .vscode)
			try XCTAssertMatches("folder/foo.js", pattern: "**/**/*.js", options: .vscode)
		}
		try XCTAssertMatches("/node_modules/foo.js", pattern: "**/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("foo.jss", pattern: "**/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("some.js/test", pattern: "**/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("foo.js", pattern: "**/node_modules/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("folder/foo.js", pattern: "**/node_modules/**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("node_modules/foo.js", pattern: "**/node_modules/**/*.js", options: .vscode)
			try XCTAssertMatches("/node_modules/foo.js", pattern: "**/node_modules/**/*.js", options: .vscode)
			try XCTAssertMatches("node_modules/some/folder/foo.js", pattern: "**/node_modules/**/*.js", options: .vscode)
		}
		try XCTAssertMatches("/node_modules/some/folder/foo.js", pattern: "**/node_modules/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("node_modules/some/folder/foo.ts", pattern: "**/node_modules/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("foo.jss", pattern: "**/node_modules/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("some.js/test", pattern: "**/node_modules/**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("node_modules", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("/node_modules", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("/node_modules/more", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("some/test/node_modules", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("some\\test\\node_modules", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("/some/test/node_modules", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("\\some\\test\\node_modules", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("C:\\\\some\\test\\node_modules", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("C:\\\\some\\test\\node_modules\\more", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("bower_components", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("bower_components/more", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("/bower_components", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("some/test/bower_components", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("some\\test\\bower_components", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("/some/test/bower_components", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("\\some\\test\\bower_components", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("C:\\\\some\\test\\bower_components", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("C:\\\\some\\test\\bower_components\\more", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches(".git", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("/.git", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("some/test/.git", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("some\\test\\.git", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("/some/test/.git", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("\\some\\test\\.git", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
			try XCTAssertMatches("C:\\\\some\\test\\.git", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
		}
		try XCTAssertDoesNotMatch("tempting", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
		try XCTAssertDoesNotMatch("/tempting", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
		try XCTAssertDoesNotMatch("some/test/tempting", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
		try XCTAssertDoesNotMatch("some\\test\\tempting", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
		try XCTAssertDoesNotMatch("/some/test/tempting", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
		try XCTAssertDoesNotMatch("\\some\\test\\tempting", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
		try XCTAssertDoesNotMatch("C:\\\\some\\test\\tempting", pattern: "{**/node_modules/**,**/.git/**,**/bower_components/**}", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("package.json", pattern: "{**/package.json,**/project.json}", options: .vscode)
			try XCTAssertMatches("/package.json", pattern: "{**/package.json,**/project.json}", options: .vscode)
		}
		try XCTAssertDoesNotMatch("xpackage.json", pattern: "{**/package.json,**/project.json}", options: .vscode)
		try XCTAssertDoesNotMatch("/xpackage.json", pattern: "{**/package.json,**/project.json}", options: .vscode)
	}

	func test_issue41724() throws {
		try XCTExpectFailure {
			try XCTAssertMatches("some/foo.js", pattern: "some/**/*.js", options: .vscode)
		}
		try XCTAssertMatches("some/folder/foo.js", pattern: "some/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("something/foo.js", pattern: "some/**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("something/folder/foo.js", pattern: "some/**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("some/foo.js", pattern: "some/**/*", options: .vscode)
		}
		try XCTAssertMatches("some/folder/foo.js", pattern: "some/**/*", options: .vscode)
		try XCTAssertDoesNotMatch("something/foo.js", pattern: "some/**/*", options: .vscode)
		try XCTAssertDoesNotMatch("something/folder/foo.js", pattern: "some/**/*", options: .vscode)
	}

	func test_braceExpansion() throws {
		try XCTExpectFailure {
			try XCTAssertMatches("foo.js", pattern: "*.{html,js}", options: .vscode)
			try XCTAssertMatches("foo.html", pattern: "*.{html,js}", options: .vscode)
			try XCTAssertDoesNotMatch("folder/foo.js", pattern: "*.{html,js}", options: .vscode)
			try XCTAssertDoesNotMatch("/node_modules/foo.js", pattern: "*.{html,js}", options: .vscode)
			try XCTAssertDoesNotMatch("foo.jss", pattern: "*.{html,js}", options: .vscode)
			try XCTAssertDoesNotMatch("some.js/test", pattern: "*.{html,js}", options: .vscode)
			try XCTAssertMatches("foo.html", pattern: "*.{html}", options: .vscode)
			try XCTAssertDoesNotMatch("foo.js", pattern: "*.{html}", options: .vscode)
			try XCTAssertDoesNotMatch("folder/foo.js", pattern: "*.{html}", options: .vscode)
			try XCTAssertDoesNotMatch("/node_modules/foo.js", pattern: "*.{html}", options: .vscode)
			try XCTAssertDoesNotMatch("foo.jss", pattern: "*.{html}", options: .vscode)
			try XCTAssertDoesNotMatch("some.js/test", pattern: "*.{html}", options: .vscode)
			try XCTAssertMatches("node_modules", pattern: "{node_modules,testing}", options: .vscode)
			try XCTAssertMatches("testing", pattern: "{node_modules,testing}", options: .vscode)
			try XCTAssertDoesNotMatch("node_module", pattern: "{node_modules,testing}", options: .vscode)
			try XCTAssertDoesNotMatch("dtesting", pattern: "{node_modules,testing}", options: .vscode)
			try XCTAssertMatches("foo", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("bar", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("test/foo", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("test/bar", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("other/more/foo", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("other/more/bar", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("/foo", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("/bar", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("/test/foo", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("/test/bar", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("/other/more/foo", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("/other/more/bar", pattern: "**/{foo,bar}", options: .vscode)
			try XCTAssertMatches("foo", pattern: "{foo,bar}/**", options: .vscode)
			try XCTAssertMatches("bar", pattern: "{foo,bar}/**", options: .vscode)
			try XCTAssertMatches("bar/", pattern: "{foo,bar}/**", options: .vscode)
			try XCTAssertMatches("foo/test", pattern: "{foo,bar}/**", options: .vscode)
			try XCTAssertMatches("bar/test", pattern: "{foo,bar}/**", options: .vscode)
			try XCTAssertMatches("bar/test/", pattern: "{foo,bar}/**", options: .vscode)
			try XCTAssertMatches("foo/other/more", pattern: "{foo,bar}/**", options: .vscode)
			try XCTAssertMatches("bar/other/more", pattern: "{foo,bar}/**", options: .vscode)
			try XCTAssertMatches("bar/other/more/", pattern: "{foo,bar}/**", options: .vscode)
			try XCTAssertMatches("foo.js", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("testing/foo.js", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("testing\\foo.js", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("/testing/foo.js", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("\\testing\\foo.js", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("C:\\testing\\foo.js", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("foo.d.ts", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("testing/foo.d.ts", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("testing\\foo.d.ts", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("/testing/foo.d.ts", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("\\testing\\foo.d.ts", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("C:\\testing\\foo.d.ts", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertDoesNotMatch("foo.d", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertDoesNotMatch("testing/foo.d", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertDoesNotMatch("testing\\foo.d", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertDoesNotMatch("/testing/foo.d", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertDoesNotMatch("\\testing\\foo.d", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertDoesNotMatch("C:\\testing\\foo.d", pattern: "{**/*.d.ts,**/*.js}", options: .vscode)
			try XCTAssertMatches("foo.js", pattern: "{**/*.d.ts,**/*.js,path/simple.jgs}", options: .vscode)
			try XCTAssertMatches("testing/foo.js", pattern: "{**/*.d.ts,**/*.js,path/simple.jgs}", options: .vscode)
			try XCTAssertMatches("testing\\foo.js", pattern: "{**/*.d.ts,**/*.js,path/simple.jgs}", options: .vscode)
			try XCTAssertMatches("/testing/foo.js", pattern: "{**/*.d.ts,**/*.js,path/simple.jgs}", options: .vscode)
			try XCTAssertMatches("path/simple.jgs", pattern: "{**/*.d.ts,**/*.js,path/simple.jgs}", options: .vscode)
			try XCTAssertDoesNotMatch("/path/simple.jgs", pattern: "{**/*.d.ts,**/*.js,path/simple.jgs}", options: .vscode)
			try XCTAssertMatches("\\testing\\foo.js", pattern: "{**/*.d.ts,**/*.js,path/simple.jgs}", options: .vscode)
			try XCTAssertMatches("C:\\testing\\foo.js", pattern: "{**/*.d.ts,**/*.js,path/simple.jgs}", options: .vscode)
			try XCTAssertMatches("foo.5", pattern: "{**/*.d.ts,**/*.js,foo.[0-9]}", options: .vscode)
			try XCTAssertMatches("foo.8", pattern: "{**/*.d.ts,**/*.js,foo.[0-9]}", options: .vscode)
			try XCTAssertDoesNotMatch("bar.5", pattern: "{**/*.d.ts,**/*.js,foo.[0-9]}", options: .vscode)
			try XCTAssertDoesNotMatch("foo.f", pattern: "{**/*.d.ts,**/*.js,foo.[0-9]}", options: .vscode)
			try XCTAssertMatches("foo.js", pattern: "{**/*.d.ts,**/*.js,foo.[0-9]}", options: .vscode)
			try XCTAssertMatches("prefix/foo.5", pattern: "prefix/{**/*.d.ts,**/*.js,foo.[0-9]}", options: .vscode)
			try XCTAssertMatches("prefix/foo.8", pattern: "prefix/{**/*.d.ts,**/*.js,foo.[0-9]}", options: .vscode)
			try XCTAssertDoesNotMatch("prefix/bar.5", pattern: "prefix/{**/*.d.ts,**/*.js,foo.[0-9]}", options: .vscode)
			try XCTAssertDoesNotMatch("prefix/foo.f", pattern: "prefix/{**/*.d.ts,**/*.js,foo.[0-9]}", options: .vscode)
			try XCTAssertMatches("prefix/foo.js", pattern: "prefix/{**/*.d.ts,**/*.js,foo.[0-9]}", options: .vscode)
		}
	}

	func test_brackets() throws {
		try XCTAssertMatches("foo.5", pattern: "foo.[0-9]", options: .vscode)
		try XCTAssertMatches("foo.8", pattern: "foo.[0-9]", options: .vscode)
		try XCTAssertDoesNotMatch("bar.5", pattern: "foo.[0-9]", options: .vscode)
		try XCTAssertDoesNotMatch("foo.f", pattern: "foo.[0-9]", options: .vscode)
		try XCTAssertDoesNotMatch("foo.5", pattern: "foo.[^0-9]", options: .vscode)
		try XCTAssertDoesNotMatch("foo.8", pattern: "foo.[^0-9]", options: .vscode)
		try XCTAssertDoesNotMatch("bar.5", pattern: "foo.[^0-9]", options: .vscode)
		try XCTAssertMatches("foo.f", pattern: "foo.[^0-9]", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertDoesNotMatch("foo.5", pattern: "foo.[!0-9]", options: .vscode)
		}
		try XCTExpectFailure {
			try XCTAssertDoesNotMatch("foo.8", pattern: "foo.[!0-9]", options: .vscode)
		}
		try XCTAssertDoesNotMatch("bar.5", pattern: "foo.[!0-9]", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("foo.f", pattern: "foo.[!0-9]", options: .vscode)
		}
		try XCTAssertDoesNotMatch("foo.5", pattern: "foo.[0!^*?]", options: .vscode)
		try XCTAssertDoesNotMatch("foo.8", pattern: "foo.[0!^*?]", options: .vscode)
		try XCTAssertMatches("foo.0", pattern: "foo.[0!^*?]", options: .vscode)
		try XCTAssertMatches("foo.!", pattern: "foo.[0!^*?]", options: .vscode)
		try XCTAssertMatches("foo.^", pattern: "foo.[0!^*?]", options: .vscode)
		try XCTAssertMatches("foo.*", pattern: "foo.[0!^*?]", options: .vscode)
		try XCTAssertMatches("foo.?", pattern: "foo.[0!^*?]", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertDoesNotMatch("foo/bar", pattern: "foo[/]bar", options: .vscode)
		}
		try XCTAssertMatches("foo.[", pattern: "foo.[[]", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("foo.]", pattern: "foo.[]]", options: .vscode)
			try XCTAssertMatches("foo.]", pattern: "foo.[][!]", options: .vscode)
			try XCTAssertMatches("foo.[", pattern: "foo.[][!]", options: .vscode)
			try XCTAssertMatches("foo.!", pattern: "foo.[][!]", options: .vscode)
			try XCTAssertMatches("foo.]", pattern: "foo.[]-]", options: .vscode)
			try XCTAssertMatches("foo.-", pattern: "foo.[]-]", options: .vscode)
		}
	}

	func test_fullPath() throws {
		try XCTAssertMatches("testing/this/foo.txt", pattern: "testing/this/foo.txt", options: .vscode)
	}

	func test_endingPath() throws {
		try XCTAssertMatches("some/path/testing/this/foo.txt", pattern: "**/testing/this/foo.txt", options: .vscode)
	}

	func test_prefixAgnostic() throws {
		try XCTExpectFailure {
			try XCTAssertMatches("foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTAssertMatches("/foo.js", pattern: "**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("\\foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTAssertMatches("testing/foo.js", pattern: "**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("testing\\foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTAssertMatches("/testing/foo.js", pattern: "**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("\\testing\\foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTExpectFailure {
			try XCTAssertMatches("C:\\testing\\foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTAssertDoesNotMatch("foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing/foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing\\foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/testing/foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("\\testing\\foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("C:\\testing\\foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing/foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing\\foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/testing/foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("\\testing\\foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("C:\\testing\\foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing.js/foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing.js\\foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/testing.js/foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("\\testing.js\\foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("C:\\testing.js\\foo", pattern: "**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("foo.js", pattern: "**/foo.js", options: .vscode)
		}
		try XCTAssertMatches("/foo.js", pattern: "**/foo.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("\\foo.js", pattern: "**/foo.js", options: .vscode)
		}
		try XCTAssertMatches("testing/foo.js", pattern: "**/foo.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("testing\\foo.js", pattern: "**/foo.js", options: .vscode)
		}
		try XCTAssertMatches("/testing/foo.js", pattern: "**/foo.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("\\testing\\foo.js", pattern: "**/foo.js", options: .vscode)
		}
		try XCTExpectFailure {
			try XCTAssertMatches("C:\\testing\\foo.js", pattern: "**/foo.js", options: .vscode)
		}
	}

	func test_cachedProperly() throws {
		try XCTExpectFailure {
			try XCTAssertMatches("foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTAssertMatches("testing/foo.js", pattern: "**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("testing\\foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTAssertMatches("/testing/foo.js", pattern: "**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("\\testing\\foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTExpectFailure {
			try XCTAssertMatches("C:\\testing\\foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTAssertDoesNotMatch("foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing/foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing\\foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/testing/foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("\\testing\\foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("C:\\testing\\foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing/foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing\\foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/testing/foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("\\testing\\foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("C:\\testing\\foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing.js/foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing.js\\foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/testing.js/foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("\\testing.js\\foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("C:\\testing.js\\foo", pattern: "**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTAssertMatches("testing/foo.js", pattern: "**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("testing\\foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTAssertMatches("/testing/foo.js", pattern: "**/*.js", options: .vscode)
		try XCTExpectFailure {
			try XCTAssertMatches("\\testing\\foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTExpectFailure {
			try XCTAssertMatches("C:\\testing\\foo.js", pattern: "**/*.js", options: .vscode)
		}
		try XCTAssertDoesNotMatch("foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing/foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing\\foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/testing/foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("\\testing\\foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("C:\\testing\\foo.ts", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing/foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing\\foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/testing/foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("\\testing\\foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("C:\\testing\\foo.js.txt", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing.js/foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("testing.js\\foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("/testing.js/foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("\\testing.js\\foo", pattern: "**/*.js", options: .vscode)
		try XCTAssertDoesNotMatch("C:\\testing.js\\foo", pattern: "**/*.js", options: .vscode)
	}

	func test_invalidGlob() throws {
		try XCTAssertDoesNotMatch("foo.js", pattern: "**/*(.js", options: .vscode)
	}
}
