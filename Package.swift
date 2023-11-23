// swift-tools-version: 5.9

import PackageDescription

let package = Package(
	name: "swift-glob",
	platforms: [
		.macOS(.v13),
	],
	products: [
		.library(
			name: "Glob",
			targets: ["Glob"]
		),
	],
	dependencies: [
	],
	targets: [
		.target(
			name: "Glob",
			dependencies: [
			],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency"),
			]
		),
		.testTarget(
			name: "GlobTests",
			dependencies: [
				"Glob",
			]
		),
	]
)
