import SwiftUI

struct NewTabView: View {
    @EnvironmentObject private var store: TabStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        VStack(spacing: 16) {
            TextField("Name", text: $name)
                .font(.title3)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .onSubmit(addTapped)
                .padding(.horizontal)

            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(height: 1)
                .padding(.horizontal)

            Button(action: addTapped) {
                Text("Add")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        Capsule().fill(Color(white: 0.85))
                    )
            }
            .buttonStyle(.plain)
            .disabled(trimmedName.isEmpty)
            .opacity(trimmedName.isEmpty ? 0.5 : 1)
            .padding(.horizontal, 4)
        }
        .navigationTitle("Enter Name")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addTapped() {
        guard !trimmedName.isEmpty else { return }
        _ = store.addTab(name: trimmedName)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        NewTabView()
            .environmentObject(TabStore())
    }
}
