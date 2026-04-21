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
                PriceHeader(total: tab.total(using: store.prices))

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
/// matching the first mockup. Hidden when the tab is empty.
private struct PriceHeader: View {
    let total: Decimal

    var body: some View {
        let amount = NSDecimalNumber(decimal: total).doubleValue
        let dollars = Int(amount)
        let cents = Int((amount - Double(dollars)) * 100 + 0.5)

        if total > 0 {
            HStack(alignment: .top, spacing: 2) {
                Text("$")
                    .font(.system(size: 22, weight: .bold))
                Text("\(dollars)")
                    .font(.system(size: 40, weight: .bold))
                Text(String(format: "%02d", cents))
                    .font(.system(size: 20, weight: .bold))
                    .baselineOffset(18)
            }
            .foregroundStyle(.white)
        } else {
            // Reserve the same vertical space so the counters don't jump
            // when the first drink is added.
            Color.clear.frame(height: 40)
        }
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
