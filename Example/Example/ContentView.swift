import SwiftUI

import Glob

struct Pattern: Identifiable, Equatable {
	var pattern: String

	var id: String {
		pattern
	}
}

extension URL: Identifiable {
	public var id: URL {
		self
	}
}

struct ContentView: View {
	@State private var patterns: [Pattern] = []
	@State private var searchURL: URL?

	@State private var output: [URL]?
	@State private var duration: TimeInterval?
	@State private var error: Swift.Error?

	@State private var isSearching: Bool = false

	var body: some View {
		VStack {
			PatternsView(patterns: $patterns)

			Divider()

			SearchOptionsView(searchURL: $searchURL, search: self.search)

			OutputView(searchURL: searchURL, output: output, duration: duration)
		}
		.padding()
		.disabled(isSearching)
		.alert(
			"Error",
			isPresented: .init(get: {
				error != nil
			}, set: { newValue in
				if !newValue {
					error = nil
				}
			}),
			presenting: error
		) { _ in
			Button("OK") {
				self.error = nil
			}
		} message: { error in
			Text(error.localizedDescription)
		}
	}

	private func search() {
		guard let searchURL else { return }

		isSearching = true
		let start = Date.now

		Task {
			do {
				let output = try await Glob.search(
					directory: searchURL,
					include: [],
					exclude: patterns.map { try Glob.Pattern($0.pattern) },
					skipHiddenFiles: false
				)
				.reduce(into: [URL]()) { $0.append($1) }

				let end = Date.now

				self.isSearching = false
				self.output = output
				self.duration = end.timeIntervalSince(start)
			} catch {
				self.error = error
			}
		}
	}
}

#Preview {
	ContentView()
}
