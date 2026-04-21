import Foundation

/// A user-defined drink: name, SF Symbol for the counter icon, and price.
/// Previously an enum (Bottle / Beer / Wine) — the real-bar use case
/// needs her vocabulary, not ours. Icons are restricted to a fixed
/// palette so she isn't typing symbol strings on a watch keyboard.
struct DrinkKind: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var symbolName: String
    var price: Decimal

    init(id: UUID = UUID(), name: String, symbolName: String, price: Decimal) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.price = price
    }

    /// SF Symbols that ship on watchOS 10+ and read well at counter size.
    /// Free-form symbol names aren't an option — picking an unknown
    /// glyph would render a broken placeholder she can't diagnose on
    /// the watch.
    static let symbolPalette: [String] = [
        "mug.fill",                          // beer, draft
        "wineglass.fill",                    // wine
        "waterbottle.fill",                  // bottle / water
        "takeoutbag.and.cup.and.straw.fill", // cocktail / mixed
        "drop.fill",                         // shot
        "cup.and.heat.waves.fill",           // coffee / hot
    ]
}
