import SwiftUI
import WidgetKit

/// Entry driving every complication family: today's total, how many open
/// tabs, and the top (most-recent) tab's summary for the rectangular /
/// Smart Stack layout.
struct TabWatchEntry: TimelineEntry {
    let date: Date
    let todaysTotal: Decimal
    let todaysTips: Decimal
    let openTabCount: Int
    /// Most-recent open tab, if any. Drives the rectangular family + the
    /// interactive `+` button on Smart Stack.
    let topTab: TopTab?

    struct TopTab {
        let id: UUID
        let name: String
        let total: Decimal
        /// First configured drink — the Smart Stack `+` button targets this.
        let firstDrink: FirstDrink?
    }

    struct FirstDrink {
        let id: UUID
        let name: String
        let symbolName: String
    }

    static let placeholder = TabWatchEntry(
        date: .now,
        todaysTotal: 142.50,
        todaysTips: 22.75,
        openTabCount: 3,
        topTab: TopTab(
            id: UUID(),
            name: "Tab 3",
            total: 47.00,
            firstDrink: FirstDrink(id: UUID(), name: "Beer", symbolName: "mug.fill")
        )
    )
}

/// Loads the shared UserDefaults suite the watch app writes on every
/// save. Nonisolated so it's safe to call from TimelineProvider methods
/// which WidgetKit invokes on arbitrary queues. Reads a subset of keys
/// rather than instantiating the full `TabStore` to keep widget launch
/// cheap and avoid MainActor plumbing.
enum WidgetDataReader {
    static func currentEntry() -> TabWatchEntry {
        let defaults = UserDefaults(suiteName: TabStore.appGroupID) ?? .standard

        let tabs: [Tab]             = decode(key: "TabWatch.tabs.v2",   from: defaults) ?? []
        let drinks: [DrinkKind]     = decode(key: "TabWatch.drinks.v1", from: defaults) ?? TabStore.defaultDrinks
        let sales: DailySales       = decode(key: "TabWatch.sales.v1",  from: defaults) ?? .zero

        let topTabModel = tabs.first
        let firstDrinkModel = drinks.first
        return TabWatchEntry(
            date: Date(),
            todaysTotal: sales.total,
            todaysTips: sales.tips,
            openTabCount: tabs.count,
            topTab: topTabModel.map { tab in
                TabWatchEntry.TopTab(
                    id: tab.id,
                    name: tab.name,
                    total: tab.total(using: drinks),
                    firstDrink: firstDrinkModel.map {
                        TabWatchEntry.FirstDrink(id: $0.id, name: $0.name, symbolName: $0.symbolName)
                    }
                )
            }
        )
    }

    private static func decode<T: Decodable>(key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

struct TabWatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> TabWatchEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TabWatchEntry) -> Void) {
        completion(WidgetDataReader.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TabWatchEntry>) -> Void) {
        // Single-entry timeline, refreshed on demand: the app calls
        // WidgetCenter.shared.reloadAllTimelines() from TabStore.save()
        // so counts update immediately after a mutation.
        let entry = WidgetDataReader.currentEntry()
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct TabWatchWidget: Widget {
    let kind = "TabWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TabWatchProvider()) { entry in
            TabWatchWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("TabWatch")
        .description("Today's sales and your top open tab.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

struct TabWatchWidgetView: View {
    let entry: TabWatchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:   CircularView(entry: entry)
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryInline:     InlineView(entry: entry)
        case .accessoryCorner:     CornerView(entry: entry)
        default:                   InlineView(entry: entry)
        }
    }
}

// MARK: - Family views

private struct CircularView: View {
    let entry: TabWatchEntry

    var body: some View {
        // Compact: big dollar amount for today, tab count below. Favors
        // the shift-total glance since that's the most-asked question.
        VStack(spacing: 0) {
            Text(Self.compactCurrency(entry.todaysTotal))
                .font(.system(.headline, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("\(entry.openTabCount) open")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .widgetAccentable()
    }

    /// "$142" or "$1.2k" so it fits the accessoryCircular well. Cents are
    /// dropped since the glance is about magnitude, not reconciliation.
    static func compactCurrency(_ value: Decimal) -> String {
        let dollars = (value as NSDecimalNumber).intValue
        if dollars >= 1000 {
            let thousands = Double(dollars) / 1000.0
            return String(format: "$%.1fk", thousands)
        }
        return "$\(dollars)"
    }
}

private struct RectangularView: View {
    let entry: TabWatchEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Line 1: today's shift
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.tint)
                Text(formattedTotal)
                    .font(.headline)
                    .monospacedDigit()
                Spacer(minLength: 4)
                if entry.todaysTips > 0 {
                    Text("+ \(formattedTips) tips")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            // Line 2 + 3: top tab + inline `+` button
            if let top = entry.topTab {
                HStack(spacing: 4) {
                    Text(top.name)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(formattedCurrency(top.total))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let drink = top.firstDrink {
                        Button(intent: IncrementTopDrinkIntent()) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add \(drink.name) to \(top.name)")
                    }
                }
            } else {
                Text("No open tabs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "tabwatch://home"))
    }

    private var formattedTotal: String {
        formattedCurrency(entry.todaysTotal)
    }

    private var formattedTips: String {
        formattedCurrency(entry.todaysTips)
    }

    private func formattedCurrency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}

private struct InlineView: View {
    let entry: TabWatchEntry

    var body: some View {
        // Single-line layouts are text-only on watchOS — iconography is
        // dropped in favor of glanceable data.
        if let top = entry.topTab {
            Text("\(top.name) · \(CircularView.compactCurrency(top.total)) · Today \(CircularView.compactCurrency(entry.todaysTotal))")
        } else {
            Text("TabWatch · Today \(CircularView.compactCurrency(entry.todaysTotal))")
        }
    }
}

private struct CornerView: View {
    let entry: TabWatchEntry

    var body: some View {
        Text(CircularView.compactCurrency(entry.todaysTotal))
            .font(.system(.caption, design: .rounded, weight: .bold))
            .widgetLabel {
                Text("\(entry.openTabCount) open · today")
                    .monospacedDigit()
            }
    }
}

#Preview(as: .accessoryCircular) {
    TabWatchWidget()
} timeline: {
    TabWatchEntry.placeholder
}

#Preview(as: .accessoryRectangular) {
    TabWatchWidget()
} timeline: {
    TabWatchEntry.placeholder
}
