import SwiftUI

/// Single-screen drink editor: name, icon from a fixed palette, price.
/// Icon taps and Stepper ticks commit to the store immediately (discrete
/// events); the name TextField uses local `@State` and commits on submit
/// or on disappear to avoid a UserDefaults write per keystroke — which
/// also keeps the store consistent while Scribble is emitting partials.
struct EditDrinkView: View {
    let drinkID: UUID
    @EnvironmentObject private var store: TabStore
    @Environment(\.dismiss) private var dismiss

    @State private var nameDraft: String = ""
    @State private var draftLoaded = false

    var body: some View {
        if let drink = store.drink(id: drinkID) {
            editor(for: drink)
                .navigationTitle(drink.name.isEmpty ? "Drink" : drink.name)
                .onAppear {
                    // Load the draft exactly once so re-entering the view
                    // from a deeper push doesn't clobber in-progress edits.
                    if !draftLoaded {
                        nameDraft = drink.name
                        draftLoaded = true
                    }
                }
                .onDisappear { commitName() }
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    @ViewBuilder
    private func editor(for drink: DrinkKind) -> some View {
        List {
            Section {
                TextField("Name", text: $nameDraft)
                    .font(.headline)
                    .submitLabel(.done)
                    .onSubmit { commitName() }
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

    private func commitName() {
        guard let drink = store.drink(id: drinkID) else { return }
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != drink.name else { return }
        var updated = drink
        updated.name = trimmed
        store.updateDrink(updated)
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
                .accessibilityLabel(Self.label(for: symbol))
                .accessibilityAddTraits(symbol == selected ? .isSelected : [])
            }
        }
    }

    /// Human-readable VoiceOver labels for the palette. Keep in sync with
    /// `DrinkKind.symbolPalette`.
    private static func label(for symbol: String) -> String {
        switch symbol {
        case "mug.fill":                           return "Beer mug"
        case "wineglass.fill":                     return "Wine glass"
        case "waterbottle.fill":                   return "Bottle"
        case "takeoutbag.and.cup.and.straw.fill":  return "Cocktail"
        case "drop.fill":                          return "Shot"
        case "cup.and.heat.waves.fill":            return "Hot drink"
        default:                                   return symbol
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
