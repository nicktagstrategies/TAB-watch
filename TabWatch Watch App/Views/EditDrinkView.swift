import SwiftUI

/// Single-screen drink editor: name, icon from a fixed palette, price.
/// Auto-saves every change via `store.updateDrink` — no "Save" button to
/// miss. If the drink is removed out from under us (rare, but e.g. swipe-
/// delete from a previous screen), this pops back.
struct EditDrinkView: View {
    let drinkID: UUID
    @EnvironmentObject private var store: TabStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let drink = store.drink(id: drinkID) {
            editor(for: drink)
                .navigationTitle(drink.name.isEmpty ? "Drink" : drink.name)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    @ViewBuilder
    private func editor(for drink: DrinkKind) -> some View {
        List {
            Section {
                TextField("Name", text: nameBinding(for: drink))
                    .font(.headline)
                    .submitLabel(.done)
            }

            Section("Icon") {
                IconGrid(selected: drink.symbolName) { symbol in
                    Haptics.click()
                    var updated = drink
                    updated.symbolName = symbol
                    store.updateDrink(updated)
                }
            }

            Section("Price") {
                Stepper(
                    value: priceBinding(for: drink),
                    in: 0...100,
                    step: 0.25
                ) {
                    HStack {
                        Text("Price")
                        Spacer()
                        Text(Self.currency(drink.price))
                            .monospacedDigit()
                    }
                }
            }

            Section {
                Button("Remove Drink", role: .destructive) {
                    Haptics.failure()
                    store.removeDrink(id: drink.id)
                    dismiss()
                }
            }
        }
    }

    private func nameBinding(for drink: DrinkKind) -> Binding<String> {
        Binding(
            get: { drink.name },
            set: { newValue in
                var updated = drink
                updated.name = newValue
                store.updateDrink(updated)
            }
        )
    }

    private func priceBinding(for drink: DrinkKind) -> Binding<Double> {
        Binding(
            get: { NSDecimalNumber(decimal: drink.price).doubleValue },
            set: { newValue in
                var updated = drink
                updated.price = Decimal(newValue)
                store.updateDrink(updated)
            }
        )
    }

    private static func currency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}

/// Fixed-palette icon picker. 3 columns fit comfortably on a 40mm watch.
private struct IconGrid: View {
    let selected: String
    let onSelect: (String) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 3
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(DrinkKind.symbolPalette, id: \.self) { symbol in
                Button {
                    onSelect(symbol)
                } label: {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(symbol == selected ? Color.black : Color.white)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(symbol == selected ? Color(white: 0.85) : Color(white: 0.2))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    let store = TabStore()
    let drink = store.drinks.first!
    return NavigationStack {
        EditDrinkView(drinkID: drink.id)
            .environmentObject(store)
    }
}
