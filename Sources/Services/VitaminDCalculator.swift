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
    @Published private(set) var settings = ExposureSettings()
    @Published private(set) var now = Date()
    private var loaded = false
    private let store: SessionFileStore
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var forecast: [UVSample] = []
    private var weatherUpdatedAt: Date?
    private var currentUV: Double?
    private let activity = SessionActivityController()
    private let exposureWarning = ExposureWarningController()
    private let shared = UserDefaults(suiteName: "group.com.khouryg.fryday")
    private var lastWidgetUpdate = Date.distantPast
    private var widgetUpdate: Task<Void, Never>?
    private var timerInterval: TimeInterval?
    private var isForeground = UIApplication.shared.applicationState == .active
    private var activeTotals = ExposureTotalsAccumulator()
    private var activeTodayTotals = ExposureTotalsAccumulator()
    private var historyDirty = true
    private var historyDay: Date?
    private var savedTodayTotal = 0.0
    private var historyContainsFutureEnd = false
    @Published private(set) var todayTotal = 0.0

    @Published private(set) var estimatedBurnDate: Date?
    private var burnEstimateUpdatedAt = Date.distantPast

    var estimatedBurnTimeText: String {
        guard let date = estimatedBurnDate else { return "—" }
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 { return "Reached" }
        if seconds < 60 { return "<1 min" }
        let minutes = Int(ceil(seconds / 60))
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60)h \(minutes % 60)m"
    }

    var exposureWarningStatus: String? { exposureWarning.status }
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

    init(store: SessionFileStore? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FryDay", isDirectory: true)
        self.store = store ?? SessionFileStore(url: directory.appendingPathComponent("sessions.json"))
        removeLegacySessionNotifications()
        reload()
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isForeground = false
                self?.timer?.invalidate()
                self?.timer = nil
                self?.timerInterval = nil
                self?.refresh(forceWidget: true)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isForeground = true
                self?.refresh(forceWidget: true)
                self?.startTimer()
                self?.syncActivity(allowStart: false)
                self?.exposureWarning.synchronize(session: self?.active)
            }
        })
        startTimer()
        // Reconcile orphan activities without recreating ones the user dismissed.
        syncActivity(allowStart: false)
    }

    func reload() {
        do {
            archive = try store.load()
            exposureWarning.synchronize(session: active)
            historyDirty = true
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
            if updated.completed != archive.completed { historyDirty = true }
            archive = updated
            exposureWarning.synchronize(session: active)
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
        updated.active = ExposureSession(start: date, reminderDate: date, segments: [ExposureSegment(start: date, settings: settings, forecast: forecast)])
        guard commit(updated) else { return }
        syncActivity(allowStart: true)
        exposureWarning.synchronize(session: active, requestPermission: true)
    }

    func prepareCompletion(sessionID: UUID? = nil) {
        guard let active, active.end == nil, sessionID == nil || active.id == sessionID else { return }
        var updated = archive
        updated.active?.end = Date()
        guard commit(updated) else { return }
        syncActivity(allowStart: false)
    }

    @discardableResult
    func saveSession(end: Date) -> Bool {
        guard let sessionID = active?.id else { return false }
        var updated = archive
        updated.complete(at: min(end, Date()))
        guard commit(updated) else { return false }
        if let saved = archive.completed.first(where: { $0.id == sessionID }) { HealthManager.shared.export(saved) }
        syncActivity(allowStart: false)
        return true
    }

    func continueSession() {
        guard active != nil else { return }
        var updated = archive
        updated.active?.end = nil
        guard commit(updated) else { return }
        syncActivity(allowStart: true)
        exposureWarning.synchronize(session: active, requestPermission: true)
    }

    @discardableResult
    func discardSession() -> Bool {
        var updated = archive
        updated.active = nil
        guard commit(updated) else { return false }
        syncActivity(allowStart: false)
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
        guard commit(updated) else { return false }
        HealthManager.shared.export(session)
        return true
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
        guard isForeground else { return }
        let interval: TimeInterval = isInSun ? 1 : 60
        guard timerInterval != interval || timer == nil else { return }
        timer?.invalidate()
        timerInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = isInSun ? 0.1 : 5
    }

    func refresh(forceWidget: Bool = false) {
        let previousNow = now
        now = Date()
        if now < previousNow { historyDirty = true }
        totals = active.map { activeTotals.totals(for: $0, until: now) } ?? ExposureTotals()
        // Reuse the warning model without repeating forecast integration every timer tick.
        if forceWidget || now < burnEstimateUpdatedAt || now.timeIntervalSince(burnEstimateUpdatedAt) >= 60 {
            let session = active ?? ExposureSession(start: now, reminderDate: now,
                segments: [ExposureSegment(start: now, settings: settings, forecast: forecast)])
            let elapsed = session.totals(until: now)
            let complete = elapsed.coveredSeconds >= max(0, now.timeIntervalSince(session.start)) - 1
            let canEstimate = active != nil || (ExposureSession.uv(at: now, in: forecast) ?? 0) > 0
            estimatedBurnDate = complete && canEstimate ? session.exposureWarningDate(now: now) : nil
            burnEstimateUpdatedAt = now
        }
        let day = Calendar.current.startOfDay(for: now)
        if historyDirty || historyDay != day || historyContainsFutureEnd {
            savedTodayTotal = archive.completed.reduce(0) { $0 + $1.totals(until: now, since: day).iu }
            historyContainsFutureEnd = archive.completed.contains { ($0.end ?? $0.start) > now }
            historyDay = day
            historyDirty = false
        }
        let currentToday = active.map {
            day <= $0.start ? totals.iu : activeTodayTotals.totals(for: $0, until: now, since: day).iu
        } ?? 0
        let total = savedTodayTotal + currentToday
        if todayTotal != total { todayTotal = total }
        currentUV = ExposureSession.uv(at: now, in: forecast)
        currentVitaminDRate = settings.hourlyIU(uv: currentUV ?? 0)
        startTimer()
        guard forceWidget || now.timeIntervalSince(lastWidgetUpdate) >= 15 * 60 else { return }
        // Collapse multiple synchronous changes (save + settings/forecast update) into one write/reload.
        guard widgetUpdate == nil else { return }
        widgetUpdate = Task { [weak self] in
            await Task.yield()
            guard let self else { return }
            self.publishWidgetSnapshot()
            self.widgetUpdate = nil
        }
    }

    private func publishWidgetSnapshot() {
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
