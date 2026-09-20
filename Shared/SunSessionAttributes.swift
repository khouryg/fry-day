import ActivityKit
import Foundation

struct SunSessionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var reminderDate: Date
        var uv: Double?
        var weatherUpdatedAt: Date?
        var endedAt: Date?
    }
    var sessionID: UUID
    var startedAt: Date
}
