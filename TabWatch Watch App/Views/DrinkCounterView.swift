import SwiftUI

/// One column in the drink-counter row.
///
/// - When `count == 0`, renders a minimal "+ / icon" so the user can tap `+`
///   to start counting. The column still takes the full capsule-width slot so
///   neighbors don't jump around when you incr/decr.
/// - When `count > 0`, renders the full `+ / number / icon / -` capsule shown
///   in the mockups.
struct DrinkCounterView: View {
    let drink: DrinkKind
    let count: Int
    /// The drink the Digital Crown is currently driving. Rendered as a
    /// thin accent ring so she can tell at a glance which column will
    /// respond to the crown.
    var isActive: Bool = false
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        Group {
            if count == 0 {
                emptyState
            } else {
                filledState
            }
        }
        .overlay(
            Group {
                if isActive {
                    Capsule()
                        .stroke(Color.accentColor, lineWidth: 2)
                }
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(drink.name)")

            Image(systemName: drink.symbolName)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 28)
                .accessibilityHidden(true)

            // Spacer that matches the height of the "minus" half of the
            // filled capsule so all three columns line up vertically.
            Color.clear.frame(height: 28)
        }
        .frame(maxWidth: .infinity)
    }

    private var filledState: some View {
        VStack(spacing: 4) {
            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(drink.name)")

            Text("\(count)")
                .font(.system(size: 32, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(count) \(drink.name)")

            Image(systemName: drink.symbolName)
                .font(.system(size: 16))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(drink.name)")
        }
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color(white: 0.85))
        )
    }
}
