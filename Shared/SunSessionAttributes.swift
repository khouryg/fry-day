import ActivityKit
import Foundation

struct SunSessionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        // Retained for decoding Live Activities created by build 1; no deadline is displayed.
        var reminderDate: Date
        var uv: Double?
        var weatherUpdatedAt: Date?
        var endedAt: Date?
    }
    var sessionID: UUID
    var startedAt: Date
}
