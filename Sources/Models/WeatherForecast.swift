import Foundation

struct WeatherSnapshot: Codable {
    var latitude: Double
    var longitude: Double
    var updatedAt: Date
    var samples: [UVSample]
    var maxUV: Double
    var sunrise: Date?
    var sunset: Date?
    var tomorrowSunrise: Date?
    var tomorrowSunset: Date?
    var tomorrowMaxUV: Double?
    var cloudCover: Double?
    var altitude: Double?
}

private struct ForecastResponse: Decodable {
    struct Hourly: Decodable {
        var time: [Double]
        var uv_index: [Double?]
        var cloud_cover: [Double?]?
    }
    struct Daily: Decodable {
        var uv_index_max: [Double?]
        var sunrise: [Double?]
        var sunset: [Double?]
    }
    var hourly: Hourly
    var daily: Daily
}

enum WeatherClient {
    static func fetch(latitude: Double, longitude: Double, altitude: Double? = nil) async throws -> WeatherSnapshot {
                var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
                // Epoch timestamps avoid phone/API timezone disagreement and DST indexing bugs.
                components.queryItems = [
                    URLQueryItem(name: "latitude", value: String(latitude)),
                    URLQueryItem(name: "longitude", value: String(longitude)),
                    URLQueryItem(name: "hourly", value: "uv_index,cloud_cover"),
                    URLQueryItem(name: "daily", value: "uv_index_max,sunrise,sunset"),
                    URLQueryItem(name: "timezone", value: TimeZone.current.identifier),
                    URLQueryItem(name: "timeformat", value: "unixtime"),
                    URLQueryItem(name: "forecast_days", value: "2")
                ]
                let (data, response) = try await URLSession.shared.data(from: components.url!)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
                let decoded = try JSONDecoder().decode(ForecastResponse.self, from: data)
                guard decoded.hourly.time.count == decoded.hourly.uv_index.count else { throw URLError(.cannotParseResponse) }
                // Null values remain gaps. Interpolation rejects missing intervals over one hour.
                let samples = zip(decoded.hourly.time, decoded.hourly.uv_index).compactMap { timestamp, uv -> UVSample? in
                    guard let uv, uv.isFinite, timestamp.isFinite else { return nil }
                    return UVSample(date: Date(timeIntervalSince1970: timestamp), uv: max(0, uv))
                }.sorted { $0.date < $1.date }
                guard samples.count > 1, UVSample.value(at: Date(), in: samples) != nil else { throw URLError(.cannotParseResponse) }
                try Task.checkCancellation()
                func date(_ values: [Double?], index: Int = 0) -> Date? {
                    guard values.indices.contains(index), let value = values[index] else { return nil }
                    return Date(timeIntervalSince1970: value)
                }
                var result = WeatherSnapshot(latitude: latitude, longitude: longitude, updatedAt: Date(), samples: samples, maxUV: decoded.daily.uv_index_max.first.flatMap { $0 } ?? 0, sunrise: date(decoded.daily.sunrise), sunset: date(decoded.daily.sunset), tomorrowSunrise: date(decoded.daily.sunrise, index: 1), tomorrowSunset: date(decoded.daily.sunset, index: 1), tomorrowMaxUV: decoded.daily.uv_index_max.count > 1 ? decoded.daily.uv_index_max[1] : nil, cloudCover: nil, altitude: altitude)
                if let index = decoded.hourly.time.lastIndex(where: { $0 <= Date().timeIntervalSince1970 }),
                   let clouds = decoded.hourly.cloud_cover, clouds.indices.contains(index) { result.cloudCover = clouds[index] }
        return result
    }
}

// Pure policy shared by app/extension tests. Timeline entries do not make network requests.
enum ForecastRefreshPolicy {
    static let refreshInterval: TimeInterval = 3 * 3600
    static let maximumAge: TimeInterval = 24 * 3600
    static func shouldRefresh(now: Date, updatedAt: Date, lastAttempt: Date?) -> Bool {
        now.timeIntervalSince(updatedAt) >= refreshInterval &&
        (lastAttempt.map { now.timeIntervalSince($0) >= refreshInterval } ?? true)
    }
    static func uv(at date: Date, snapshot: WeatherSnapshot) -> Double? {
        guard date.timeIntervalSince(snapshot.updatedAt) <= maximumAge else { return nil }
        return UVSample.value(at: date, in: snapshot.samples)
    }
    static func timelineDates(from date: Date) -> [Date] {
        (0...96).map { date.addingTimeInterval(Double($0) * 15 * 60) }
    }
}
