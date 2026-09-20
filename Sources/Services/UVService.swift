import Foundation
import CoreLocation

@MainActor
final class UVService: ObservableObject {
    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var isOfflineMode = false
    @Published private(set) var currentUV: Double?
    private var request: Task<Void, Never>?
    private var requestedLocation: CLLocation?
    private var generation = UUID()
    private var refreshPolicy = ForegroundRefreshPolicy()
    private let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("fryday-weather.json")

    var samples: [UVSample] { snapshot?.samples ?? [] }
    var lastSuccessfulUpdate: Date? { snapshot?.updatedAt }
    var currentLatitude: Double { snapshot?.latitude ?? 0 }
    var isVitaminDWinter: Bool {
        Self.isWinter(latitude: currentLatitude, month: Calendar.current.component(.month, from: Date()), maxUV: snapshot?.maxUV ?? 0)
    }
    var shouldShowTomorrowTimes: Bool { snapshot?.sunset.map { Date() > $0 } ?? false }
    var displaySunrise: Date? { shouldShowTomorrowTimes ? snapshot?.tomorrowSunrise : snapshot?.sunrise }
    var displaySunset: Date? { shouldShowTomorrowTimes ? snapshot?.tomorrowSunset : snapshot?.sunset }
    var displayMaxUV: Double { (shouldShowTomorrowTimes ? snapshot?.tomorrowMaxUV : snapshot?.maxUV) ?? 0 }
    var currentCloudCover: Double { snapshot?.cloudCover ?? 0 }
    var currentAltitude: Double { snapshot?.altitude ?? 0 }
    var moonPhaseIcon: String {
        // Approximate synodic phase; no network request or fabricated fallback.
        let days = Date().timeIntervalSince1970 / 86400 - 10962.75972
        let phase = (days / 29.530588853).truncatingRemainder(dividingBy: 1)
        let index = Int(((phase + 1).truncatingRemainder(dividingBy: 1) * 8).rounded()) % 8
        return ["moonphase.new.moon", "moonphase.waxing.crescent", "moonphase.first.quarter", "moonphase.waxing.gibbous", "moonphase.full.moon", "moonphase.waning.gibbous", "moonphase.last.quarter", "moonphase.waning.crescent"][index]
    }
    static func isWinter(latitude: Double, month: Int, maxUV: Double) -> Bool {
        guard abs(latitude) > 35 else { return maxUV < 3 }
        let northernMonth = latitude < 0 ? ((month + 5) % 12) + 1 : month
        return [11, 12, 1, 2].contains(northernMonth) || ([3, 10].contains(northernMonth) && maxUV < 3)
    }

    func refreshCurrentUV() {
        let value = snapshot.flatMap { ForecastRefreshPolicy.uv(at: Date(), snapshot: $0) }
        if currentUV != value { currentUV = value }
        let shared = UserDefaults(suiteName: "group.com.khouryg.fryday")
        let phase = moonPhaseIcon.replacingOccurrences(of: "moonphase.", with: "").replacingOccurrences(of: ".", with: " ")
        if shared?.string(forKey: "moonPhaseName") != phase { shared?.set(phase, forKey: "moonPhaseName") }
    }

    func networkBecameAvailable() {
        // Connectivity recovery removes failure backoff; the short request-burst limit still applies.
        refreshPolicy.succeeded()
    }

    func fetchUVData(for location: CLLocation, force: Bool = false, isTracking: Bool = false) {
        if snapshot == nil { loadCache(near: location) }
        let nearby = snapshot.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: location) < 1000
        } ?? false
        // Repeated foreground/location events share the existing request, including manual retries.
        if isLoading, requestedLocation.map({ $0.distance(from: location) < 1000 }) == true { return }
        let date = Date()
        guard refreshPolicy.shouldFetch(now: date, updatedAt: snapshot?.updatedAt, nearby: nearby,
            hasCoverage: snapshot.flatMap { ForecastRefreshPolicy.uv(at: date, snapshot: $0) } != nil,
            isTracking: isTracking, force: force) else {
            refreshCurrentUV()
            return
        }
        refreshPolicy.began(at: date)
        requestedLocation = location
        request?.cancel()
        let identifier = UUID()
        generation = identifier
        isLoading = true
        lastError = nil
        if let current = snapshot,
           CLLocation(latitude: current.latitude, longitude: current.longitude).distance(from: location) > 25000 {
            snapshot = nil
            currentUV = nil
        }
        if snapshot == nil { loadCache(near: location) }
        request = Task {
            do {
                let result = try await WeatherClient.fetch(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, altitude: location.verticalAccuracy >= 0 ? location.altitude : nil)
                guard !Task.isCancelled, generation == identifier else { return }
                refreshPolicy.succeeded()
                snapshot = result
                shareForecast(result)
                refreshCurrentUV()
                isOfflineMode = false
                isLoading = false
                // A disposable cache failure must not hide valid weather data.
                if let encoded = try? JSONEncoder().encode(result) { try? encoded.write(to: cacheURL, options: .atomic) }
            } catch {
                guard !Task.isCancelled, generation == identifier else { return }
                refreshPolicy.failed(at: Date())
                isLoading = false
                isOfflineMode = true
                lastError = "Weather could not be refreshed. Cached forecasts are labeled with their update time."
                if snapshot == nil { loadCache(near: location) }
                refreshCurrentUV()
            }
        }
    }

    private func shareForecast(_ forecast: WeatherSnapshot) {
        let shared = UserDefaults(suiteName: "group.com.khouryg.fryday")
        if let data = try? JSONEncoder().encode(forecast) { shared?.set(data, forKey: "weatherSnapshot") }
    }

    private func loadCache(near location: CLLocation) {
        let shared = UserDefaults(suiteName: "group.com.khouryg.fryday")
        let candidates = [(try? Data(contentsOf: cacheURL)), shared?.data(forKey: "weatherSnapshot")]
            .compactMap { $0 }.compactMap { try? JSONDecoder().decode(WeatherSnapshot.self, from: $0) }
            .filter { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: location) < 25000 && ExposureSession.uv(at: Date(), in: $0.samples) != nil }
        guard let cached = candidates.max(by: { $0.updatedAt < $1.updatedAt }) else { return }
        snapshot = cached
        shareForecast(cached)
        isOfflineMode = true
        refreshCurrentUV()
    }
}
