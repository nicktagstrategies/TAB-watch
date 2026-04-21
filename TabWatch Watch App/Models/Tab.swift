import Foundation

struct Tab: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date
    /// Keyed by `DrinkKind.id.uuidString` so drinks can be renamed,
    /// reordered, or re-priced without invalidating open-tab counts.
    /// Orphaned entries (count for a drink that's since been deleted)
    /// are silently ignored in totals.
    var counts: [String: Int]
    /// Snapshot of drink prices at tab creation. When populated, the tab's
    /// total uses these locked values — so a mid-shift happy-hour change
    /// doesn't retroactively alter open tabs. Nil for tabs created before
    /// this field existed (use current store prices as fallback).
    var drinkPrices: [String: Decimal]?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        counts: [String: Int] = [:],
        drinkPrices: [String: Decimal]? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.counts = counts
        self.drinkPrices = drinkPrices
    }

    func count(of drink: DrinkKind) -> Int {
        counts[drink.id.uuidString] ?? 0
    }

    /// Pre-tax subtotal across the given drinks. Uses this tab's locked
    /// price snapshot when available, falling back to the drink's current
    /// price for legacy tabs or drinks added after this tab was opened.
    func total(using drinks: [DrinkKind]) -> Decimal {
        drinks.reduce(Decimal(0)) { running, drink in
            let qty = Decimal(counts[drink.id.uuidString] ?? 0)
            let price = drinkPrices?[drink.id.uuidString] ?? drink.price
            return running + qty * price
        }
    }

    /// Tax dollar amount, rounded to cents. `taxRate` is a fraction
    /// (e.g. `0.0825` for 8.25%). Returns 0 when the rate is 0.
    func tax(using drinks: [DrinkKind], rate taxRate: Decimal) -> Decimal {
        guard taxRate > 0 else { return 0 }
        let raw = total(using: drinks) * taxRate
        var rounded = Decimal()
        var source = raw
        NSDecimalRound(&rounded, &source, 2, .plain)
        return rounded
    }

    /// Subtotal + rounded tax. This is the amount to collect.
    func totalWithTax(using drinks: [DrinkKind], rate taxRate: Decimal) -> Decimal {
        total(using: drinks) + tax(using: drinks, rate: taxRate)
    }
}
