import Foundation
import UserNotifications

@MainActor
final class ExposureWarningController {
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let identifier = "exposureWarning"
    private var work: Task<Void, Never>?
    private var generation = 0
    private(set) var status: String?

    func synchronize(session: ExposureSession?, requestPermission: Bool = false) {
        generation += 1
        let revision = generation
        let previous = work
        work = Task {
            await previous?.value
            guard revision == generation else { return }
            guard let session, session.end == nil else {
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
                status = nil
                return
            }
            do {
                if requestPermission {
                    _ = try await center.requestAuthorization(options: [.alert, .sound])
                }
                let settings = await center.notificationSettings()
                guard revision == generation else { return }
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                    status = "Exposure warnings are off. Allow notifications in Settings to receive them."
                    return
                }
                // Persist the last scheduled deadline so relaunching or continuing a session
                // cannot repeatedly alert after its warning has already become due.
                let key = "exposureWarning.deadline"
                if defaults.string(forKey: "exposureWarning.sessionID") == session.id.uuidString,
                   let deadline = defaults.object(forKey: key) as? Date, deadline <= Date() {
                    status = "This session's exposure warning is already due. Delivery depends on notification settings."
                    return
                }
                let now = Date()
                let incomplete = session.totals(until: now).coveredSeconds < max(0, now.timeIntervalSince(session.start)) - 1
                let predicted = session.exposureWarningDate(now: now)
                // If the estimate cannot reach a threshold within forecast coverage, warn
                // when that coverage ends rather than silently extrapolating old UV values.
                let fallback = session.segments.last?.forecast.last?.date ?? now
                let date = max(now.addingTimeInterval(1), predicted ?? fallback)
                let content = UNMutableNotificationContent()
                if incomplete || predicted == nil {
                    content.title = "Check your sun exposure"
                    content.body = "UV forecast coverage is limited. Open Fry Day to refresh. Don't rely on this estimate to avoid sunburn."
                } else {
                    content.title = "Sun exposure warning"
                    content.body = "Your estimated exposure threshold is due. Seek shade or cover up. This forecast-based warning is not a guarantee against sunburn."
                }
                content.sound = .default
                content.userInfo = ["sessionID": session.id.uuidString]
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
                defaults.set(date, forKey: key)
                defaults.set(session.id.uuidString, forKey: "exposureWarning.sessionID")
                status = "Best-effort warning scheduled. Forecast changes are applied when the app updates; alerts may be delayed or silenced by iOS."
            } catch {
                status = "The exposure warning could not be scheduled. Don't rely on an alert for sun protection."
            }
        }
    }

}
