import WidgetKit

/// Reads exclusively from the shared App Group store — no network calls —
/// so the Lock Screen widget always reflects the last value written by the
/// app, a silent push, or `UpdateMoodIntent`.
struct PulseWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseWidgetEntry {
        PulseWidgetEntry(
            date: Date(),
            partnerState: PartnerState(partnerName: "Tu pareja", mood: .good, updatedAt: Date()),
            myMood: .good,
            isConnected: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // Relative "hace Xm" labels drift over time even without new data,
        // so refresh the timeline periodically rather than only on reload.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date) ?? entry.date.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> PulseWidgetEntry {
        let connectionState = PulseSharedStore.connectionState
        return PulseWidgetEntry(
            date: Date(),
            partnerState: PulseSharedStore.partnerState,
            myMood: PulseSharedStore.myMood,
            isConnected: connectionState.isConnected
        )
    }
}
