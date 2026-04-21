import SwiftUI

/// "Put these drinks on *his* tab instead." Like Split, but the
/// destination is an existing open tab rather than a new auto-numbered
/// one. Destination is picked first; then a Stepper per drink decides
/// how many to move.
struct MoveTabView: View {
    let tabID: Tab.ID
    @EnvironmentObject private var store: TabStore
    @Environment(\.dismiss) private var dismiss

    @State private var destinationID: Tab.ID?
    @State private var moving: [String: Int] = [:]

    var body: some View {
        if let tab = store.tab(id: tabID) {
            content(for: tab)
                .navigationTitle("Move from \(tab.name)")
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    @ViewBuilder
    private func content(for tab: Tab) -> some View {
        let others = store.tabs.filter { $0.id != tab.id }
        if others.isEmpty {
            VStack(spacing: 8) {
                Text("No other tabs open")
                    .foregroundStyle(.secondary)
                Text("Use Split to start a new tab instead.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section("Destination") {
                    Picker("Tab", selection: destinationBinding(fallbackTo: others.first!.id)) {
                        ForEach(others) { Text($0.name).tag($0.id as Tab.ID?) }
                    }
                }

                let countedDrinks = store.drinks.filter { tab.count(of: $0) > 0 }
                if countedDrinks.isEmpty {
                    Section {
                        Text("Nothing to move.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(countedDrinks) { drink in
                            MoveDrinkRow(
                                drink: drink,
                                available: tab.count(of: drink),
                                moving: movingBinding(for: drink, tab: tab)
                            )
                        }
                    } footer: {
                        Text("Moved drinks re-price at the destination tab's locked rates.")
                            .font(.caption2)
                    }

                    if totalMoving > 0, let destID = resolvedDestinationID(fallback: others.first!.id) {
                        Section {
                            Button {
                                Haptics.success()
                                store.moveDrinks(from: tabID, to: destID, moving: moving)
                                dismiss()
                            } label: {
                                HStack {
                                    Text("Move \(totalMoving)")
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func destinationBinding(fallbackTo fallback: Tab.ID) -> Binding<Tab.ID?> {
        Binding(
            get: { destinationID ?? fallback },
            set: { destinationID = $0 }
        )
    }

    private func resolvedDestinationID(fallback: Tab.ID) -> Tab.ID? {
        destinationID ?? fallback
    }

    private func movingBinding(for drink: DrinkKind, tab: Tab) -> Binding<Int> {
        Binding(
            get: { moving[drink.id.uuidString] ?? 0 },
            set: { newValue in
                let clamped = max(0, min(newValue, tab.count(of: drink)))
                if clamped == 0 {
                    moving.removeValue(forKey: drink.id.uuidString)
                } else {
                    moving[drink.id.uuidString] = clamped
                }
            }
        )
    }

    private var totalMoving: Int {
        moving.values.reduce(0, +)
    }
}

/// Same shape as SplitDrinkRow but left private there to avoid a public
/// shared component — these views' layouts will likely diverge.
private struct MoveDrinkRow: View {
    let drink: DrinkKind
    let available: Int
    @Binding var moving: Int

    var body: some View {
        Stepper(value: $moving, in: 0...available, step: 1) {
            HStack(spacing: 6) {
                Image(systemName: drink.symbolName)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(drink.name)
                Spacer()
                Text("\(available - moving) → \(moving)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("\(drink.name). \(moving) moving of \(available).")
    }
}

#Preview {
    let store = TabStore()
    let source = store.addTab(name: "Johnny Appleseed")
    let _ = store.addTab(name: "Heather B")
    for drink in store.drinks {
        store.increment(drink.id, for: source.id)
    }
    return NavigationStack {
        MoveTabView(tabID: source.id)
            .environmentObject(store)
    }
}
