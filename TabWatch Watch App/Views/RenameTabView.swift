import SwiftUI

struct RenameTabView: View {
    let tabID: Tab.ID
    @EnvironmentObject private var store: TabStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 16) {
            TextField("Name", text: $name)
                .font(.title3)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .onSubmit(save)
                .padding(.horizontal)

            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(height: 1)
                .padding(.horizontal)

            Button(action: save) {
                Text("Save")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule().fill(Color(white: 0.85)))
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty)
            .opacity(trimmed.isEmpty ? 0.5 : 1)
            .padding(.horizontal, 4)
        }
        .navigationTitle("Rename")
        .onAppear {
            // Prefill once — re-entering the screen shouldn't clobber edits.
            guard !loaded, let tab = store.tab(id: tabID) else { return }
            name = tab.name
            loaded = true
        }
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        store.rename(id: tabID, to: trimmed)
        dismiss()
    }
}

#Preview {
    let store = TabStore()
    let tab = store.addTab()
    return NavigationStack {
        RenameTabView(tabID: tab.id)
            .environmentObject(store)
    }
}
