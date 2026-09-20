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
                    status = "Live Activities are disabled. Session reminders are still available."
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

@MainActor
final class SessionReminderController {
    private var work: Task<Void, Never>?
    private let identifiers = ["sessionReminder", "burnWarning", "sunrise", "sunset", "solarNoon", "safeTimeReached"]

    func synchronize(session: ExposureSession?, requestPermission: Bool, onStatus: @escaping (String?) -> Void) {
        let previous = work
        work = Task {
            await previous?.value
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            guard let session, session.end == nil else { return }
            do {
                let settings = await center.notificationSettings()
                var allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                if requestPermission && settings.authorizationStatus == .notDetermined {
                    allowed = try await center.requestAuthorization(options: [.alert, .sound])
                }
                guard allowed else {
                    onStatus("Notifications are disabled. Enable them in Settings to receive session reminders.")
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = "Check your sun session"
                content.body = "Still outdoors? Review your Fry Day session and take a shade break. This reminder is not a safe-exposure limit."
                content.sound = .default
                content.userInfo = ["sessionID": session.id.uuidString]
                let delay = max(1, session.reminderDate.timeIntervalSinceNow)
                // A persisted past deadline must not generate a new alert on every relaunch.
                guard session.reminderDate > Date() || requestPermission else { return }
                try await center.add(UNNotificationRequest(identifier: "sessionReminder", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)))
                onStatus(nil)
            } catch {
                onStatus("The reminder could not be scheduled. Your session is still saved.")
            }
        }
    }
}
