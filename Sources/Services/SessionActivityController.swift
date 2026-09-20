import ActivityKit
import Foundation
import UserNotifications

@MainActor
final class SessionActivityController {
    private var work: Task<Void, Never>?
    private(set) var status: String?

    func synchronize(session: ExposureSession?, uv: Double?, updatedAt: Date?, allowStart: Bool) {
        // Serialize lifecycle operations so a slow update cannot resurrect an ended activity.
        let previous = work
        work = Task {
            await previous?.value
            let running = session.flatMap { $0.end == nil ? $0 : nil }
            for activity in Activity<SunSessionAttributes>.activities where activity.attributes.sessionID != running?.id {
                var state = activity.content.state
                state.endedAt = Date()
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
            }
            guard let session = running else { return }
            let state = SunSessionAttributes.ContentState(reminderDate: session.reminderDate, uv: uv, weatherUpdatedAt: updatedAt, endedAt: nil)
            let content = ActivityContent(state: state, staleDate: updatedAt?.addingTimeInterval(900) ?? Date())
            if let existing = Activity<SunSessionAttributes>.activities.first(where: { $0.attributes.sessionID == session.id }) {
                await existing.update(content)
            } else if allowStart {
                guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                    status = "Live Activities are disabled. Enable them in Settings to see the session on your Lock Screen."
                    return
                }
                do {
                    _ = try Activity.request(attributes: SunSessionAttributes(sessionID: session.id, startedAt: session.start), content: content, pushType: nil)
                    status = nil
                } catch {
                    status = "Live Activity unavailable. Your session is still saved."
                }
            }
        }
    }
}

// Cancel notifications already scheduled by earlier builds when upgrading.
func removeLegacySessionNotifications() {
    let identifiers = ["sessionReminder", "burnWarning", "sunrise", "sunset", "solarNoon", "safeTimeReached"]
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
    center.removeDeliveredNotifications(withIdentifiers: identifiers)
}
