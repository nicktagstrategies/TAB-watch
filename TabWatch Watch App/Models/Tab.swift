import Foundation

struct Tab: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    /// Keyed by `DrinkKind.id.uuidString` so drinks can be renamed,
    /// reordered, or re-priced without invalidating open-tab counts.
    /// Orphaned entries (count for a drink that's since been deleted)
    /// are silently ignored in totals.
    var counts: [String: Int]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        counts: [String: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.counts = counts
    }

    func count(of drink: DrinkKind) -> Int {
        counts[drink.id.uuidString] ?? 0
    }

    /// Pre-tax subtotal across the given drinks. Orphaned count keys
    /// (drink was deleted while the tab was open) contribute 0.
    func total(using drinks: [DrinkKind]) -> Decimal {
        drinks.reduce(Decimal(0)) { running, drink in
            let qty = Decimal(counts[drink.id.uuidString] ?? 0)
            return running + qty * drink.price
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
