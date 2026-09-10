import WidgetKit

/// Timeline entry rendered by both widget families. Populated exclusively
/// from `PulseSharedStore` (App Group `UserDefaults`) for instant, zero-lag
/// rendering — never from the network.
struct PulseWidgetEntry: TimelineEntry {
    let date: Date
    let partnerState: PartnerState?
    let myMood: PulseMood
    let isConnected: Bool
}
