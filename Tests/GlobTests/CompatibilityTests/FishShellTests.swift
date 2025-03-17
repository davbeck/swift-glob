import Foundation
import Testing

@testable import Glob

struct FishShellTests {
	// https://github.com/fish-shell/fish-shell/blob/master/tests/checks/glob.fish

	private let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)

	init() throws {
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	}

	private func touch(_ files: String...) throws {
		for file in files {
			try Data().write(to: directory.appending(path: file))
		}
	}

	private func mkdir(_ files: String...) throws {
		for file in files {
			try FileManager.default.createDirectory(
				at: directory.appending(path: file),
				withIntermediateDirectories: true
			)
		}
	}

	private func ln(_ destination: String, _ source: String) throws {
		try FileManager.default.createSymbolicLink(
			at: directory.appending(path: source),
			withDestinationURL: directory.appending(path: destination)
		)
	}

	private func pattern(_ pattern: String) throws -> Pattern {
		try Pattern(pattern, options: .default)
	}

	private func search(_ pattern: String) async throws -> Set<String> {
		try await Glob.search(
			directory: directory,
			include: [self.pattern(pattern)]
		)
		.reduce(into: Set<String>()) { $0.insert($1.relativePath(from: directory)) }
	}

	// MARK: -

	@Test func hiddenFilesAreOnlyMatchedWithExplicitDot() async throws {
		try touch(".hidden", "visible")
		try await #expect(search("*") == ["visible"])
		try await #expect(search(".*") == [".hidden"])
	}

	@Test func trailingSlashMatchesOnlyDirectories() async throws {
		try touch("abc1")
		try mkdir("abc2")
		try await #expect(search("*") == ["abc1", "abc2/"])
		try await #expect(search("*/") == ["abc2/"])
	}

	@Test func symlinksAreDescendedIntoIndependently() async throws {
		// Here dir2/link2 is symlinked to dir1/child1.
		// The contents of dir2 will be explored twice.
		print("directory", directory.path(percentEncoded: false))

		try mkdir("dir1/child1")
		try touch("dir1/child1/anyfile")
		try mkdir("dir2")
		try ln("dir1/child1", "dir2/link2")

		await withKnownIssue {
			try await #expect(search("**/anyfile") == ["dir1/child1/anyfile", "dir2/link2/anyfile"])
		}
	}

	@Test func butSymlinkLoopsOnlyGetExploredOnce() async throws {
		try mkdir("dir1/child2/grandchild1")
		try touch("dir1/child2/grandchild1/differentfile")
		try ln("dir1/child2/grandchild1", "dir1/child2/grandchild1/link2")

		try await #expect(search("**/differentfile") == ["dir1/child2/grandchild1/differentfile"])
	}

	@Test func recursiveGlobsHandling() async throws {
		try mkdir("dir_a1/dir_a2/dir_a3")
		try touch("dir_a1/dir_a2/dir_a3/file_a")
		try mkdir("dir_b1/dir_b2/dir_b3")
		try touch("dir_b1/dir_b2/dir_b3/file_b")

		try await #expect(search("**/file_*") == ["dir_a1/dir_a2/dir_a3/file_a", "dir_b1/dir_b2/dir_b3/file_b"])
		try await #expect(search("**a3/file_*") == ["dir_a1/dir_a2/dir_a3/file_a"])
		try await #expect(
			search("**") == [
				"dir_a1/",
				"dir_a1/dir_a2/",
				"dir_a1/dir_a2/dir_a3/",
				"dir_a1/dir_a2/dir_a3/file_a",
				"dir_b1/",
				"dir_b1/dir_b2/",
				"dir_b1/dir_b2/dir_b3/",
				"dir_b1/dir_b2/dir_b3/file_b",
			]
		)
		// same issue as ``trailingSlashMatchesOnlyDirectories``
		try await #expect(
			search("**/") == [
				"dir_a1/",
				"dir_a1/dir_a2/",
				"dir_a1/dir_a2/dir_a3/",
				"dir_b1/",
				"dir_b1/dir_b2/",
				"dir_b1/dir_b2/dir_b3/",
			]
		)
		await withKnownIssue {
			// "dir_a1/dir_a2" is also being matched
			// so `/**/` should match an empty segment, but not a trailing `/**`
			try await #expect(
				search("**a2/**") == [
					"dir_a1/dir_a2/dir_a3",
					"dir_a1/dir_a2/dir_a3/file_a",
				]
			)
		}
	}

	@Test func theLiteralSegmentPathWildcardMatchesInTheSameDirectory() async throws {
		// Special behavior for https://github.com/fish-shell/fish-shell/issues/7222
		// The literal segment ** matches in the same directory.

		try mkdir("foo")
		try touch("bar", "foo/bar")

		try await #expect(
			search("**/bar") == [
				"bar",
				"foo/bar",
			]
		)
	}
}

private extension URL {
	func relativePath(from base: URL) -> String {
		// https://stackoverflow.com/a/48360631/78336

		let destComponents = self.standardizedFileURL.pathComponents
		let baseComponents = base.standardizedFileURL.pathComponents

		let componentsInCommon = zip(destComponents, baseComponents).count(where: { $0 == $1 })

		var relComponents = Array(repeating: "..", count: baseComponents.count - componentsInCommon)
		relComponents.append(contentsOf: destComponents.dropFirst(componentsInCommon))
		var path = relComponents.joined(separator: "/")

		if self.hasDirectoryPath {
			path += "/"
		}

		return path
	}
}
