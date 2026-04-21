import Foundation
import SwiftUI

@MainActor
final class TabStore: ObservableObject {
    @Published private(set) var tabs: [Tab] = []
    @Published var prices: [DrinkKind: Decimal] = TabStore.defaultPrices

    private let tabsKey = "TabWatch.tabs.v1"
    private let pricesKey = "TabWatch.prices.v1"
    private let defaults: UserDefaults

    static var defaultPrices: [DrinkKind: Decimal] {
        Dictionary(uniqueKeysWithValues: DrinkKind.allCases.map { ($0, $0.defaultPrice) })
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Mutations

    func addTab(name: String) -> Tab {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let tab = Tab(name: trimmed.isEmpty ? "Tab" : trimmed)
        tabs.insert(tab, at: 0)
        save()
        return tab
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

    func remove(id: Tab.ID) {
        tabs.removeAll { $0.id == id }
        save()
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
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tabs) {
            defaults.set(data, forKey: tabsKey)
        }
        if let data = try? JSONEncoder().encode(prices) {
            defaults.set(data, forKey: pricesKey)
        }
    }
}
