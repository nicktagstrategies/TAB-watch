import Foundation
import SwiftUI

/// Running "sales today" rollup. Resets automatically when the stored date
/// is no longer the same calendar day as `now`.
struct DailySales: Codable, Equatable {
    var date: Date
    var total: Decimal
    var closedTabs: Int

    static let zero = DailySales(date: .distantPast, total: 0, closedTabs: 0)

    /// Returns `self` if the stored date is today, otherwise a fresh zero
    /// value dated to `now`.
    func rolledOver(to now: Date, calendar: Calendar = .current) -> DailySales {
        if calendar.isDate(date, inSameDayAs: now) {
            return self
        }
        return DailySales(date: now, total: 0, closedTabs: 0)
    }
}

@MainActor
final class TabStore: ObservableObject {
    @Published private(set) var tabs: [Tab] = []
    @Published var prices: [DrinkKind: Decimal] = TabStore.defaultPrices
    @Published private(set) var sales: DailySales = .zero

    private let tabsKey = "TabWatch.tabs.v1"
    private let pricesKey = "TabWatch.prices.v1"
    private let salesKey = "TabWatch.sales.v1"
    private let defaults: UserDefaults

    static var defaultPrices: [DrinkKind: Decimal] {
        Dictionary(uniqueKeysWithValues: DrinkKind.allCases.map { ($0, $0.defaultPrice) })
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        rollOverIfNeeded()
    }

    // MARK: - Tab mutations

    /// Adds a tab with an auto-incremented name ("Tab 1", "Tab 2", ...).
    /// The next number is the smallest positive integer not currently used
    /// by an open `Tab N`-named tab, so numbers get recycled as tabs close.
    @discardableResult
    func addTab() -> Tab {
        addTab(name: nextAutoName())
    }

    @discardableResult
    func addTab(name: String) -> Tab {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let tab = Tab(name: trimmed.isEmpty ? nextAutoName() : trimmed)
        tabs.insert(tab, at: 0)
        save()
        return tab
    }

    func rename(id: Tab.ID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(id) { $0.name = trimmed }
    }

    private func nextAutoName() -> String {
        let prefix = "Tab "
        let used: Set<Int> = Set(tabs.compactMap { tab -> Int? in
            guard tab.name.hasPrefix(prefix) else { return nil }
            return Int(tab.name.dropFirst(prefix.count))
        })
        var n = 1
        while used.contains(n) { n += 1 }
        return "\(prefix)\(n)"
    }

    func increment(_ kind: DrinkKind, for id: Tab.ID) {
        update(id) { tab in
            tab.counts[kind, default: 0] += 1
        }
    }

    func decrement(_ kind: DrinkKind, for id: Tab.ID) {
        update(id) { tab in
            let current = tab.counts[kind, default: 0]
            tab.counts[kind] = max(0, current - 1)
        }
    }

    /// "Close Out": removes the tab and adds its total to today's sales.
    /// Use this when the customer paid.
    func closeOut(id: Tab.ID) {
        guard let tab = tab(id: id) else { return }
        let tabTotal = tab.total(using: prices)
        rollOverIfNeeded()
        sales.total += tabTotal
        sales.closedTabs += 1
        tabs.removeAll { $0.id == id }
        save()
    }

    /// "Delete": throw the tab away without recording the sale. Use this for
    /// mistakes.
    func delete(id: Tab.ID) {
        tabs.removeAll { $0.id == id }
        save()
    }

    // MARK: - Price mutations

    func setPrice(_ price: Decimal, for kind: DrinkKind) {
        prices[kind] = max(0, price)
        save()
    }

    // MARK: - Sales

    /// Manually clear today's rolled-up total. The daily auto-rollover handles
    /// this at midnight; this is for "start fresh now".
    func resetTodaysSales() {
        sales = DailySales(date: Date(), total: 0, closedTabs: 0)
        save()
    }

    private func rollOverIfNeeded(now: Date = Date()) {
        let rolled = sales.rolledOver(to: now)
        if rolled != sales {
            sales = rolled
        }
    }

    // MARK: - Lookups

    func tab(id: Tab.ID) -> Tab? {
        tabs.first { $0.id == id }
    }

    func total(for id: Tab.ID) -> Decimal {
        tab(id: id)?.total(using: prices) ?? 0
    }

    // MARK: - Persistence

    private func update(_ id: Tab.ID, _ mutate: (inout Tab) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        var tab = tabs[index]
        mutate(&tab)
        tabs[index] = tab
        save()
    }

    private func load() {
        if let data = defaults.data(forKey: tabsKey),
           let decoded = try? JSONDecoder().decode([Tab].self, from: data) {
            tabs = decoded
        }
        if let data = defaults.data(forKey: pricesKey),
           let decoded = try? JSONDecoder().decode([DrinkKind: Decimal].self, from: data) {
            prices = decoded
        }
        if let data = defaults.data(forKey: salesKey),
           let decoded = try? JSONDecoder().decode(DailySales.self, from: data) {
            sales = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tabs) {
            defaults.set(data, forKey: tabsKey)
        }
        if let data = try? JSONEncoder().encode(prices) {
            defaults.set(data, forKey: pricesKey)
        }
        if let data = try? JSONEncoder().encode(sales) {
            defaults.set(data, forKey: salesKey)
        }
    }
}
