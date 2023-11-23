import SwiftUI

struct PatternsView: View {
	@Binding var patterns: [Pattern]

	@State private var isAddingPattern: Bool = false
	@State private var newPattern = ""

	var body: some View {
		VStack {
			Table(patterns) {
				TableColumn("Pattern", value: \.pattern)
			}

			HStack {
				Spacer()

				Button {
					isAddingPattern = true
				} label: {
					Image(systemName: "note.text.badge.plus")
				}
			}
		}
		.alert("New pattern", isPresented: $isAddingPattern) {
			TextField("Pattern", text: $newPattern)
			Button("Add", action: {
				guard !patterns.contains(where: { $0.pattern == newPattern }) else { return }
				patterns.append(.init(pattern: newPattern))
			})
		} message: {
			Text("Enter a glob pattern to test with.")
		}
		.onAppear {
			patterns = (UserDefaults.standard.array(forKey: "patterns") as? [String] ?? [])
				.map(Pattern.init)
		}
		.onChange(of: patterns) { _, newValue in
			UserDefaults.standard.set(newValue.map(\.pattern), forKey: "patterns")
		}
	}
}

#Preview {
	PatternsView(patterns: .constant([.init(pattern: "**/.build")]))
}
