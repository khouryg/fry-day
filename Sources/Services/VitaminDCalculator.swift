import Foundation
import Combine
import UIKit
import WidgetKit

@MainActor
final class VitaminDCalculator: ObservableObject {
    @Published private(set) var archive = SessionArchive()
    @Published private(set) var totals = ExposureTotals()
    @Published private(set) var currentVitaminDRate = 0.0
    @Published var errorMessage: String?
    @Published var reminderStatus: String?
    @Published private(set) var settings = ExposureSettings()
    @Published var reminderMinutes = 20
    @Published private(set) var now = Date()
    private var loaded = false
    private let store: SessionFileStore
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var forecast: [UVSample] = []
    private var weatherUpdatedAt: Date?
    private var currentUV: Double?
    private let activity = SessionActivityController()
    private let reminders = SessionReminderController()
    private let shared = UserDefaults(suiteName: "group.com.khouryg.fryday")
    private var lastWidgetUpdate = Date.distantPast

    var liveActivityStatus: String? { activity.status }
    var active: ExposureSession? { archive.active }
    var isInSun: Bool { active != nil && active?.end == nil }
    var sessionVitaminD: Double { totals.iu }
    var sessionStartTime: Date? { active?.start }
    var completed: [ExposureSession] { archive.completed.sorted { $0.start > $1.start } }
    var hasIncompleteCoverage: Bool {
        guard let active else { return false }
        return (active.end ?? now).timeIntervalSince(active.start) - totals.coveredSeconds > 60
    }
    var todayTotal: Double {
        let start = Calendar.current.startOfDay(for: now)
        let saved = archive.completed.reduce(0) { $0 + $1.totals(until: now, since: start).iu }
        return saved + (active?.totals(until: now, since: start).iu ?? 0)
    }

    init(store: SessionFileStore? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FryDay", isDirectory: true)
        self.store = store ?? SessionFileStore(url: directory.appendingPathComponent("sessions.json"))
        let savedMinutes = UserDefaults.standard.integer(forKey: "reminderMinutes")
        if [10, 20, 30, 60].contains(savedMinutes) { reminderMinutes = savedMinutes }
        reload()
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.timer?.invalidate()
                self?.timer = nil
                self?.refresh(forceWidget: true)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(forceWidget: true)
                self?.startTimer()
                self?.syncActivity(allowStart: false)
            }
        })
        startTimer()
        // Reconcile orphan activities without recreating ones the user dismissed.
        syncActivity(allowStart: false)
        reminders.synchronize(session: active, requestPermission: false) { [weak self] in self?.reminderStatus = $0 }
    }

    func reload() {
        do {
            archive = try store.load()
            settings = archive.settings
            loaded = true
            errorMessage = nil
            refresh(forceWidget: true)
        } catch {
            loaded = false
            errorMessage = "Your saved sessions could not be opened. They have been left untouched. Try again after unlocking your device."
        }
    }

    @discardableResult
    private func commit(_ updated: SessionArchive) -> Bool {
        guard loaded else { return false }
        do {
            try store.save(updated)
            archive = updated
            errorMessage = nil
            refresh(forceWidget: true)
            return true
        } catch {
            errorMessage = "The session could not be saved. Please free some storage and try again. Your previous record is unchanged."
            return false
        }
    }

    func startSession() {
        guard loaded, active == nil, let uv = currentUV, uv > 0,
              let weatherDate = weatherUpdatedAt, Date().timeIntervalSince(weatherDate) < 900,
              ExposureSession.uv(at: Date(), in: forecast) != nil else {
            errorMessage = "Refresh UV data before beginning a session."
            return
        }
        let date = Date()
        var updated = archive
        updated.active = ExposureSession(start: date, reminderDate: date.addingTimeInterval(Double(reminderMinutes) * 60), segments: [ExposureSegment(start: date, settings: settings, forecast: forecast)])
        guard commit(updated) else { return }
        UserDefaults.standard.set(reminderMinutes, forKey: "reminderMinutes")
        syncActivity(allowStart: true)
        reminders.synchronize(session: active, requestPermission: true) { [weak self] in self?.reminderStatus = $0 }
    }

    func prepareCompletion(sessionID: UUID? = nil) {
        guard let active, active.end == nil, sessionID == nil || active.id == sessionID else { return }
        var updated = archive
        updated.active?.end = Date()
        guard commit(updated) else { return }
        syncActivity(allowStart: false)
        reminders.synchronize(session: nil, requestPermission: false) { _ in }
    }

    @discardableResult
    func saveSession(end: Date) -> Bool {
        guard active != nil else { return false }
        var updated = archive
        updated.complete(at: min(end, Date()))
        guard commit(updated) else { return false }
        syncActivity(allowStart: false)
        reminders.synchronize(session: nil, requestPermission: false) { _ in }
        return true
    }

    func continueSession() {
        guard active != nil else { return }
        var updated = archive
        updated.active?.end = nil
        updated.active?.reminderDate = Date().addingTimeInterval(Double(reminderMinutes) * 60)
        guard commit(updated) else { return }
        syncActivity(allowStart: true)
        reminders.synchronize(session: active, requestPermission: true) { [weak self] in self?.reminderStatus = $0 }
    }

    @discardableResult
    func discardSession() -> Bool {
        var updated = archive
        updated.active = nil
        guard commit(updated) else { return false }
        syncActivity(allowStart: false)
        reminders.synchronize(session: nil, requestPermission: false) { _ in }
        return true
    }

    func deleteSession(id: UUID) {
        var updated = archive
        updated.completed.removeAll { $0.id == id }
        _ = commit(updated)
    }

    @discardableResult
    func addManualSession(start: Date, end: Date, settings: ExposureSettings, forecast: [UVSample]) -> Bool {
        guard loaded, active == nil, start < end, end <= Date() else { return false }
        let session = ExposureSession(start: start, end: end, reminderDate: end, segments: [ExposureSegment(start: start, settings: settings, forecast: forecast)])
        guard session.totals(until: end).coveredSeconds >= end.timeIntervalSince(start) - 1 else {
            errorMessage = "UV data does not cover the whole interval. Choose a shorter interval or refresh the forecast."
            return false
        }
        var updated = archive
        updated.completed.append(session)
        return commit(updated)
    }

    func updateSettings(_ newSettings: ExposureSettings) {
        var updated = archive
        if isInSun { updated.active?.segments.append(ExposureSegment(start: Date(), settings: newSettings, forecast: forecast)) }
        updated.settings = newSettings
        guard commit(updated) else { return }
        settings = newSettings
        refresh(forceWidget: true)
    }

    func updateForecast(_ samples: [UVSample], updatedAt: Date?) {
        let sorted = samples.filter { $0.uv.isFinite }.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return }
        if forecast != sorted && isInSun {
            var updated = archive
            // Keep the forecast used for elapsed time; new conditions affect future time only.
            updated.active?.segments.append(ExposureSegment(start: Date(), settings: settings, forecast: sorted))
            guard commit(updated) else { return }
        }
        forecast = sorted
        weatherUpdatedAt = updatedAt
        refresh(forceWidget: true)
        syncActivity(allowStart: false)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh(forceWidget: Bool = false) {
        now = Date()
        totals = active?.totals(until: now) ?? ExposureTotals()
        currentUV = ExposureSession.uv(at: now, in: forecast)
        currentVitaminDRate = settings.hourlyIU(uv: currentUV ?? 0)
        guard forceWidget || now.timeIntervalSince(lastWidgetUpdate) >= 15 * 60 else { return }
        shared?.set(currentUV, forKey: "currentUV")
        shared?.set(currentVitaminDRate, forKey: "vitaminDRate")
        shared?.set(weatherUpdatedAt, forKey: "weatherUpdatedAt")
        shared?.set(now, forKey: "totalsUpdatedAt")
        shared?.set(isInSun, forKey: "isTracking")
        shared?.set(active?.start, forKey: "sessionStart")
        shared?.set(active?.id.uuidString, forKey: "sessionID")
        shared?.set(todayTotal, forKey: "todaysTotal")
        WidgetCenter.shared.reloadAllTimelines()
        lastWidgetUpdate = now
    }

    private func syncActivity(allowStart: Bool) {
        activity.synchronize(session: active, uv: currentUV, updatedAt: weatherUpdatedAt, allowStart: allowStart)
    }
}
