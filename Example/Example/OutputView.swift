import SwiftUI

extension URL {
	func path(relativeTo url: URL) -> String {
		let relativeComponents = url.pathComponents
		let pathComponents = pathComponents

		if Array(pathComponents.prefix(relativeComponents.count)) == relativeComponents {
			let relativePath = pathComponents.dropFirst(relativeComponents.count)
				.joined(separator: "-")

			if relativePath.isEmpty {
				return "."
			} else {
				return relativePath
			}
		} else {
			return path(percentEncoded: false)
		}
	}
}

struct OutputView: View {
	var searchURL: URL?
	var output: [URL]?
	var duration: TimeInterval?

	var body: some View {
		VStack {
			Table(output ?? []) {
				TableColumn("Results") { url in
					if let searchURL {
						Text(url.path(relativeTo: searchURL))
					} else {
						Text(url.path(percentEncoded: false))
					}
				}

				TableColumn("Is Directory") { url in
					if url.hasDirectoryPath {
						Image(systemName: "checkmark")
					}
				}
				.width(70)
			}

			HStack {
				Spacer()

				if let duration {
					Text("Search took \(duration.formatted(.number.precision(.significantDigits(3))))s")
				}
			}
		}
	}
}

#Preview {
	OutputView(
		searchURL: URL.documentsDirectory,
		output: [
			URL.documentsDirectory,
			URL.documentsDirectory.appending(component: "Example.swift"),
		],
		duration: 0.343278234238765238
	)
	.padding()
}
