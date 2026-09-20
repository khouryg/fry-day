import XCTest
#if canImport(FryDay)
@testable import FryDay
#else
@testable import ExposureCore
#endif

final class ExposureSessionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_789_812_000)
    private func forecast(_ uv: Double = 5) -> [UVSample] {
        (0...4).map { UVSample(date: start.addingTimeInterval(Double($0) * 3600), uv: uv) }
    }
    private func session(settings: ExposureSettings = ExposureSettings()) -> ExposureSession {
        ExposureSession(start: start, reminderDate: start.addingTimeInterval(1200), segments: [ExposureSegment(start: start, settings: settings, forecast: forecast())])
    }

    func testBackgroundIntervalCountsElapsedTimeForBothEstimates() {
        let value = session(), end = start.addingTimeInterval(1800)
        let totals = value.totals(until: end)
        XCTAssertEqual(totals.iu, ExposureSettings().hourlyIU(uv: 5) / 2, accuracy: 0.001)
        XCTAssertEqual(totals.med, ExposureSettings().medPerSecond(uv: 5) * 1800, accuracy: 0.000001)
        XCTAssertEqual(totals.coveredSeconds, 1800)
    }
    func testBackgroundAndForegroundGiveSameResult() {
        let value = session(), end = start.addingTimeInterval(1800)
        let expected = value.totals(until: end)
        var iu = 0.0, med = 0.0
        for i in 0..<30 {
            let a = start.addingTimeInterval(Double(i) * 60), b = a.addingTimeInterval(60)
            let part = value.totals(until: b, since: a)
            iu += part.iu; med += part.med
        }
        XCTAssertEqual(iu, expected.iu, accuracy: 0.000001)
        XCTAssertEqual(med, expected.med, accuracy: 0.000001)
    }
    func testCorrectedEndTimeRecalculatesAmount() {
        let value = session()
        let hour = value.totals(until: start.addingTimeInterval(3600))
        let tenMinutes = value.totals(until: start.addingTimeInterval(600))
        XCTAssertEqual(tenMinutes.iu * 6, hour.iu, accuracy: 0.001)
    }
    func testSettingsChangeDoesNotRewriteEarlierExposure() {
        var value = session()
        var covered = ExposureSettings(); covered.clothing = .heavy
        value.segments.append(ExposureSegment(start: start.addingTimeInterval(1800), settings: covered, forecast: forecast()))
        let expected = (ExposureSettings().hourlyIU(uv: 5) + covered.hourlyIU(uv: 5)) / 2
        XCTAssertEqual(value.totals(until: start.addingTimeInterval(3600)).iu, expected, accuracy: 0.001)
    }
    func testNewForecastDoesNotRewriteElapsedExposure() {
        var value = session()
        value.segments.append(ExposureSegment(start: start.addingTimeInterval(1800), settings: ExposureSettings(), forecast: forecast(0)))
        XCTAssertEqual(value.totals(until: start.addingTimeInterval(3600)).iu, ExposureSettings().hourlyIU(uv: 5) / 2, accuracy: 0.001)
    }
    func testMissingForecastIsNotExtrapolated() {
        let totals = session().totals(until: start.addingTimeInterval(6 * 3600))
        XCTAssertEqual(totals.coveredSeconds, 4 * 3600)
        XCTAssertEqual(totals.iu, ExposureSettings().hourlyIU(uv: 5) * 4, accuracy: 0.001)
    }
    func testMissingHourlyValueIsNotInterpolatedAcrossGap() {
        let samples = [UVSample(date: start, uv: 5), UVSample(date: start.addingTimeInterval(7200), uv: 5)]
        XCTAssertNil(ExposureSession.uv(at: start.addingTimeInterval(3600), in: samples))
    }
    func testCompletedSessionNeverAccruesMoreTime() {
        var value = session(); value.end = start.addingTimeInterval(600)
        XCTAssertEqual(value.totals(until: start.addingTimeInterval(7200)), value.totals(until: start.addingTimeInterval(600)))
    }
    func testDailyTotalsSplitAtBoundary() {
        let value = session(), boundary = start.addingTimeInterval(1800), end = start.addingTimeInterval(3600)
        let first = value.totals(until: boundary), second = value.totals(until: end, since: boundary)
        XCTAssertEqual(first.iu + second.iu, value.totals(until: end).iu, accuracy: 0.001)
    }
    func testAtomicArchiveRestoresOlderUnfinishedSession() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SessionFileStore(url: folder.appendingPathComponent("sessions.json"))
        let archive = SessionArchive(active: session())
        try store.save(archive)
        let restored = try store.load()
        XCTAssertEqual(restored.active?.id, archive.active?.id)
        XCTAssertEqual(restored.active?.start, start)
    }
    func testCompletionIsIdempotentAndNotDoubleCounted() {
        var archive = SessionArchive(active: session())
        archive.complete(at: start.addingTimeInterval(600))
        archive.complete(at: start.addingTimeInterval(600))
        XCTAssertNil(archive.active)
        XCTAssertEqual(archive.completed.count, 1)
    }
    func testCorruptArchiveFailsInsteadOfReturningEmptyHistory() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("sessions.json")
        try Data("not JSON".utf8).write(to: url)
        XCTAssertThrowsError(try SessionFileStore(url: url).load())
        XCTAssertEqual(try String(contentsOf: url), "not JSON")
    }
    func testFailedWriteLeavesCallerStateUnchanged() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data().write(to: file)
        let archive = SessionArchive(active: session())
        XCTAssertThrowsError(try SessionFileStore(url: file.appendingPathComponent("sessions.json")).save(archive))
        XCTAssertNotNil(archive.active)
    }
    func testAgeFactorHasNoSeventiethBirthdayCliff() {
        var a = ExposureSettings(), b = ExposureSettings(); a.age = 69; b.age = 70
        XCTAssertLessThan(abs(a.hourlyIU(uv: 5) - b.hourlyIU(uv: 5)) / a.hourlyIU(uv: 5), 0.06)
    }
    func testInvalidUVDoesNotProduceInvalidAmounts() {
        XCTAssertEqual(ExposureSettings().hourlyIU(uv: .nan), 0)
        XCTAssertEqual(ExposureSettings().hourlyIU(uv: -5), 0)
    }
}
