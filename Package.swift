// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "swift-glob",
	platforms: [
		.macOS(.v10_15),
		.iOS(.v13),
		.tvOS(.v13),
		.watchOS(.v6),
		.macCatalyst(.v13),
		.visionOS(.v1),
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
		.target(name: "FNMDefinitions", dependencies: []),
		.target(
			name: "Glob",
			dependencies: [
				"FNMDefinitions",
			],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances"),

				.enableUpcomingFeature("ExistentialAny"),

				.enableUpcomingFeature("MemberImportVisibility"),
				.enableUpcomingFeature("InternalImportsByDefault"),
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
