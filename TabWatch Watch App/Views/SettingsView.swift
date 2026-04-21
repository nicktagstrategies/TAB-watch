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
