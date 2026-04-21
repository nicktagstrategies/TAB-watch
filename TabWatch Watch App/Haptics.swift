import WatchKit

/// Thin wrapper around `WKInterfaceDevice` so call sites don't have to import
/// WatchKit and we can stub/disable it in tests or previews.
enum Haptics {
    static func click()   { WKInterfaceDevice.current().play(.click) }
    static func success() { WKInterfaceDevice.current().play(.success) }
    static func failure() { WKInterfaceDevice.current().play(.failure) }
}
