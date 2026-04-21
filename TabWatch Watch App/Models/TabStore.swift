import Foundation
import SwiftUI

/// Running "sales today" rollup. Rolls over when the "business day" changes,
/// where a business day is `[shiftStartHour, shiftStartHour + 24h)` instead
/// of calendar midnight. A bartender whose shift ends at 2 AM wants 4 AM
/// rollover, not 12 AM.
struct DailySales: Codable, Equatable {
    var date: Date
    var total: Decimal
    var closedTabs: Int
    /// Dollars that walked out unpaid. Tracked separately so `total` stays a
    /// clean "sales collected" figure — managers asking for the register
    /// total shouldn't see phantom dollars.
    var lost: Decimal
    var walkers: Int
    /// Tips collected on close-out. Separate bucket so she can glance at
    /// "what did I make tonight" vs. "what did the bar ring up".
    var tips: Decimal

    static let zero = DailySales(
        date: .distantPast,
        total: 0,
        closedTabs: 0,
        lost: 0,
        walkers: 0,
        tips: 0
    )

    // Custom init keeps backward compat with rollups persisted before new
    // fields existed — missing keys decode as 0.
    enum CodingKeys: String, CodingKey {
        case date, total, closedTabs, lost, walkers, tips
    }

    init(
        date: Date,
        total: Decimal,
        closedTabs: Int,
        lost: Decimal,
        walkers: Int,
        tips: Decimal
    ) {
        self.date = date
        self.total = total
        self.closedTabs = closedTabs
        self.lost = lost
        self.walkers = walkers
        self.tips = tips
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        total = try c.decode(Decimal.self, forKey: .total)
        closedTabs = try c.decode(Int.self, forKey: .closedTabs)
        lost = try c.decodeIfPresent(Decimal.self, forKey: .lost) ?? 0
        walkers = try c.decodeIfPresent(Int.self, forKey: .walkers) ?? 0
        tips = try c.decodeIfPresent(Decimal.self, forKey: .tips) ?? 0
    }

    /// Returns `self` if `date` and `now` fall in the same business day,
    /// otherwise a fresh zero value dated to `now`.
    func rolledOver(
        to now: Date,
        shiftStartHour: Int,
        calendar: Calendar = .current
    ) -> DailySales {
        if Self.sameBusinessDay(date, now, shiftStartHour: shiftStartHour, calendar: calendar) {
            return self
        }
        return DailySales(date: now, total: 0, closedTabs: 0, lost: 0, walkers: 0, tips: 0)
    }

    /// Two dates belong to the same business day iff they share a calendar
    /// day after shifting backwards by `shiftStartHour` hours. E.g. with
    /// shiftStartHour=4, April 20 3:59 AM (shifts to April 19 11:59 PM) and
    /// April 19 10:00 PM (shifts to April 19 6:00 PM) are the same day.
    static func sameBusinessDay(
        _ a: Date,
        _ b: Date,
        shiftStartHour: Int,
        calendar: Calendar = .current
    ) -> Bool {
        let offset = -TimeInterval(shiftStartHour) * 3600
        return calendar.isDate(
            a.addingTimeInterval(offset),
            inSameDayAs: b.addingTimeInterval(offset)
        )
    }
}

/// One-slot undo buffer for Close Out / Delete. Not persisted — if the app
/// is killed, the window is gone. In memory it lives until the next
/// close-out replaces it (or `expireLastClosed` clears it past 30 s).
struct ClosedTabSnapshot: Equatable, Codable {
    let tab: Tab
    let originalIndex: Int
    /// For close-outs and walkers: the dollars to reverse on undo. Zero
    /// for plain discards.
    let collectedAmount: Decimal
    /// Tip collected alongside the close-out. Reversed on undo.
    let tipAmount: Decimal
    let closedAt: Date
    let wasDelete: Bool
    /// True when the tab was deleted as an unpaid "walker" — the
    /// collectedAmount was added to `sales.lost`, not `sales.total`.
    let wasWalker: Bool

    static let undoWindow: TimeInterval = 30
    /// How long closed tabs remain reopenable from the Recent list before
    /// being purged. Longer than the undo window since this is a "customer
    /// came back" feature, not a mis-tap safety net.
    static let recentWindow: TimeInterval = 60 * 60 * 2   // 2 hours
}

@MainActor
final class TabStore: ObservableObject {
    @Published private(set) var tabs: [Tab] = []
    /// Ordered list of drink kinds. Each carries its own price; there's no
    /// separate price dictionary. Order matters — it's the order drinks
    /// appear in the counter row.
    @Published private(set) var drinks: [DrinkKind] = TabStore.defaultDrinks
    @Published private(set) var sales: DailySales = .zero
    /// Sales-tax fraction. `0.0825` = 8.25%. Defaults to 0 so tax display
    /// only shows up once the user opts in from Settings.
    @Published private(set) var taxRate: Decimal = 0
    /// Hour (0–23) at which the "business day" rolls over. 4 AM fits a bar
    /// schedule — close-outs after midnight still count toward last night.
    @Published private(set) var shiftStartHour: Int = 4
    /// Most recent Close Out / Delete, available for undo within 30 s.
    @Published private(set) var lastClosed: ClosedTabSnapshot?
    /// Longer-lived buffer for "customer came back" reopens. Kept newest-
    /// first; pruned to `maxRecentClosures` and `ClosedTabSnapshot.recentWindow`
    /// on every access. Survives beyond the 30 s undo window.
    @Published private(set) var recentClosures: [ClosedTabSnapshot] = []

    /// Hard cap. Up to 4 are laid out in a fixed HStack; 5-8 get a
    /// horizontal ScrollView so drink tiers (well / call / premium)
    /// are reachable without crushing layout.
    static let maxDrinks = 8
    /// Upper bound on the reopen-buffer. Older entries fall off first.
    static let maxRecentClosures = 10

    private let tabsKey = "TabWatch.tabs.v2"
    private let drinksKey = "TabWatch.drinks.v1"
    private let salesKey = "TabWatch.sales.v1"
    private let taxRateKey = "TabWatch.taxRate.v1"
    private let shiftStartHourKey = "TabWatch.shiftStartHour.v1"
    private let recentClosuresKey = "TabWatch.recentClosures.v1"
    private let defaults: UserDefaults

    /// Ships with her vocabulary, not ours. She said "beers / AMFs /
    /// Jacks"; AMF is a cocktail, Jack is usually a shot.
    static var defaultDrinks: [DrinkKind] {
        [
            DrinkKind(name: "Beer",     symbolName: "mug.fill",                           price: 6.50),
            DrinkKind(name: "Shot",     symbolName: "drop.fill",                          price: 7.00),
            DrinkKind(name: "Cocktail", symbolName: "takeoutbag.and.cup.and.straw.fill",  price: 10.00),
        ]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        rollOverIfNeeded()
        pruneLegacyKeys()
    }

    /// One-time cleanup of keys from before the v2 schema bump. Cheap to
    /// run every launch; the keys are absent after the first pass.
    private func pruneLegacyKeys() {
        for legacy in ["TabWatch.tabs.v1", "TabWatch.prices.v1"] {
            if defaults.object(forKey: legacy) != nil {
                defaults.removeObject(forKey: legacy)
            }
        }
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
        let tab = Tab(
            name: trimmed.isEmpty ? nextAutoName() : trimmed,
            drinkPrices: Self.snapshotPrices(from: drinks)
        )
        tabs.insert(tab, at: 0)
        save()
        return tab
    }

    /// Captures the current drink prices keyed by drink UUID string. Used
    /// on tab creation so the tab's totals stay locked to the prices that
    /// were in effect when the customer sat down.
    static func snapshotPrices(from drinks: [DrinkKind]) -> [String: Decimal] {
        Dictionary(
            uniqueKeysWithValues: drinks.map { ($0.id.uuidString, $0.price) }
        )
    }

    func rename(id: Tab.ID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(id) { $0.name = trimmed }
    }

    private func nextAutoName() -> String {
        let prefix = "Tab "
        var used: Set<Int> = Set(tabs.compactMap { Self.parseTabNumber($0.name) })
        // Reserve the number held by a pending undo so restoring it doesn't
        // collide with a freshly-recycled "Tab 3".
        if let snap = lastClosed,
           Date().timeIntervalSince(snap.closedAt) < ClosedTabSnapshot.undoWindow,
           let n = Self.parseTabNumber(snap.tab.name) {
            used.insert(n)
        }
        var n = 1
        while used.contains(n) { n += 1 }
        return "\(prefix)\(n)"
    }

    private static func parseTabNumber(_ name: String) -> Int? {
        let prefix = "Tab "
        guard name.hasPrefix(prefix) else { return nil }
        return Int(name.dropFirst(prefix.count))
    }

    func increment(_ drinkID: UUID, for id: Tab.ID) {
        update(id) { tab in
            tab.counts[drinkID.uuidString, default: 0] += 1
        }
    }

    func decrement(_ drinkID: UUID, for id: Tab.ID) {
        update(id) { tab in
            let key = drinkID.uuidString
            let current = tab.counts[key, default: 0]
            tab.counts[key] = max(0, current - 1)
        }
    }

    /// "Close Out": removes the tab and adds the amount collected (subtotal +
    /// tax) to today's sales. Optional `tipPercent` is applied to the
    /// pre-tax subtotal and added to `sales.tips`. Use this when the
    /// customer paid. The tab is captured in `lastClosed` for a 30 s
    /// undo window and `recentClosures` for a 2 h reopen window.
    func closeOut(id: Tab.ID, tipPercent: Int? = nil) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]
        let collected = tab.totalWithTax(using: drinks, rate: taxRate)
        let tip = Self.tipAmount(on: tab.total(using: drinks), percent: tipPercent)
        rollOverIfNeeded()
        sales.total += collected
        sales.closedTabs += 1
        sales.tips += tip
        tabs.remove(at: index)
        let snap = ClosedTabSnapshot(
            tab: tab,
            originalIndex: index,
            collectedAmount: collected,
            tipAmount: tip,
            closedAt: Date(),
            wasDelete: false,
            wasWalker: false
        )
        lastClosed = snap
        recordRecentClosure(snap)
        save()
    }

    static func tipAmount(on subtotal: Decimal, percent: Int?) -> Decimal {
        guard let pct = percent, pct > 0 else { return 0 }
        var raw = subtotal * Decimal(pct) / 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 2, .plain)
        return rounded
    }

    /// "Delete": remove the tab with no accounting effect. Use for
    /// accidental opens — nothing was served.
    func delete(id: Tab.ID) {
        removeTab(id: id, asWalker: false)
    }

    /// "Walker": customer left without paying. Drinks were served, so the
    /// dollars move to `sales.lost` (NOT `sales.total`) for shift
    /// reconciliation. Undoable like any other remove.
    func markWalker(id: Tab.ID) {
        removeTab(id: id, asWalker: true)
    }

    private func removeTab(id: Tab.ID, asWalker: Bool) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]
        let wouldHaveCollected = tab.totalWithTax(using: drinks, rate: taxRate)
        tabs.remove(at: index)
        if asWalker && wouldHaveCollected > 0 {
            rollOverIfNeeded()
            sales.lost += wouldHaveCollected
            sales.walkers += 1
        }
        let snap = ClosedTabSnapshot(
            tab: tab,
            originalIndex: index,
            collectedAmount: asWalker ? wouldHaveCollected : 0,
            tipAmount: 0,
            closedAt: Date(),
            wasDelete: true,
            wasWalker: asWalker
        )
        lastClosed = snap
        recordRecentClosure(snap)
        save()
    }

    private func recordRecentClosure(_ snap: ClosedTabSnapshot) {
        recentClosures.insert(snap, at: 0)
        if recentClosures.count > Self.maxRecentClosures {
            recentClosures = Array(recentClosures.prefix(Self.maxRecentClosures))
        }
    }

    /// Drops recent closures past the 2 h window. Safe to call freely;
    /// home-screen timers drive it.
    func pruneRecentClosures(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-ClosedTabSnapshot.recentWindow)
        let filtered = recentClosures.filter { $0.closedAt >= cutoff }
        if filtered.count != recentClosures.count {
            recentClosures = filtered
            save()
        }
    }

    /// Restore a closure from the recent buffer. Reverses sales accounting
    /// only when it's still the same business day — crossing shift
    /// boundaries leaves the original shift's totals untouched (they've
    /// already been reported out).
    func reopenRecent(snapshotID: UUID) {
        guard let idx = recentClosures.firstIndex(where: { $0.tab.id == snapshotID }) else { return }
        let snap = recentClosures.remove(at: idx)
        let sameShift = DailySales.sameBusinessDay(
            snap.closedAt, Date(),
            shiftStartHour: shiftStartHour
        )
        if sameShift {
            if !snap.wasDelete {
                sales.total -= snap.collectedAmount
                sales.tips -= snap.tipAmount
                sales.closedTabs = max(0, sales.closedTabs - 1)
            } else if snap.wasWalker {
                sales.lost -= snap.collectedAmount
                sales.walkers = max(0, sales.walkers - 1)
            }
        }
        // Always insert at the top; the original index is stale after
        // minutes/hours. Auto-numbers may collide; leave the name as-is
        // and let her rename if the duplicate bothers her.
        tabs.insert(snap.tab, at: 0)
        if lastClosed?.tab.id == snap.tab.id {
            lastClosed = nil
        }
        save()
    }

    /// Moves drinks from `source` to an already-open `destination`. Counts
    /// are clamped to what the source actually has. The destination's
    /// locked prices apply to the moved drinks — matching the paying
    /// customer's price-list expectation.
    func moveDrinks(from source: Tab.ID, to destination: Tab.ID, moving: [String: Int]) {
        guard source != destination,
              let sourceIdx = tabs.firstIndex(where: { $0.id == source }),
              let destIdx = tabs.firstIndex(where: { $0.id == destination }) else { return }
        var realized: [String: Int] = [:]
        for (drinkID, qty) in moving where qty > 0 {
            let available = tabs[sourceIdx].counts[drinkID] ?? 0
            let move = min(qty, available)
            if move > 0 { realized[drinkID] = move }
        }
        guard !realized.isEmpty else { return }
        for (drinkID, qty) in realized {
            tabs[sourceIdx].counts[drinkID] = max(0, (tabs[sourceIdx].counts[drinkID] ?? 0) - qty)
            tabs[destIdx].counts[drinkID] = (tabs[destIdx].counts[drinkID] ?? 0) + qty
        }
        save()
    }

    /// Splits drinks off a tab onto a new auto-numbered tab. `moving` is
    /// keyed by `DrinkKind.id.uuidString` → count to move; counts are
    /// clamped against what the source tab actually has. The new tab
    /// inherits the source tab's locked prices so split halves charge
    /// identically.
    func splitTab(id: Tab.ID, moving: [String: Int]) {
        guard let sourceIndex = tabs.firstIndex(where: { $0.id == id }) else { return }
        let source = tabs[sourceIndex]
        // Filter out zero / negative entries and clamp to what's available.
        var realized: [String: Int] = [:]
        for (drinkID, qty) in moving where qty > 0 {
            let available = source.counts[drinkID] ?? 0
            let move = min(qty, available)
            if move > 0 { realized[drinkID] = move }
        }
        guard !realized.isEmpty else { return }
        // Subtract from source.
        for (drinkID, qty) in realized {
            let current = tabs[sourceIndex].counts[drinkID] ?? 0
            tabs[sourceIndex].counts[drinkID] = max(0, current - qty)
        }
        // New tab inherits the source's locked prices, not current drink
        // prices — so splitting a pre-happy-hour tab doesn't magically
        // re-price the split half.
        let newTab = Tab(
            name: nextAutoName(),
            counts: realized,
            drinkPrices: source.drinkPrices
        )
        tabs.insert(newTab, at: 0)
        save()
    }

    /// Restores the most recent Close Out / Delete / Walker. No-op if the
    /// 30 s window has passed or there's nothing to undo.
    func undoLast() {
        guard let snap = lastClosed else { return }
        guard Date().timeIntervalSince(snap.closedAt) < ClosedTabSnapshot.undoWindow else {
            lastClosed = nil
            return
        }
        let index = min(snap.originalIndex, tabs.count)
        tabs.insert(snap.tab, at: index)
        if !snap.wasDelete {
            // Close-out → reverse the sales bump and tip.
            sales.total -= snap.collectedAmount
            sales.tips -= snap.tipAmount
            sales.closedTabs = max(0, sales.closedTabs - 1)
        } else if snap.wasWalker {
            // Walker → reverse the loss entry.
            sales.lost -= snap.collectedAmount
            sales.walkers = max(0, sales.walkers - 1)
        }
        lastClosed = nil
        save()
    }

    /// Clears `lastClosed` once it's outside the undo window. Safe to call
    /// repeatedly — view-layer timers drive this.
    func expireLastClosedIfNeeded() {
        guard let snap = lastClosed,
              Date().timeIntervalSince(snap.closedAt) >= ClosedTabSnapshot.undoWindow else {
            return
        }
        lastClosed = nil
    }

    // MARK: - Drink mutations

    /// Appends a new drink. No-op past `maxDrinks`. Returns the new drink so
    /// callers can route to an edit screen.
    @discardableResult
    func addDrink() -> DrinkKind? {
        guard drinks.count < Self.maxDrinks else { return nil }
        let drink = DrinkKind(
            name: "New Drink",
            symbolName: DrinkKind.symbolPalette.first ?? "mug.fill",
            price: 6.00
        )
        drinks.append(drink)
        save()
        return drink
    }

    /// Removes the drink and prunes count entries from all open tabs so the
    /// subtotals don't silently ignore orphaned keys.
    func removeDrink(id: UUID) {
        drinks.removeAll { $0.id == id }
        for i in tabs.indices {
            tabs[i].counts[id.uuidString] = nil
        }
        save()
    }

    func updateDrink(_ drink: DrinkKind) {
        guard let index = drinks.firstIndex(where: { $0.id == drink.id }) else { return }
        drinks[index] = drink
        save()
    }

    func drink(id: UUID) -> DrinkKind? {
        drinks.first { $0.id == id }
    }

    // MARK: - Other settings

    /// Sets the tax rate as a fraction. Clamped to `0...0.25` (0–25%) since
    /// real rates don't go higher and it keeps Stepper UX sane.
    func setTaxRate(_ rate: Decimal) {
        taxRate = min(max(0, rate), Decimal(0.25))
        save()
    }

    /// Sets the shift-start hour. Clamped to 0–23 so day-shift bartenders
    /// (rollover at 6 PM, say) are supported alongside late-night ones.
    func setShiftStartHour(_ hour: Int) {
        shiftStartHour = min(max(0, hour), 23)
        // Re-evaluate rollover in case the new cutoff moves the boundary.
        rollOverIfNeeded()
        save()
    }

    // MARK: - Sales

    /// Manually clear today's rolled-up total. The daily auto-rollover handles
    /// this at midnight; this is for "start fresh now".
    func resetTodaysSales() {
        sales = DailySales(
            date: Date(),
            total: 0,
            closedTabs: 0,
            lost: 0,
            walkers: 0,
            tips: 0
        )
        save()
    }

    /// Public so the app entry point can call this on `scenePhase == .active`,
    /// otherwise "Today" stays stale until the next close-out.
    func rollOverIfNeeded(now: Date = Date()) {
        let rolled = sales.rolledOver(to: now, shiftStartHour: shiftStartHour)
        if rolled != sales {
            sales = rolled
        }
    }

    // MARK: - Lookups

    func tab(id: Tab.ID) -> Tab? {
        tabs.first { $0.id == id }
    }

    func total(for id: Tab.ID) -> Decimal {
        tab(id: id)?.total(using: drinks) ?? 0
    }

    func totalWithTax(for id: Tab.ID) -> Decimal {
        tab(id: id)?.totalWithTax(using: drinks, rate: taxRate) ?? 0
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
        if let data = defaults.data(forKey: drinksKey),
           let decoded = try? JSONDecoder().decode([DrinkKind].self, from: data),
           !decoded.isEmpty {
            drinks = decoded
        }
        if let data = defaults.data(forKey: tabsKey),
           let decoded = try? JSONDecoder().decode([Tab].self, from: data) {
            tabs = decoded
        }
        if let data = defaults.data(forKey: salesKey),
           let decoded = try? JSONDecoder().decode(DailySales.self, from: data) {
            sales = decoded
        }
        if let data = defaults.data(forKey: taxRateKey),
           let decoded = try? JSONDecoder().decode(Decimal.self, from: data) {
            taxRate = decoded
        }
        if let data = defaults.data(forKey: shiftStartHourKey),
           let decoded = try? JSONDecoder().decode(Int.self, from: data) {
            shiftStartHour = decoded
        }
        if let data = defaults.data(forKey: recentClosuresKey),
           let decoded = try? JSONDecoder().decode([ClosedTabSnapshot].self, from: data) {
            recentClosures = decoded
        }
        pruneRecentClosures()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tabs) {
            defaults.set(data, forKey: tabsKey)
        }
        if let data = try? JSONEncoder().encode(drinks) {
            defaults.set(data, forKey: drinksKey)
        }
        if let data = try? JSONEncoder().encode(sales) {
            defaults.set(data, forKey: salesKey)
        }
        if let data = try? JSONEncoder().encode(taxRate) {
            defaults.set(data, forKey: taxRateKey)
        }
        if let data = try? JSONEncoder().encode(shiftStartHour) {
            defaults.set(data, forKey: shiftStartHourKey)
        }
        if let data = try? JSONEncoder().encode(recentClosures) {
            defaults.set(data, forKey: recentClosuresKey)
        }
    }
}
