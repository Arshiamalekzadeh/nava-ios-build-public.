import ActivityKit
import Foundation

/// The six visual phases of NAVA's orange Dynamic Island. Kept in Shared
/// so the app and WidgetKit extension render the same ActivityKit state.
enum NAVAIslandPhase: String, Codable, Hashable, CaseIterable {
    case ready
    case listening
    case processing
    case responding
    case recording
    case focus

    var persianTitle: String {
        switch self {
        case .ready: "نوا آماده است"
        case .listening: "در حال گوش دادن…"
        case .processing: "در حال پردازش…"
        case .responding: "در حال پاسخ…"
        case .recording: "در حال ضبط…"
        case .focus: "در حال تمرکز"
        }
    }
}

struct NAVAActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
        let endsAt: Date?
        let phase: NAVAIslandPhase

        init(status: String, endsAt: Date? = nil, phase: NAVAIslandPhase = .ready) {
            self.status = status
            self.endsAt = endsAt
            self.phase = phase
        }

        // Activities created by NAVA 4.1 only stored status + endsAt.
        // Use a backward-compatible decoder instead of crashing the extension.
        private enum CodingKeys: String, CodingKey {
            case status, endsAt, phase
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            status = try values.decode(String.self, forKey: .status)
            endsAt = try values.decodeIfPresent(Date.self, forKey: .endsAt)
            phase = try values.decodeIfPresent(NAVAIslandPhase.self, forKey: .phase) ?? .ready
        }

        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(status, forKey: .status)
            try values.encodeIfPresent(endsAt, forKey: .endsAt)
            try values.encode(phase, forKey: .phase)
        }
    }

    let title: String
    let startedAt: Date
}
