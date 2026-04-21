import SwiftUI

struct TabListView: View {
    @EnvironmentObject private var store: TabStore
    @State private var showingNewTab = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(Self.headerDateString(for: Date()))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                ForEach(store.tabs) { tab in
                    NavigationLink(value: tab.id) {
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

                Button {
                    showingNewTab = true
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
            }
            .padding(.horizontal, 4)
        }
        .navigationDestination(isPresented: $showingNewTab) {
            NewTabView()
        }
        .navigationDestination(for: Tab.ID.self) { tabID in
            TabDetailView(tabID: tabID)
        }
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
