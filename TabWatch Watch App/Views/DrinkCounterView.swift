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
        // Bare "+" + icon, no surface — the invitation to start counting.
        // A glass capsule here would read as "this column is already in
        // use", contradicting the count-zero signal.
        VStack(spacing: 10) {
            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(.title2, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(drink.name)")
            // Active column is the watchOS Double Tap target — pour a
            // beer, double-tap your fist, `+`. Only one primary action
            // per view, so we gate on isActive.
            .modifier(PrimaryActionIf(enabled: isActive))

            Image(systemName: drink.symbolName)
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: 28)
                .accessibilityHidden(true)

            // Matches the filled capsule's "-" half so columns line up.
            Color.clear.frame(height: 28)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
    }

    private var filledState: some View {
        VStack(spacing: 4) {
            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(.title3, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(drink.name)")
            .modifier(PrimaryActionIf(enabled: isActive))

            Text("\(count)")
                .font(.system(.title, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(count) \(drink.name)")

            Image(systemName: drink.symbolName)
                .font(.caption)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.system(.title3, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(drink.name)")
        }
        // High-contrast black content on a white-tinted interactive glass
        // capsule. Matches the original mockups' "filled = focal point"
        // feel, and picks up AOD + motion refraction for free.
        .foregroundStyle(.black)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(.white).interactive(), in: .capsule)
    }
}

/// Conditional `.handGestureShortcut(.primaryAction)` — only the active
/// drink's `+` gets wired to Double Tap, since watchOS allows a single
/// primary-action target per view hierarchy.
private struct PrimaryActionIf: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.handGestureShortcut(.primaryAction)
        } else {
            content
        }
    }
}
