import ArgumentParser
import FilenameMatcher
import Foundation
import Glob

@main
struct Benchmark: ParsableCommand {
	enum Method: String, ExpressibleByArgument {
		case swiftGlob = "swift-glob"
		case swiftFilenameMatcher = "swift-filename-matcher"
		case fnmatch
	}

	@Option(help: "The method to use for pattern matching.")
	var method: Method = .swiftGlob

	@Flag(help: "When enabled, double star patterns (ie **/.build) will not be included. fnmatch does not support path level wildcards so to accurately compare performance this needs to be enabled.")
	var excludePathLevelWildcard: Bool = false

	mutating func run() throws {
		// ~1.8m paths
		let paths = generateFolderPaths()

		var rawPatterns = [
			"level5/level4/level3/*",
			"level*/level*/level*/*",
			"level5/*/level3/*",
			"level[0-9]/level[0-9]/level[0-9]/*",
			"level?/level?/level?/*",
		]
		if !excludePathLevelWildcard {
			rawPatterns += [
				"**/*.swift",
				"**/*.txt",
				"**/.build",
				"**/*.generated.swift",
				"level5/**/level*/*.swift",
			]
		}

		let match: (String) -> Void
		switch method {
		case .swiftGlob:
			let patterns = try rawPatterns.map { try Pattern($0) }
			match = { path in
				for pattern in patterns {
					_ = pattern.match(path)
				}
			}
		case .swiftFilenameMatcher:
			let matchers = rawPatterns.map { FilenameMatcher(pattern: $0) }
			match = { path in
				for matcher in matchers {
					_ = matcher.match(filename: path)
				}
			}
		case .fnmatch:
			match = { path in
				path.withCString { path in
					for pattern in rawPatterns {
						pattern.withCString { pattern in
							_ = fnmatch(pattern, path, FNM_PATHNAME)
						}
					}
				}
			}
		}

		let clock = SuspendingClock()
		let start = clock.now

		for path in paths {
			match(path)
		}

		let end = clock.now

		let duration = start.duration(to: end)

		print("done in \(duration.formatted())")
	}
}

func generateFolderPaths(depth: Int = 6) -> [String] {
	var output: [String] = [
		"Localized.generated.swift",
		"Assets.generated.swift",
		"Assets.generated.txt",

		"Hello.swift",
		"Hello World.swift",
		"hello-world.swift",
		"hello_world.swift",
		"👋🏻 World.swift",
		"Hello🧑🏾‍💻.swift",
		"Hèllo World.swift",
		"Hello World!.swift",
		"Hello \(depth).swift",
		"HelloWorldAndToEveryoneWhoNeedsALongerFilename.swift",

		"Hello.txt",
		"Hello World.txt",
		"hello-world.txt",
		"hello_world.txt",
		"👋🏻 World.txt",
		"Hello🧑🏾‍💻.txt",
		"Hèllo World.txt",
		"Hello World!.txt",
		"Hello \(depth).txt",
		"HelloWorldAndToEveryoneWhoNeedsALongerFilename.txt",

		"Hello",
		"Hello World",
		"hello-world",
		"hello_world",
		"👋🏻 World",
		"Hello🧑🏾‍💻",
		"Hèllo World",
		"Hello World!",
		"Hello \(depth)",
		"HelloWorldAndToEveryoneWhoNeedsALongerFilename",
	]

	if depth > 0 {
		output += generateFolderPaths(depth: depth - 1).map { "Hello/" + $0 }
		output += generateFolderPaths(depth: depth - 1).map { "Hello-World/" + $0 }
		output += generateFolderPaths(depth: depth - 1).map { "Hello World/" + $0 }
		output += generateFolderPaths(depth: depth - 1).map { "HelloWorldAndToEveryoneWhoNeedsALongerFilename/" + $0 }
		output += generateFolderPaths(depth: depth - 1).map { ".build/" + $0 }
		output += generateFolderPaths(depth: depth - 1).map { "level\(depth)/" + $0 }
	}

	return output
}
