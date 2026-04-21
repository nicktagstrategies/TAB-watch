import SwiftUI

struct TabDetailView: View {
    let tabID: Tab.ID
    @EnvironmentObject private var store: TabStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let tab = store.tab(id: tabID) {
            content(for: tab)
                .navigationTitle(tab.name)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: Route.rename(tab.id)) {
                            Image(systemName: "pencil")
                        }
                        .accessibilityLabel("Rename tab")
                    }
                }
        } else {
            // Tab was closed out or deleted — pop back.
            Color.clear.onAppear { dismiss() }
        }
    }

    @ViewBuilder
    private func content(for tab: Tab) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                PriceHeader(
                    subtotal: tab.total(using: store.drinks),
                    tax: tab.tax(using: store.drinks, rate: store.taxRate),
                    total: tab.totalWithTax(using: store.drinks, rate: store.taxRate),
                    showsTax: store.taxRate > 0
                )

                if store.drinks.isEmpty {
                    // She removed every drink in Settings. Give her a
                    // hint rather than a blank row.
                    Text("Add a drink in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    HStack(alignment: .top, spacing: 6) {
                        ForEach(store.drinks) { drink in
                            DrinkCounterView(
                                drink: drink,
                                count: tab.count(of: drink),
                                onIncrement: {
                                    Haptics.click()
                                    store.increment(drink.id, for: tab.id)
                                },
                                onDecrement: {
                                    Haptics.click()
                                    store.decrement(drink.id, for: tab.id)
                                }
                            )
                        }
                    }
                }

                Button {
                    Haptics.success()
                    store.closeOut(id: tab.id)
                } label: {
                    Text("Close Out")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule().fill(Color(red: 0.09, green: 0.62, blue: 0.36))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .accessibilityLabel("Close out \(tab.name)")

                Button {
                    Haptics.failure()
                    store.delete(id: tab.id)
                } label: {
                    Text("Delete")
                        .font(.headline)
                        .foregroundStyle(Color.orange)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule().stroke(Color.orange, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(tab.name)")
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }
}

/// Big `$26⁵⁰` header with the dollars big and the cents as a superscript,
/// matching the first mockup. When `showsTax` is true and the tab is
/// non-empty, a small `$24.50 + $2.00 tax` caption is shown underneath.
private struct PriceHeader: View {
    let subtotal: Decimal
    let tax: Decimal
    let total: Decimal
    let showsTax: Bool

    var body: some View {
        if total > 0 {
            VStack(spacing: 2) {
                bigTotal
                if showsTax {
                    Text("\(Self.currency(subtotal)) + \(Self.currency(tax)) tax")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            // Reserve the same vertical space so the counters don't jump
            // when the first drink is added.
            Color.clear.frame(height: 40)
        }
    }

    private var bigTotal: some View {
        let amount = NSDecimalNumber(decimal: total).doubleValue
        let dollars = Int(amount)
        let cents = Int((amount - Double(dollars)) * 100 + 0.5)
        return HStack(alignment: .top, spacing: 2) {
            Text("$")
                .font(.system(size: 22, weight: .bold))
            Text("\(dollars)")
                .font(.system(size: 40, weight: .bold))
            Text(String(format: "%02d", cents))
                .font(.system(size: 20, weight: .bold))
                .baselineOffset(18)
        }
        .foregroundStyle(.white)
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

#Preview {
    let store = TabStore()
    let tab = store.addTab(name: "Johnny Appleseed")
    for drink in store.drinks.prefix(2) {
        store.increment(drink.id, for: tab.id)
    }
    return NavigationStack {
        TabDetailView(tabID: tab.id)
            .environmentObject(store)
    }
}
