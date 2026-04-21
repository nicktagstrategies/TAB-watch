import WatchKit

/// Thin wrapper around `WKInterfaceDevice` so call sites don't have to import
/// WatchKit and so Swift 6's strict concurrency checker knows these are
/// main-actor-isolated (WKInterfaceDevice is not Sendable).
@MainActor
enum Haptics {
    /// Generic tap — used for button presses without a +/- direction.
    static func click()      { WKInterfaceDevice.current().play(.click) }
    /// Success chirp — Close Out.
    static func success()    { WKInterfaceDevice.current().play(.success) }
    /// Failure buzz — walker / discard.
    static func failure()    { WKInterfaceDevice.current().play(.failure) }
    /// Directional up tick — `+` taps on drink counters, crown increments.
    /// Distinct from `click()` so a bartender feels "up vs down" without
    /// looking.
    static func increment()  { WKInterfaceDevice.current().play(.directionUp) }
    /// Directional down tick — `-` taps, crown decrements.
    static func decrement()  { WKInterfaceDevice.current().play(.directionDown) }
}
