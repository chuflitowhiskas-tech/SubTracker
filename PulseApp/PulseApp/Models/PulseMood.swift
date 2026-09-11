import SwiftUI
import AppIntents

/// The three moods a partner can broadcast to the other. Backed by `String`
/// so it round-trips directly with the JSON the Go backend sends/receives,
/// and conforms to `AppEnum` so it can be an `UpdateMoodIntent` parameter.
enum PulseMood: String, AppEnum, Codable, Sendable, CaseIterable {
    case good
    case hungry
    case sad

    var displayName: String {
        switch self {
        case .good: return "Feliz"
        case .hungry: return "Hambre"
        case .sad: return "Triste"
        }
    }

    var systemImageName: String {
        switch self {
        case .good: return "face.smiling.fill"
        case .hungry: return "fork.knife"
        case .sad: return "cloud.rain.fill"
        }
    }

    /// The exact hex tint from the design system for this mood.
    var hexColor: String {
        switch self {
        case .good: return "#49B9F9"
        case .hungry: return "#D29922"
        case .sad: return "#7B61FF"
        }
    }

    var tintColor: Color { Color(hex: hexColor) }

    // MARK: - AppEnum

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Estado de ánimo")
    }

    static var caseDisplayRepresentations: [PulseMood: DisplayRepresentation] = [
        .good: DisplayRepresentation(title: "Feliz", image: .init(systemName: "face.smiling.fill")),
        .hungry: DisplayRepresentation(title: "Hambre", image: .init(systemName: "fork.knife")),
        .sad: DisplayRepresentation(title: "Triste", image: .init(systemName: "cloud.rain.fill")),
    ]
}
