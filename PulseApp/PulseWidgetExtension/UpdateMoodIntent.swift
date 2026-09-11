import AppIntents
import WidgetKit

/// Lock Screen button intent. Runs entirely in the widget extension process:
/// writes the new mood to the App Group instantly (so the timeline can
/// re-render before the network call even starts), reloads timelines, then
/// fires a best-effort background `POST /status`.
struct UpdateMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Actualizar estado de ánimo"
    static var description = IntentDescription("Comparte tu estado de ánimo actual con tu pareja.")

    /// Interactive Lock Screen widgets require intents to run without
    /// opening the app.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Estado de ánimo")
    var mood: PulseMood

    init() {}

    init(mood: PulseMood) {
        self.mood = mood
    }

    func perform() async throws -> some IntentResult {
        PulseSharedStore.myMood = mood
        WidgetCenter.shared.reloadAllTimelines()

        await PulseAPIClient.shared.postStatus(mood: mood)

        return .result()
    }
}
