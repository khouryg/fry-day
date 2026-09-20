import Foundation

struct ExposureSettings: Codable, Equatable {
    var clothing: ClothingLevel = .light
    var sunscreen: SunscreenLevel = .none
    var skin: SkinType = .type3
    var age: Int?

    // Inherited model; an estimate, not a measured health quantity.
    func hourlyIU(uv: Double) -> Double {
        guard uv.isFinite, uv > 0 else { return 0 }
        let ageFactor = age.map { max(0.25, min(1, 1 - Double($0 - 20) * 0.015)) } ?? 1
        return 21000 * (uv * 3 / (4 + uv)) * clothing.exposureFactor
            * sunscreen.uvTransmissionFactor * skin.vitaminDFactor * ageFactor
    }

    func medPerSecond(uv: Double) -> Double {
        let minutes: [Double] = [150, 250, 425, 600, 850, 1100]
        return max(0, uv) / (minutes[skin.rawValue - 1] * 60)
    }
}

struct ExposureSegment: Codable, Equatable {
    var start: Date
    var settings: ExposureSettings
    var forecast: [UVSample]
}

struct ExposureTotals: Equatable {
    var iu = 0.0
    var med = 0.0
    var coveredSeconds = 0.0
    var uvSeconds = 0.0
    var peakUV = 0.0
    var averageUV: Double { coveredSeconds > 0 ? uvSeconds / coveredSeconds : 0 }
}

struct ExposureSession: Codable, Identifiable, Equatable {
    var id = UUID()
    var start: Date
    var end: Date?
    var reminderDate: Date
    var segments: [ExposureSegment]

    static func uv(at date: Date, in samples: [UVSample]) -> Double? {
        UVSample.value(at: date, in: samples)
    }

    // Best-effort threshold from the inherited skin-type model, not a safe-exposure limit.
    // Never project beyond the available forecast or treat missing coverage as safe time.
    func exposureWarningDate(now: Date) -> Date? {
        guard end == nil, let horizon = segments.last?.forecast.last?.date,
              horizon > now else { return nil }
        let elapsed = totals(until: now)
        guard elapsed.coveredSeconds >= max(0, now.timeIntervalSince(start)) - 1 else { return now }
        if elapsed.med >= 1 { return now }
        guard totals(until: horizon).med >= 1 else { return nil }
        var low = now
        var high = horizon
        while high.timeIntervalSince(low) > 1 {
            let middle = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if totals(until: middle).med >= 1 { high = middle } else { low = middle }
        }
        return high
    }

    func totals(until requestedEnd: Date, since requestedStart: Date? = nil) -> ExposureTotals {
        let finish = min(end ?? requestedEnd, requestedEnd)
        let begin = max(start, requestedStart ?? start)
        var result = ExposureTotals()
        guard finish > begin else { return result }
        for index in segments.indices {
            let segment = segments[index]
            let next = index + 1 < segments.count ? segments[index + 1].start : finish
            guard let first = segment.forecast.first, let last = segment.forecast.last else { continue }
            var cursor = max(begin, segment.start, first.date)
            let stop = min(finish, next, last.date)
            // Integrate within forecast coverage only. Never extrapolate a stale rate.
            while cursor < stop {
                let boundary = segment.forecast.first(where: { $0.date > cursor })?.date ?? stop
                let stepEnd = min(stop, cursor.addingTimeInterval(60), boundary)
                if let a = Self.uv(at: cursor, in: segment.forecast),
                   let b = Self.uv(at: stepEnd, in: segment.forecast) {
                    let seconds = stepEnd.timeIntervalSince(cursor)
                    result.iu += (segment.settings.hourlyIU(uv: a) + segment.settings.hourlyIU(uv: b)) / 2 * seconds / 3600
                    result.med += segment.settings.medPerSecond(uv: (a + b) / 2) * seconds
                    result.coveredSeconds += seconds
                    result.uvSeconds += (a + b) / 2 * seconds
                    result.peakUV = max(result.peakUV, a, b)
                }
                cursor = stepEnd
            }
        }
        return result
    }
}

struct SessionArchive: Codable {
    var version = 1
    var settings = ExposureSettings()
    var active: ExposureSession?
    var completed: [ExposureSession] = []

    mutating func complete(at date: Date) {
        guard var session = active else { return }
        session.end = max(session.start, min(date, session.end ?? date))
        completed.removeAll { $0.id == session.id }
        completed.append(session)
        active = nil
    }
}

// A single atomic file owns both pending and completed sessions. Write before publishing state.
final class SessionFileStore {
    let url: URL
    init(url: URL) { self.url = url }
    func load() throws -> SessionArchive {
        guard FileManager.default.fileExists(atPath: url.path) else { return SessionArchive() }
        let archive = try JSONDecoder().decode(SessionArchive.self, from: Data(contentsOf: url))
        guard archive.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
        return archive
    }
    func save(_ archive: SessionArchive) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var folder = url.deletingLastPathComponent()
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        let data = try JSONEncoder().encode(archive)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
