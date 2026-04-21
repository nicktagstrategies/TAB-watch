import SwiftUI

/// Everything reachable from the home screen, routed through a single
/// `navigationDestination(for:)` so the gear button, tab rows, the
/// rename sheet, and the drink editor all coexist.
enum Route: Hashable {
    case settings
    case tab(Tab.ID)
    case rename(Tab.ID)
    case editDrink(UUID)
    case split(Tab.ID)
    case move(Tab.ID)
    case recent
}

struct TabListView: View {
    @EnvironmentObject private var store: TabStore
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    header

                    ForEach(store.tabs) { tab in
                        NavigationLink(value: Route.tab(tab.id)) {
                            TabRow(tab: tab)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Haptics.click()
                        let tab = store.addTab()
                        path.append(Route.tab(tab.id))
                    } label: {
                        HStack(spacing: 6) {
                            Text("Add Tab")
                            Image(systemName: "plus")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule().stroke(Color.white, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add tab")

                    // Sits below Add Tab so the tab rows above don't shift
                    // when the banner appears for 30 s post-close.
                    UndoBanner()

                    RecentLink()
                }
                .padding(.horizontal, 4)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.settings) {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .settings:           SettingsView()
                case .tab(let id):        TabDetailView(tabID: id)
                case .rename(let id):     RenameTabView(tabID: id)
                case .editDrink(let id):  EditDrinkView(drinkID: id)
                case .split(let id):      SplitTabView(tabID: id)
                case .move(let id):       MoveTabView(tabID: id)
                case .recent:             RecentClosuresView()
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(Self.headerDateString(for: Date()))
                .font(.headline)
                .foregroundStyle(.secondary)
            if store.sales.total > 0 {
                Text("Today: \(SettingsView.currencyString(store.sales.total))")
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.09, green: 0.62, blue: 0.36))
            }
        }
        .padding(.top, 4)
    }

    /// "July 9th 2025"
    static func headerDateString(for date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "LLLL"
        let month = monthFormatter.string(from: date)
        let year = calendar.component(.year, from: date)
        return "\(month) \(day)\(ordinalSuffix(for: day)) \(year)"
    }

    private static func ordinalSuffix(for day: Int) -> String {
        switch day % 100 {
        case 11, 12, 13: return "th"
        default:
            switch day % 10 {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }
}

/// Single tab row: `Tab 3` on the left, `$14.50` on the right when the
/// tab has any drinks. Lets her spot the heavy hitter at a glance without
/// tapping in.
private struct TabRow: View {
    let tab: Tab
    @EnvironmentObject private var store: TabStore

    var body: some View {
        HStack {
            Text(tab.name)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 4)
            if subtotal > 0 {
                Text(SettingsView.currencyString(subtotal))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color(white: 0.35))
            }
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(
            Capsule().fill(Color(white: 0.85))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var subtotal: Decimal {
        tab.total(using: store.drinks)
    }

    private var accessibilityDescription: String {
        if subtotal > 0 {
            return "\(tab.name), \(SettingsView.currencyString(subtotal))"
        }
        return tab.name
    }
}

/// Transient "Undo — Tab 3 · 18s" capsule, visible for 30 s after a Close
/// Out or Delete. TimelineView drives the countdown; when the window
/// expires, the capsule asks the store to clear the snapshot so the next
/// ScrollView rebuild drops the whole view.
private struct UndoBanner: View {
    @EnvironmentObject private var store: TabStore

    var body: some View {
        if let snap = store.lastClosed {
            TimelineView(.periodic(from: snap.closedAt, by: 1)) { context in
                let elapsed = context.date.timeIntervalSince(snap.closedAt)
                let remaining = Int(ClosedTabSnapshot.undoWindow - elapsed)
                if remaining > 0 {
                    banner(for: snap, secondsLeft: remaining)
                } else {
                    Color.clear
                        .frame(height: 0)
                        .onAppear { store.expireLastClosedIfNeeded() }
                }
            }
        }
    }

    private func banner(for snap: ClosedTabSnapshot, secondsLeft: Int) -> some View {
        Button {
            Haptics.click()
            store.undoLast()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                Text("Undo — \(snap.tab.name)")
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(secondsLeft)s")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(Color(white: 0.18))
            )
            .overlay(
                Capsule().stroke(Color(white: 0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Undo close out of \(snap.tab.name), \(secondsLeft) seconds left")
    }
}

/// Subtle "Recent" link below Add Tab, surfaced only when there's
/// something to reopen within the 2 h window. Distinct from the 30 s
/// Undo banner — that handles mis-tap recovery; this handles "the
/// customer came back".
private struct RecentLink: View {
    @EnvironmentObject private var store: TabStore

    var body: some View {
        if !store.recentClosures.isEmpty {
            NavigationLink(value: Route.recent) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Recent (\(store.recentClosures.count))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Recent closures")
        }
    }
}

#Preview {
    TabListView()
        .environmentObject(TabStore())
}
