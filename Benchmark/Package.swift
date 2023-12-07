// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Benchmark",
	platforms: [
		.macOS(.v13),
	],
	dependencies: [
		.package(path: "../"),
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.3"),

		.package(url: "https://github.com/ileitch/swift-filename-matcher.git", from: "0.1.1"),
	],
	targets: [
		.executableTarget(
			name: "Benchmark",
			dependencies: [
				.product(name: "Glob", package: "swift-glob"),
				.product(name: "ArgumentParser", package: "swift-argument-parser"),

				.product(name: "FilenameMatcher", package: "swift-filename-matcher"),
			]
		),
	]
)
