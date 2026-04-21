import SwiftUI

/// Price editor. One Stepper per drink, turned via the digital crown.
/// Defaults to $0.25 increments; hold the crown for fast scrubbing.
struct SettingsView: View {
    @EnvironmentObject private var store: TabStore

    var body: some View {
        List {
            Section("Prices") {
                ForEach(DrinkKind.allCases) { kind in
                    PriceRow(kind: kind)
                }
            }

            Section("Tax") {
                TaxRateRow()
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

private struct PriceRow: View {
    let kind: DrinkKind
    @EnvironmentObject private var store: TabStore

    var body: some View {
        Stepper(value: binding, in: 0...100, step: 0.25) {
            HStack {
                Image(systemName: kind.symbolName)
                    .foregroundStyle(.secondary)
                Text(kind.displayName)
                Spacer()
                Text(SettingsView.currencyString(Decimal(currentPrice)))
                    .monospacedDigit()
            }
        }
    }

    private var currentPrice: Double {
        let decimal = store.prices[kind] ?? kind.defaultPrice
        return NSDecimalNumber(decimal: decimal).doubleValue
    }

    private var binding: Binding<Double> {
        Binding(
            get: { currentPrice },
            set: { store.setPrice(Decimal($0), for: kind) }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(TabStore())
    }
}
