import SwiftUI
import WidgetKit

/// Interactive Lock Screen widget (`.accessoryRectangular`) plus a compact
/// `.systemSmall` Home Screen presentation, both driven by
/// `PulseWidgetProvider`'s App Group-only timeline.
struct PulseWidget: Widget {
    let kind: String = "PulseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseWidgetProvider()) { entry in
            PulseWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    PulseColor.backgroundSurface
                }
        }
        .configurationDisplayName("Pulse")
        .description("Mira y comparte tu estado de ánimo al instante.")
        .supportedFamilies([.accessoryRectangular, .systemSmall])
    }
}

struct PulseWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseWidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        default:
            SmallHomeScreenView(entry: entry)
        }
    }
}

// MARK: - Lock Screen (.accessoryRectangular)

private struct LockScreenRectangularView: View {
    let entry: PulseWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Row 1: partner mood icon + "[Nombre]: [Mood] • hace Xm".
            HStack(spacing: 4) {
                if let partner = entry.partnerState {
                    Image(systemName: partner.mood.systemImageName)
                        .font(.system(size: 11, weight: .semibold))

                    Text("\(partner.partnerName): \(partner.mood.displayName) · \(partner.relativeUpdatedAtLabel)")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Sin pareja conectada")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
            }

            // Row 2: three compact interactive mood buttons.
            HStack(spacing: 6) {
                ForEach(PulseMood.allCases, id: \.self) { mood in
                    Button(intent: UpdateMoodIntent(mood: mood)) {
                        Image(systemName: mood.systemImageName)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .tint(entry.myMood == mood ? mood.tintColor : nil)
                }
            }
        }
    }
}

// MARK: - Home Screen (.systemSmall)

private struct SmallHomeScreenView: View {
    let entry: PulseWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PULSE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(PulseColor.textMuted)
                Spacer()
            }

            if let partner = entry.partnerState {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: partner.mood.systemImageName)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(partner.mood.tintColor)

                    Text(partner.partnerName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PulseColor.textPrimary)
                        .lineLimit(1)

                    Text("\(partner.mood.displayName) · \(partner.relativeUpdatedAtLabel)")
                        .font(.system(size: 10))
                        .foregroundStyle(PulseColor.textMuted)
                        .lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(PulseColor.textMuted)
                    Text("Sin pareja")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PulseColor.textPrimary)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                ForEach(PulseMood.allCases, id: \.self) { mood in
                    Button(intent: UpdateMoodIntent(mood: mood)) {
                        Image(systemName: mood.systemImageName)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 26)
                    }
                    .buttonStyle(.plain)
                    .background(entry.myMood == mood ? mood.tintColor.opacity(0.2) : PulseColor.backgroundElevated)
                    .foregroundStyle(entry.myMood == mood ? mood.tintColor : PulseColor.textMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(14)
    }
}

#Preview(as: .accessoryRectangular) {
    PulseWidget()
} timeline: {
    PulseWidgetEntry(
        date: Date(),
        partnerState: PartnerState(partnerName: "Valentina", mood: .hungry, updatedAt: Date().addingTimeInterval(-180)),
        myMood: .good,
        isConnected: true
    )
}

#Preview(as: .systemSmall) {
    PulseWidget()
} timeline: {
    PulseWidgetEntry(
        date: Date(),
        partnerState: PartnerState(partnerName: "Valentina", mood: .sad, updatedAt: Date().addingTimeInterval(-600)),
        myMood: .hungry,
        isConnected: true
    )
}
