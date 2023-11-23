import SwiftUI

struct SearchOptionsView: View {
	@Binding var searchURL: URL?
	var search: () -> Void

	var body: some View {
		HStack {
			Button {
				let folderPicker = NSOpenPanel()
				folderPicker.canChooseDirectories = true
				folderPicker.canChooseFiles = false
				folderPicker.allowsMultipleSelection = false
				folderPicker.begin { response in
					guard response == .OK else { return }
					self.searchURL = folderPicker.urls.first
				}
			} label: {
				Text("Select directory...")
			}

			Text(searchURL?.path(percentEncoded: false) ?? "")
				.frame(maxWidth: .infinity, alignment: .leading)

			Button {
				self.search()
			} label: {
				Text("Search")
			}
		}
		.onAppear {
			do {
				guard let bookmarkData = UserDefaults.standard.data(forKey: "searchDirectory") else { return }
				var bookmarkDataIsStale: Bool = false
				self.searchURL = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &bookmarkDataIsStale)
			} catch {
				print("unable to load bookmark", error)
			}
		}
		.onChange(of: searchURL) { _, newValue in
			do {
				guard let newValue else { return }
				let bookmarkData = try newValue.bookmarkData()
				UserDefaults.standard.set(bookmarkData, forKey: "searchDirectory")
			} catch {
				print("unable to save bookmark", error)
			}
		}
	}
}

#Preview {
	SearchOptionsView(searchURL: .constant(nil), search: {})
}
