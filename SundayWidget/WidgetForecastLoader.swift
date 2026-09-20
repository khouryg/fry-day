import Foundation
import CoreLocation

actor WidgetForecastLoader {
    static let shared = WidgetForecastLoader()
    private var inflight: Task<WeatherSnapshot?, Never>?
    private let defaults = UserDefaults(suiteName: "group.com.khouryg.fryday")

    func cached() -> WeatherSnapshot? {
        guard let data = defaults?.data(forKey: "weatherSnapshot") else { return nil }
        return try? JSONDecoder().decode(WeatherSnapshot.self, from: data)
    }

    func forecast() async -> WeatherSnapshot? {
        if let inflight { return await inflight.value }
        guard let previous = cached() else { return nil }
        let status = CLLocationManager().authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else { return previous }
        let attempt = defaults?.object(forKey: "widgetWeatherLastAttempt") as? Date
        guard ForecastRefreshPolicy.shouldRefresh(now: Date(), updatedAt: previous.updatedAt, lastAttempt: attempt) else { return previous }
        defaults?.set(Date(), forKey: "widgetWeatherLastAttempt")
        let task = Task<WeatherSnapshot?, Never> {
            do {
                let result = try await WeatherClient.fetch(latitude: previous.latitude, longitude: previous.longitude, altitude: previous.altitude)
                // Don't overwrite a newer location selected by the app while this request ran.
                if let latest = cached(), latest.latitude != previous.latitude || latest.longitude != previous.longitude || latest.updatedAt > result.updatedAt { return latest }
                if let data = try? JSONEncoder().encode(result) { defaults?.set(data, forKey: "weatherSnapshot") }
                return result
            } catch { return previous }
        }
        inflight = task
        let result = await task.value
        inflight = nil
        return result
    }
}
