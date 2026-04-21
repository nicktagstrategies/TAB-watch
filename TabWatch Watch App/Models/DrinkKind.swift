import Foundation

enum DrinkKind: String, CaseIterable, Codable, Identifiable {
    case bottle
    case beer
    case wine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottle: return "Bottle"
        case .beer:   return "Beer"
        case .wine:   return "Wine"
        }
    }

    /// SF Symbol used in the counter UI. watchOS 10+ ships all three.
    var symbolName: String {
        switch self {
        case .bottle: return "waterbottle.fill"
        case .beer:   return "mug.fill"
        case .wine:   return "wineglass.fill"
        }
    }

    /// Default price if the user hasn't customized it yet. Chosen to match
    /// the $26.50 total in the mockups (3 beers @ $6.50 + 1 wine @ $7.00 =
    /// $26.50).
    var defaultPrice: Decimal {
        switch self {
        case .bottle: return 5.00
        case .beer:   return 6.50
        case .wine:   return 7.00
        }
    }
}
