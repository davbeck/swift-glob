import Foundation

class SearchTestUtils {
	let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)

	init() throws {
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	}

	func touch(_ files: String...) throws {
		for file in files {
			try Data().write(to: directory.appending(path: file))
		}
	}

	func mkdir(_ files: String...) throws {
		for file in files {
			try FileManager.default.createDirectory(
				at: directory.appending(path: file),
				withIntermediateDirectories: true
			)
		}
	}

	func ln(_ destination: String, _ source: String) throws {
		try FileManager.default.createSymbolicLink(
			at: directory.appending(path: source),
			withDestinationURL: directory.appending(path: destination)
		)
	}
}
