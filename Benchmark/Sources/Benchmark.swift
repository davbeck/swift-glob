import ArgumentParser
import Foundation
import Glob

let clock = SuspendingClock()

struct BenchmarkCase {
	let name: String
	let pattern: String
	let swiftOnly: Bool
}

let benchmarkCases: [BenchmarkCase] = [
	// Cross-implementation patterns (C, Go, Swift)
	BenchmarkCase(name: "basic", pattern: "stdlib/public/*/*.swift", swiftOnly: false),
	BenchmarkCase(name: "intermediate", pattern: "lib/SILOptimizer/*/*.cpp", swiftOnly: false),
	BenchmarkCase(name: "advanced", pattern: "lib/*/[A-Z]*.cpp", swiftOnly: false),
	// Swift-only recursive patterns
	BenchmarkCase(name: "recursive", pattern: "**/*.swift", swiftOnly: true),
	BenchmarkCase(name: "deep_recursive", pattern: "**/Optimizer/**/*.cpp", swiftOnly: true),
]

@main
struct Benchmark: AsyncParsableCommand {
	@Flag(help: "Only run patterns that all implementations support (no ** patterns)")
	var commonOnly: Bool = false

	@Argument
	var searchPath: String = FileManager.default.currentDirectoryPath

	func measure(case bc: BenchmarkCase) async throws {
		let directory = URL(filePath: searchPath).standardizedFileURL

		let start = clock.now

		let count = try await Glob.search(
			directory: directory,
			include: [Pattern(bc.pattern)]
		)
		.reduce(0) { count, _ in count + 1 }

		let end = clock.now
		let duration = start.duration(to: end)

		print("swift,\(bc.name),\(bc.pattern),\(count),\(String(format: "%.3f", duration.milliseconds))")
	}

	mutating func run() async throws {
		for bc in benchmarkCases {
			if commonOnly && bc.swiftOnly {
				continue
			}
			try await measure(case: bc)
		}
	}
}

extension Duration {
	var milliseconds: Double {
		let v = components
		return Double(v.seconds) * 1000 + Double(v.attoseconds) * 1e-15
	}
}
