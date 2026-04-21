import SwiftUI

/// Top-level Settings screen. Drinks are edited via a push into
/// `EditDrinkView`; tax and shift are inline Steppers.
struct SettingsView: View {
    @EnvironmentObject private var store: TabStore
    @State private var resetConfirmShown = false
    @State private var pendingDrinkDeletion: IndexSet?

    var body: some View {
        List {
            Section("Drinks") {
                ForEach(store.drinks) { drink in
                    NavigationLink(value: Route.editDrink(drink.id)) {
                        HStack {
                            Image(systemName: drink.symbolName)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(drink.name)
                            Spacer()
                            Text(Self.currencyString(drink.price))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    // Stash the deletion and confirm — swipe-delete drops
                    // the drink AND prunes counts from every open tab, so
                    // a pocket-gesture shouldn't be able to trigger it
                    // silently.
                    pendingDrinkDeletion = indexSet
                }

                if store.drinks.count < TabStore.maxDrinks {
                    Button {
                        Haptics.click()
                        store.addDrink()
                    } label: {
                        Label("Add Drink", systemImage: "plus")
                    }
                }
            }

            Section("Tax") {
                TaxRateRow()
            }

            Section("Shift") {
                ShiftStartRow()
            }

            Section("Today") {
                HStack {
                    Text("Sales")
                    Spacer()
                    Text(Self.currencyString(store.sales.total))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Tabs Closed")
                    Spacer()
                    Text("\(store.sales.closedTabs)")
                        .foregroundStyle(.secondary)
                }
                if store.sales.tips > 0 {
                    HStack {
                        Text("Tips")
                        Spacer()
                        Text(Self.currencyString(store.sales.tips))
                            .foregroundStyle(Color(red: 0.09, green: 0.62, blue: 0.36))
                            .monospacedDigit()
                    }
                }
                if store.sales.walkers > 0 {
                    HStack {
                        Text("Walkers")
                        Spacer()
                        Text("\(store.sales.walkers) · \(Self.currencyString(store.sales.lost))")
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                    }
                }
                Button("Reset Today", role: .destructive) {
                    resetConfirmShown = true
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Reset today's sales?",
            isPresented: $resetConfirmShown,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                Haptics.failure()
                store.resetTodaysSales()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears \(Self.currencyString(store.sales.total)) and \(store.sales.closedTabs) closed tabs.")
        }
        .confirmationDialog(
            drinkDeletionTitle,
            isPresented: drinkDeletionPresented,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                guard let indexSet = pendingDrinkDeletion else { return }
                Haptics.failure()
                for i in indexSet {
                    if i < store.drinks.count {
                        store.removeDrink(id: store.drinks[i].id)
                    }
                }
                pendingDrinkDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDrinkDeletion = nil
            }
        } message: {
            Text(drinkDeletionMessage)
        }
    }

    // `.confirmationDialog(isPresented:)` wants a stable Bool binding; we
    // derive one from the optional IndexSet so the dialog closes when we
    // reset it to nil.
    private var drinkDeletionPresented: Binding<Bool> {
        Binding(
            get: { pendingDrinkDeletion != nil },
            set: { if !$0 { pendingDrinkDeletion = nil } }
        )
    }

    private var drinkDeletionTitle: String {
        guard let first = pendingDrinkDeletion?.first,
              first < store.drinks.count else { return "Remove drink?" }
        return "Remove \(store.drinks[first].name)?"
    }

    private var drinkDeletionMessage: String {
        guard let indexSet = pendingDrinkDeletion else { return "" }
        let affected = indexSet
            .compactMap { $0 < store.drinks.count ? store.drinks[$0].id : nil }
        var totalCount = 0
        for tab in store.tabs {
            for id in affected {
                totalCount += tab.counts[id.uuidString] ?? 0
            }
        }
        if totalCount > 0 {
            return "\(totalCount) counted on open tabs will be dropped."
        }
        return "This can't be undone."
    }

    static func currencyString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}

/// Tax-rate Stepper in 0.125% steps, range 0–15%. Display rounds to 3
/// decimal places so rates like 8.875% (NYC) render cleanly.
private struct TaxRateRow: View {
    @EnvironmentObject private var store: TabStore

    var body: some View {
        Stepper(value: binding, in: 0...15, step: 0.125) {
            HStack {
                Text("Rate")
                Spacer()
                Text(formatted)
                    .monospacedDigit()
                    .foregroundStyle(store.taxRate > 0 ? .primary : .secondary)
            }
        }
    }

    private var currentPercent: Double {
        NSDecimalNumber(decimal: store.taxRate * 100).doubleValue
    }

    private var binding: Binding<Double> {
        Binding(
            get: { currentPercent },
            set: { store.setTaxRate(Decimal($0) / 100) }
        )
    }

    private var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        let number = NSNumber(value: currentPercent)
        return (formatter.string(from: number) ?? "0") + "%"
    }
}

/// When the "business day" rolls over. Default 4 AM — a bartender closing
/// out at 1:30 AM still wants those sales on the same shift total.
private struct ShiftStartRow: View {
    @EnvironmentObject private var store: TabStore

    var body: some View {
        Stepper(value: binding, in: 0...23, step: 1) {
            HStack {
                Text("Day starts")
                Spacer()
                Text(Self.hourLabel(store.shiftStartHour))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var binding: Binding<Int> {
        Binding(
            get: { store.shiftStartHour },
            set: { store.setShiftStartHour($0) }
        )
    }

    static func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0:         return "12 AM"
        case 12:        return "12 PM"
        case 1...11:    return "\(hour) AM"
        case 13...23:   return "\(hour - 12) PM"
        default:        return "\(hour):00"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(TabStore())
    }
}
