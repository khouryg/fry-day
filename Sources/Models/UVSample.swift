import Foundation

struct UVSample: Codable, Equatable {
    var date: Date
    var uv: Double
}

extension UVSample {
    static func value(at date: Date, in samples: [UVSample]) -> Double? {
        guard let first = samples.first, let last = samples.last,
              date >= first.date, date <= last.date else { return nil }
        if date == last.date { return last.uv.isFinite ? max(0, last.uv) : nil }
        guard let index = samples.indices.dropLast().first(where: {
            samples[$0].date <= date && samples[$0 + 1].date > date
        }) else { return nil }
        let a = samples[index], b = samples[index + 1]
        let duration = b.date.timeIntervalSince(a.date)
        guard duration > 0, duration <= 3700, a.uv.isFinite, b.uv.isFinite else { return nil }
        return max(0, a.uv + (b.uv - a.uv) * date.timeIntervalSince(a.date) / duration)
    }

}
