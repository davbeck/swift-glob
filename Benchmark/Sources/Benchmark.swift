import ArgumentParser
import FilenameMatcher
import Foundation
import Glob

let clock = SuspendingClock()

@main
struct Benchmark: AsyncParsableCommand {
	enum Method: String, ExpressibleByArgument {
		case swiftGlob = "swift-glob"
		case swiftFilenameMatcher = "swift-filename-matcher"
		case fnmatch
	}

	@Option(help: "The method to use for pattern matching.")
	var method: Method = .swiftGlob

	@Flag(help: "When enabled, double star patterns (ie **/.build) will not be included. fnmatch does not support path level wildcards so to accurately compare performance this needs to be enabled.")
	var excludePathLevelWildcard: Bool = false

	@Argument
	var searchPath: String = FileManager.default.currentDirectoryPath

	func measure(
		include: [String] = [],
		exclude: [String] = []
	) async throws {
		let directory = URL(filePath: searchPath).standardizedFileURL

		let start = clock.now

		let count = try await Glob.search(
			directory: directory,
			include: include.map { try Pattern($0) },
			exclude: exclude.map { try Pattern($0) }
		)
		.reduce(0) { count, _ in count + 1 }

		let end = clock.now
		let duration = start.duration(to: end)

		let description = [
			include.isEmpty ? nil : "include: \(include.joined(separator: " "))",
			exclude.isEmpty ? nil : "exclude: \(exclude.joined(separator: " "))",
		]
			.compactMap { $0 }
			.joined(separator: ", ")

		print("\(description) (\(count) files): \(duration.milliseconds)ms")
	}

	mutating func run() async throws {
		try await measure(
			include: ["**.swift"]
		)

		try await measure(
			include: ["**.swift"],
			exclude: ["**test"]
		)

		try await measure(
			include: [
				"**/*UIApplicationMain*.swift",
				"**/Optimizer/**/*.swift",
			]
		)

		try await measure(
			include: [
				"stdlib/public/**.swift",
				"**/issue-44121.swift",
				"**/Reflection/**.swift",
			]
		)

		try await measure(
			include: ["**.cpp"]
		)
	}
}

extension Duration {
	var milliseconds: Double {
		let v = components
		return Double(v.seconds) * 1000 + Double(v.attoseconds) * 1e-15
	}
}
