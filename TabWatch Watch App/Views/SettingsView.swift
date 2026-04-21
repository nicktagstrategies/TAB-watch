import SwiftUI

/// Top-level Settings screen. Drinks are edited via a push into
/// `EditDrinkView`; tax and shift are inline Steppers.
struct SettingsView: View {
    @EnvironmentObject private var store: TabStore

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
                    for i in indexSet {
                        store.removeDrink(id: store.drinks[i].id)
                    }
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
                Button("Reset Today", role: .destructive) {
                    store.resetTodaysSales()
                }
            }
        }
        .navigationTitle("Settings")
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
        Stepper(value: binding, in: 0...12, step: 1) {
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
        case 0:      return "12 AM"
        case 12:     return "12 PM"
        default:     return "\(hour) AM"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(TabStore())
    }
}
