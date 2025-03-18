import Foundation
import Testing

@testable import Glob

class SearchTest: SearchTestUtils {
	private func pattern(_ pattern: String) throws -> Pattern {
		try Pattern(pattern, options: .default)
	}

	private func search(include: [String], exclude: [String] = []) async throws -> Set<String> {
		try await Glob.search(
			directory: directory,
			include: include.map { try self.pattern($0) },
			exclude: exclude.map { try self.pattern($0) }
		)
		.reduce(into: Set<String>()) { $0.insert($1.relativePath(from: directory)) }
	}

	@Test func searchWithExclude() async throws {
		try mkdir(
			"dirA1/dirA2",
			"dirB1/dirB2"
		)
		try touch(
			"dirA1/dirA2/fileA.swift",
			"dirB1/dirB2/fileB.swift"
		)

		try await #expect(
			search(
				include: ["**.swift"],
				exclude: ["**dirB2"]
			) == [
				"dirA1/dirA2/fileA.swift",
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
		return relComponents.joined(separator: "/")
	}
}
