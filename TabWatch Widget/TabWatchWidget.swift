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

/// Loads the same `TabStore` the watch app writes to. Widget process has
/// its own lifecycle but reads via the shared App Group UserDefaults
/// suite, so state is always fresh on reload.
struct TabWatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> TabWatchEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TabWatchEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TabWatchEntry>) -> Void) {
        // Single-entry timeline, refreshed on the next shift-boundary or
        // whenever the app writes new data (which triggers
        // WidgetCenter.shared.reloadAllTimelines()).
        let entry = currentEntry()
        completion(Timeline(entries: [entry], policy: .never))
    }

    @MainActor
    private func loadEntry() -> TabWatchEntry {
        let store = TabStore()
        let top = store.tabs.first
        return TabWatchEntry(
            date: Date(),
            todaysTotal: store.sales.total,
            todaysTips: store.sales.tips,
            openTabCount: store.tabs.count,
            topTab: top.map { tab in
                let first = store.drinks.first
                return TabWatchEntry.TopTab(
                    id: tab.id,
                    name: tab.name,
                    total: tab.total(using: store.drinks),
                    firstDrink: first.map {
                        TabWatchEntry.FirstDrink(id: $0.id, name: $0.name, symbolName: $0.symbolName)
                    }
                )
            }
        )
    }

    private func currentEntry() -> TabWatchEntry {
        // MainActor bridge — TimelineProvider methods aren't isolated, but
        // TabStore is @MainActor. `MainActor.assumeIsolated` on watchOS 26
        // is safe from widget callback context.
        MainActor.assumeIsolated { loadEntry() }
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
