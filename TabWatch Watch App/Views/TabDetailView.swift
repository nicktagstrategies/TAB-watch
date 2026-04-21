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
                    subtotal: tab.total(using: store.prices),
                    tax: tab.tax(using: store.prices, rate: store.taxRate),
                    total: tab.totalWithTax(using: store.prices, rate: store.taxRate),
                    showsTax: store.taxRate > 0
                )

                HStack(alignment: .top, spacing: 6) {
                    ForEach(DrinkKind.allCases) { kind in
                        DrinkCounterView(
                            kind: kind,
                            count: tab.count(of: kind),
                            onIncrement: {
                                Haptics.click()
                                store.increment(kind, for: tab.id)
                            },
                            onDecrement: {
                                Haptics.click()
                                store.decrement(kind, for: tab.id)
                            }
                        )
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
    store.increment(.beer, for: tab.id)
    store.increment(.beer, for: tab.id)
    store.increment(.beer, for: tab.id)
    store.increment(.wine, for: tab.id)
    return NavigationStack {
        TabDetailView(tabID: tab.id)
            .environmentObject(store)
    }
}
