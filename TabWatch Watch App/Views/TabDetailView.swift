import SwiftUI

struct TabDetailView: View {
    let tabID: Tab.ID
    @EnvironmentObject private var store: TabStore
    @Environment(\.dismiss) private var dismiss
    @State private var deleteConfirmShown = false
    /// Crown targets the drink she most recently tapped `+` or `-` on. On
    /// first open, defaults to the first drink.
    @State private var activeDrinkID: UUID?
    /// Raw crown position. Kept monotonic across a session; we apply the
    /// delta between ticks rather than the absolute value.
    @State private var crownValue: Double = 0

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
                .focusable(true)
                .digitalCrownRotation(
                    $crownValue,
                    from: -10000, through: 10000, by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                .onChange(of: crownValue) { old, new in
                    applyCrownDelta(Int(new - old), tab: tab)
                }
                .onAppear {
                    if activeDrinkID == nil {
                        activeDrinkID = store.drinks.first?.id
                    }
                }
        } else {
            // Tab was closed out or deleted — pop back.
            Color.clear.onAppear { dismiss() }
        }
    }

    private func applyCrownDelta(_ delta: Int, tab: Tab) {
        guard delta != 0, let drinkID = activeDrinkID else { return }
        if delta > 0 {
            for _ in 0..<delta { store.increment(drinkID, for: tab.id) }
        } else {
            for _ in 0..<(-delta) { store.decrement(drinkID, for: tab.id) }
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
                                isActive: drink.id == activeDrinkID,
                                onIncrement: {
                                    Haptics.click()
                                    activeDrinkID = drink.id
                                    store.increment(drink.id, for: tab.id)
                                },
                                onDecrement: {
                                    Haptics.click()
                                    activeDrinkID = drink.id
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

                // Only offered when there's something to split off.
                if tab.counts.values.reduce(0, +) > 0 {
                    NavigationLink(value: Route.split(tab.id)) {
                        Text("Split")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                Capsule().stroke(Color.white, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Split \(tab.name)")
                }

                Button {
                    deleteConfirmShown = true
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
        .confirmationDialog(
            deleteConfirmTitle(for: tab),
            isPresented: $deleteConfirmShown,
            titleVisibility: .visible
        ) {
            // "Walker" only makes sense when drinks were served. For a $0
            // tab (accidental open), skip straight to Discard.
            if tab.totalWithTax(using: store.drinks, rate: store.taxRate) > 0 {
                Button("Walker (unpaid)", role: .destructive) {
                    Haptics.failure()
                    store.markWalker(id: tab.id)
                }
            }
            Button("Discard", role: .destructive) {
                Haptics.failure()
                store.delete(id: tab.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Undo is available for 30 s on the home screen.")
        }
    }

    private func deleteConfirmTitle(for tab: Tab) -> String {
        let total = tab.totalWithTax(using: store.drinks, rate: store.taxRate)
        if total > 0 {
            return "Remove \(tab.name) · $\(NSDecimalNumber(decimal: total).stringValue)?"
        }
        return "Remove \(tab.name)?"
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
