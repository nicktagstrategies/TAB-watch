import SwiftUI

/// "Customer came back." List of recent Close Out / Walker / Discard
/// snapshots, tappable to restore. Separate from the 30 s on-home undo
/// banner — this is the 2-hour "whoops they returned" window.
struct RecentClosuresView: View {
    @EnvironmentObject private var store: TabStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Timeline ticks so "5 min ago" labels update and expired items
        // disappear without a manual refresh.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            List {
                let items = activeClosures(now: context.date)
                if items.isEmpty {
                    Text("Nothing to reopen in the last 2 hours.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items, id: \.tab.id) { snap in
                        row(for: snap, now: context.date)
                    }
                }
            }
            .navigationTitle("Recent")
        }
    }

    private func activeClosures(now: Date) -> [ClosedTabSnapshot] {
        let cutoff = now.addingTimeInterval(-ClosedTabSnapshot.recentWindow)
        return store.recentClosures.filter { $0.closedAt >= cutoff }
    }

    private func row(for snap: ClosedTabSnapshot, now: Date) -> some View {
        Button {
            Haptics.click()
            store.reopenRecent(snapshotID: snap.tab.id)
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: snap.wasDelete
                      ? (snap.wasWalker ? "figure.walk" : "trash")
                      : "checkmark.circle.fill")
                    .foregroundStyle(snap.wasDelete
                                     ? (snap.wasWalker ? Color.orange : Color.secondary)
                                     : Color.green)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(snap.tab.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle(for: snap, now: now))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Reopen \(snap.tab.name)")
    }

    private func subtitle(for snap: ClosedTabSnapshot, now: Date) -> String {
        let ago = Self.relative(from: snap.closedAt, to: now)
        if snap.wasDelete {
            let label = snap.wasWalker ? "Walker" : "Discard"
            let amount = snap.wasWalker ? " · \(Self.currency(snap.collectedAmount))" : ""
            return "\(label)\(amount) · \(ago)"
        }
        return "\(Self.currency(snap.collectedAmount)) · \(ago)"
    }

    private static func relative(from: Date, to now: Date) -> String {
        let secs = Int(now.timeIntervalSince(from))
        if secs < 60 { return "just now" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return m > 0 ? "\(h)h \(m)m ago" : "\(h)h ago"
    }

    private static func currency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}

#Preview {
    NavigationStack {
        RecentClosuresView()
            .environmentObject(TabStore())
    }
}
