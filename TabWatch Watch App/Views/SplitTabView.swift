import SwiftUI

/// "Split off part of this tab into a new one." Common when a table wants
/// to pay separately. Shows a Stepper per drink (0…current count) for
/// "how many to move"; tapping Move creates a new auto-numbered tab with
/// the chosen drinks, inheriting the source's locked prices.
struct SplitTabView: View {
    let tabID: Tab.ID
    @EnvironmentObject private var store: TabStore
    @Environment(\.dismiss) private var dismiss

    /// drinkID.uuidString → count to move.
    @State private var moving: [String: Int] = [:]

    var body: some View {
        if let tab = store.tab(id: tabID) {
            content(for: tab)
                .navigationTitle("Split \(tab.name)")
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    @ViewBuilder
    private func content(for tab: Tab) -> some View {
        let countedDrinks = store.drinks.filter { tab.count(of: $0) > 0 }

        if countedDrinks.isEmpty {
            VStack(spacing: 8) {
                Text("Nothing to split")
                    .foregroundStyle(.secondary)
                Text("Add drinks first.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach(countedDrinks) { drink in
                        SplitDrinkRow(
                            drink: drink,
                            available: tab.count(of: drink),
                            moving: movingBinding(for: drink, tab: tab)
                        )
                    }
                } footer: {
                    Text("Drinks moved here start on a new tab at the same price.")
                        .font(.caption2)
                }

                if totalMoving > 0 {
                    Section {
                        Button {
                            Haptics.success()
                            store.splitTab(id: tabID, moving: moving)
                            dismiss()
                        } label: {
                            HStack {
                                Text("Move \(totalMoving) to new tab")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                        }
                    }
                }
            }
        }
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

/// Single row in the splitter: `Beer  2 → 1` with a Stepper bound to the
/// right-side "moving" count (0 through `available`).
private struct SplitDrinkRow: View {
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
    let tab = store.addTab(name: "Johnny Appleseed")
    for drink in store.drinks {
        store.increment(drink.id, for: tab.id)
        store.increment(drink.id, for: tab.id)
    }
    return NavigationStack {
        SplitTabView(tabID: tab.id)
            .environmentObject(store)
    }
}
