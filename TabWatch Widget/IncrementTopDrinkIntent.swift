import AppIntents
import WidgetKit

/// Interactive widget action: increment the first configured drink on
/// the most-recent open tab. Designed for "wrist-raise, Smart Stack
/// surfaces the widget, she taps `+`" — one tap is a whole round for
/// the fastest drink.
///
/// Loads TabStore from the shared App Group suite, mutates, and asks
/// WidgetKit to reload so the count bump is reflected immediately. If
/// there's no open tab or no drinks configured, no-op.
struct IncrementTopDrinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a drink"
    static var description = IntentDescription(
        "Adds one of your default drink to the most-recent open tab."
    )

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = TabStore()
        guard let tab = store.tabs.first,
              let drink = store.drinks.first else {
            return .result()
        }
        store.increment(drink.id, for: tab.id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
