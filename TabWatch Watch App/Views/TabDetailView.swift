import SwiftUI

struct TabDetailView: View {
    let tabID: Tab.ID
    @EnvironmentObject private var store: TabStore
    @Environment(\.dismiss) private var dismiss
    @State private var deleteConfirmShown = false
    @State private var closeOutConfirmShown = false
    /// Crown targets the drink she most recently tapped `+` or `-` on. On
    /// first open, defaults to the first drink.
    @State private var activeDrinkID: UUID?
    /// When the crown-active window started — set on any `+` / `-` tap.
    /// After `crownWindow` seconds of inactivity, crown input is ignored
    /// so a wrist brush doesn't silently add drinks.
    @State private var activeSince: Date?
    /// Raw crown position. Kept monotonic across a session; we apply the
    /// delta between ticks rather than the absolute value.
    @State private var crownValue: Double = 0

    /// Crown stays live for this many seconds after a +/- tap. Long enough
    /// to crank a round, short enough that idle wrist brushes don't count.
    private let crownWindow: TimeInterval = 10

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
                    // Default the target to the first drink so the crown
                    // has something to aim at — but DO NOT set activeSince,
                    // so crown stays dormant until she taps a button.
                    if activeDrinkID == nil {
                        activeDrinkID = store.drinks.first?.id
                    }
                }
        } else {
            // Tab was closed out or deleted — pop back.
            Color.clear.onAppear { dismiss() }
        }
    }

    /// Counter row. TimelineView ticks once a second so the active ring
    /// fades on its own when the crown window expires — otherwise the
    /// ring would linger on a drink the crown can no longer drive,
    /// misleading her at a glance.
    @ViewBuilder
    private func counterRow(for tab: Tab) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let liveActiveID = isCrownLive(now: context.date) ? activeDrinkID : nil
            let row = HStack(alignment: .top, spacing: 6) {
                ForEach(store.drinks) { drink in
                    DrinkCounterView(
                        drink: drink,
                        count: tab.count(of: drink),
                        isActive: drink.id == liveActiveID,
                        onIncrement: {
                            Haptics.increment()
                            activeDrinkID = drink.id
                            activeSince = Date()
                            store.increment(drink.id, for: tab.id)
                        },
                        onDecrement: {
                            Haptics.decrement()
                            activeDrinkID = drink.id
                            activeSince = Date()
                            store.decrement(drink.id, for: tab.id)
                        }
                    )
                }
            }

            // Horizontal scroll when more than 4 drinks so the 40mm watch
            // doesn't squash them past readable width.
            if store.drinks.count > 4 {
                ScrollView(.horizontal, showsIndicators: false) {
                    row.padding(.horizontal, 2)
                }
            } else {
                row
            }
        }
    }

    private func isCrownLive(now: Date) -> Bool {
        guard let since = activeSince else { return false }
        return now.timeIntervalSince(since) < crownWindow
    }

    private func applyCrownDelta(_ delta: Int, tab: Tab) {
        guard delta != 0, let drinkID = activeDrinkID else { return }
        // Ignore crown input outside the active window — wrist brushes
        // turn the crown constantly on a real watch.
        guard let since = activeSince,
              Date().timeIntervalSince(since) < crownWindow else { return }
        if delta > 0 {
            for _ in 0..<delta {
                Haptics.increment()
                store.increment(drinkID, for: tab.id)
            }
        } else {
            for _ in 0..<(-delta) {
                Haptics.decrement()
                store.decrement(drinkID, for: tab.id)
            }
        }
        // Each crown action extends the window so a slow crank doesn't time out.
        activeSince = Date()
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
                    counterRow(for: tab)
                }

                Button {
                    closeOutConfirmShown = true
                } label: {
                    Text("Close Out")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .padding(.top, 8)
                .accessibilityLabel("Close out \(tab.name)")

                // Only offered when there's something to split / move.
                if tab.counts.values.reduce(0, +) > 0 {
                    HStack(spacing: 6) {
                        NavigationLink(value: Route.split(tab.id)) {
                            Text("Split")
                                .font(.caption)
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Split \(tab.name)")

                        // Move is only useful if there's another tab to
                        // move to; hide otherwise so the bare button
                        // doesn't invite a tap that goes nowhere.
                        if store.tabs.count > 1 {
                            NavigationLink(value: Route.move(tab.id)) {
                                Text("Move")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, minHeight: 36)
                            }
                            .buttonStyle(.glass)
                            .accessibilityLabel("Move from \(tab.name)")
                        }
                    }
                }

                Button(role: .destructive) {
                    deleteConfirmShown = true
                } label: {
                    Text("Delete")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.large)
                .accessibilityLabel("Delete \(tab.name)")
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .confirmationDialog(
            closeOutTitle(for: tab),
            isPresented: $closeOutConfirmShown,
            titleVisibility: .visible
        ) {
            // Tip presets are common US bar rates. "No tip" first so the
            // default-position button matches the most common case (cash-
            // paid tabs where the tip is left separately on the counter).
            Button("No tip") { commitCloseOut(tab: tab, tipPercent: nil) }
            Button("+ 15% tip") { commitCloseOut(tab: tab, tipPercent: 15) }
            Button("+ 18% tip") { commitCloseOut(tab: tab, tipPercent: 18) }
            Button("+ 20% tip") { commitCloseOut(tab: tab, tipPercent: 20) }
            Button("+ 25% tip") { commitCloseOut(tab: tab, tipPercent: 25) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(closeOutMessage(for: tab))
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
            return "Remove \(tab.name) · \(Self.currency(total))?"
        }
        return "Remove \(tab.name)?"
    }

    private func closeOutTitle(for tab: Tab) -> String {
        "Close \(tab.name) · \(Self.currency(tab.totalWithTax(using: store.drinks, rate: store.taxRate)))?"
    }

    private func closeOutMessage(for tab: Tab) -> String {
        let subtotal = tab.total(using: store.drinks)
        guard subtotal > 0 else {
            return "Tab is empty."
        }
        // Preview each tip preset so she can see the cash amount instead
        // of multiplying in her head during a rush.
        let tips = [15, 18, 20, 25].map { pct -> String in
            let amt = TabStore.tipAmount(on: subtotal, percent: pct)
            return "\(pct)%: \(Self.currency(amt))"
        }
        return tips.joined(separator: " · ")
    }

    private func commitCloseOut(tab: Tab, tipPercent: Int?) {
        Haptics.success()
        store.closeOut(id: tab.id, tipPercent: tipPercent)
    }

    private static func currency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: value as NSDecimalNumber) ?? "$0.00"
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
        // Semantic font sizes so Dynamic Type scales the header and AOD
        // dimming preserves contrast. The 18 pt baseline offset for cents
        // stays — Dynamic Type spec doesn't offer a "superscript cents"
        // style, so we keep this typographic trick.
        return HStack(alignment: .top, spacing: 2) {
            Text("$")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text("\(dollars)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text(String(format: "%02d", cents))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .baselineOffset(14)
        }
        .foregroundStyle(.primary)
        .minimumScaleFactor(0.5)
        .lineLimit(1)
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
