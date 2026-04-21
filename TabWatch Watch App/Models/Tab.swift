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

    func total(using prices: [DrinkKind: Decimal]) -> Decimal {
        DrinkKind.allCases.reduce(Decimal(0)) { running, kind in
            let qty = Decimal(count(of: kind))
            let price = prices[kind] ?? kind.defaultPrice
            return running + qty * price
        }
    }
}
