import Foundation

/// A user-defined drink: name, SF Symbol for the counter icon, and price.
/// Previously an enum (Bottle / Beer / Wine) — the real-bar use case
/// needs her vocabulary, not ours. Icons are restricted to a fixed
/// palette so she isn't typing symbol strings on a watch keyboard.
struct DrinkKind: Identifiable, Codable, Hashable, Sendable {
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

    /// SF Symbols 7 glyphs that read cleanly at counter size. Bumped from
    /// SFS 6 when we moved the project to watchOS 26 — `martiniglass.fill`
    /// replaces the (always-awkward) takeout-bag-and-straw for cocktails,
    /// and `waterbottle.fill` picks up a better bar silhouette.
    ///
    /// Free-form symbol names aren't an option — picking an unknown
    /// glyph would render a broken placeholder she can't diagnose on
    /// the watch.
    static let symbolPalette: [String] = [
        "mug.fill",              // beer, draft
        "wineglass.fill",        // wine
        "waterbottle.fill",      // bottle / water
        "martiniglass.fill",     // cocktail / mixed — SFS 7
        "drop.fill",             // shot / chaser
        "cup.and.heat.waves.fill", // coffee / hot
    ]
}
