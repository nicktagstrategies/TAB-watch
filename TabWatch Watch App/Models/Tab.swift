import Foundation

struct Tab: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var counts: [DrinkKind: Int]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        counts: [DrinkKind: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.counts = counts
    }

    func count(of kind: DrinkKind) -> Int {
        counts[kind] ?? 0
    }

    /// Pre-tax subtotal.
    func total(using prices: [DrinkKind: Decimal]) -> Decimal {
        DrinkKind.allCases.reduce(Decimal(0)) { running, kind in
            let qty = Decimal(count(of: kind))
            let price = prices[kind] ?? kind.defaultPrice
            return running + qty * price
        }
    }

    /// Tax dollar amount, rounded to cents. `taxRate` is a fraction
    /// (e.g. `0.0825` for 8.25%). Returns 0 when the rate is 0.
    func tax(using prices: [DrinkKind: Decimal], rate taxRate: Decimal) -> Decimal {
        guard taxRate > 0 else { return 0 }
        let raw = total(using: prices) * taxRate
        var rounded = Decimal()
        var source = raw
        NSDecimalRound(&rounded, &source, 2, .plain)
        return rounded
    }

    /// Subtotal + rounded tax. This is the amount to collect.
    func totalWithTax(using prices: [DrinkKind: Decimal], rate taxRate: Decimal) -> Decimal {
        total(using: prices) + tax(using: prices, rate: taxRate)
    }
}
