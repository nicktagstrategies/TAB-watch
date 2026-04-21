import SwiftUI

/// Everything reachable from the home screen, routed through a single
/// `navigationDestination(for:)` so multiple push sources coexist.
enum Route: Hashable {
    case newTab
    case settings
    case tab(Tab.ID)
}

struct TabListView: View {
    @EnvironmentObject private var store: TabStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header

                ForEach(store.tabs) { tab in
                    NavigationLink(value: Route.tab(tab.id)) {
                        Text(tab.name)
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                Capsule().fill(Color(white: 0.85))
                            )
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink(value: Route.newTab) {
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
            }
            .padding(.horizontal, 4)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.settings) {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .newTab:        NewTabView()
            case .settings:      SettingsView()
            case .tab(let id):   TabDetailView(tabID: id)
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

#Preview {
    NavigationStack {
        TabListView()
            .environmentObject(TabStore())
    }
}
