import SwiftUI

/// One column in the drink-counter row.
///
/// - When `count == 0`, renders a minimal "+ / icon" so the user can tap `+`
///   to start counting. The column still takes the full capsule-width slot so
///   neighbors don't jump around when you incr/decr.
/// - When `count > 0`, renders the full `+ / number / icon / -` capsule shown
///   in the mockups.
struct DrinkCounterView: View {
    let kind: DrinkKind
    let count: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        if count == 0 {
            emptyState
        } else {
            filledState
        }
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

            Image(systemName: kind.symbolName)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 28)

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

            Text("\(count)")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)

            Image(systemName: kind.symbolName)
                .font(.system(size: 16))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)

            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color(white: 0.85))
        )
    }
}
