import XCTest
#if canImport(FryDay)
@testable import FryDay
#else
@testable import ExposureCore
#endif

final class EfficiencyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_789_812_013)
    private func session() -> ExposureSession {
        let samples = (0...8).map {
            UVSample(date: start.addingTimeInterval(Double($0) * 3600 - 13), uv: Double(8 - $0))
        }
        return ExposureSession(start: start, reminderDate: start.addingTimeInterval(1200),
            segments: [ExposureSegment(start: start, settings: ExposureSettings(), forecast: samples)])
    }
    private func assertSame(_ a: ExposureTotals, _ b: ExposureTotals, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.iu, b.iu, accuracy: 0.000001, file: file, line: line)
        XCTAssertEqual(a.med, b.med, accuracy: 0.000001, file: file, line: line)
        XCTAssertEqual(a.coveredSeconds, b.coveredSeconds, accuracy: 0.000001, file: file, line: line)
        XCTAssertEqual(a.averageUV, b.averageUV, accuracy: 0.000001, file: file, line: line)
        XCTAssertEqual(a.peakUV, b.peakUV, accuracy: 0.000001, file: file, line: line)
    }
    func testIncrementalEstimatesMatchFullCalculationAtEverySecond() {
        let value = session()
        var cache = ExposureTotalsAccumulator()
        for second in 0...3700 {
            let end = start.addingTimeInterval(Double(second))
            assertSame(cache.totals(for: value, until: end), value.totals(until: end))
        }
    }
    func testNextTickDoesNotReprocessHoursOfExposure() {
        let value = session()
        var cache = ExposureTotalsAccumulator()
        let end = start.addingTimeInterval(6 * 3600 + 31)
        _ = cache.totals(for: value, until: end)
        let next = end.addingTimeInterval(1)
        assertSame(cache.totals(for: value, until: next), value.totals(until: next))
        XCTAssertEqual(cache.evaluatedSteps, 1)
    }
    func testSettingsForecastAndCorrectedEndInvalidateCache() {
        var value = session()
        var cache = ExposureTotalsAccumulator()
        _ = cache.totals(for: value, until: start.addingTimeInterval(1800))
        var settings = ExposureSettings(); settings.clothing = .heavy
        value.segments.append(ExposureSegment(start: start.addingTimeInterval(1827), settings: settings,
            forecast: value.segments[0].forecast.map { UVSample(date: $0.date, uv: $0.uv / 2) }))
        for seconds in [1827.0, 1840, 1887, 3601, 7200] {
            let end = start.addingTimeInterval(seconds)
            assertSame(cache.totals(for: value, until: end), value.totals(until: end))
        }
        value.end = start.addingTimeInterval(1500)
        let now = start.addingTimeInterval(8000)
        assertSame(cache.totals(for: value, until: now), value.totals(until: now))
    }
    func testCacheHandlesDayBoundaryClockReversalAndForecastGaps() {
        var value = session()
        value.segments[0].forecast.remove(at: 2)
        var cache = ExposureTotalsAccumulator()
        for (seconds, sinceSeconds) in [(9000.0, 0.0), (10000, 9131), (9900, 9131), (40000, 9131)] {
            let end = start.addingTimeInterval(seconds), since = start.addingTimeInterval(sinceSeconds)
            assertSame(cache.totals(for: value, until: end, since: since), value.totals(until: end, since: since))
        }
    }
    func testFreshCacheIsReusedAfterLaunch() {
        let policy = ForegroundRefreshPolicy()
        XCTAssertFalse(policy.shouldFetch(now: start.addingTimeInterval(120), updatedAt: start,
            nearby: true, hasCoverage: true, isTracking: false))
    }
    func testActiveSessionsRetainFiveMinuteForecastRefresh() {
        let policy = ForegroundRefreshPolicy(), now = start.addingTimeInterval(301)
        XCTAssertTrue(policy.shouldFetch(now: now, updatedAt: start, nearby: true, hasCoverage: true, isTracking: true))
        XCTAssertFalse(policy.shouldFetch(now: now, updatedAt: start, nearby: true, hasCoverage: true, isTracking: false))
        XCTAssertTrue(policy.shouldFetch(now: start.addingTimeInterval(600), updatedAt: start, nearby: true, hasCoverage: true, isTracking: false))
    }
    func testMovementAndMissingCoverageRefreshEvenWhenForecastIsYoung() {
        let policy = ForegroundRefreshPolicy(), now = start.addingTimeInterval(120)
        XCTAssertTrue(policy.shouldFetch(now: now, updatedAt: start, nearby: false, hasCoverage: true, isTracking: true))
        XCTAssertTrue(policy.shouldFetch(now: now, updatedAt: start, nearby: true, hasCoverage: false, isTracking: true))
    }
    func testLocationCallbacksCannotCauseRequestBurst() {
        var policy = ForegroundRefreshPolicy()
        policy.began(at: start)
        XCTAssertFalse(policy.shouldFetch(now: start.addingTimeInterval(10), updatedAt: nil, nearby: false, hasCoverage: false, isTracking: true))
        XCTAssertTrue(policy.shouldFetch(now: start.addingTimeInterval(60), updatedAt: nil, nearby: false, hasCoverage: false, isTracking: true))
    }
    func testRetryBackoffCapsAndResetsAfterSuccess() throws {
        var policy = ForegroundRefreshPolicy()
        for delay in [60.0, 120, 240, 480, 900, 900] {
            policy.failed(at: start)
            XCTAssertEqual(try XCTUnwrap(policy.retryAfter).timeIntervalSince(start), delay)
            XCTAssertFalse(policy.shouldFetch(now: start.addingTimeInterval(delay - 1), updatedAt: nil, nearby: false, hasCoverage: false, isTracking: true))
            XCTAssertTrue(policy.shouldFetch(now: start.addingTimeInterval(delay), updatedAt: nil, nearby: false, hasCoverage: false, isTracking: true))
        }
        policy.succeeded()
        XCTAssertNil(policy.retryAfter)
        policy.failed(at: start)
        XCTAssertEqual(try XCTUnwrap(policy.retryAfter).timeIntervalSince(start), 60)
    }
    func testConnectivityRecoveryRemovesLongBackoffButKeepsBurstLimit() {
        var policy = ForegroundRefreshPolicy()
        policy.began(at: start)
        for _ in 0..<5 { policy.failed(at: start) }
        policy.succeeded()
        XCTAssertFalse(policy.shouldFetch(now: start.addingTimeInterval(10), updatedAt: nil, nearby: false, hasCoverage: false, isTracking: true))
        XCTAssertTrue(policy.shouldFetch(now: start.addingTimeInterval(60), updatedAt: nil, nearby: false, hasCoverage: false, isTracking: true))
    }
    func testExplicitRetryCanBypassBackoff() {
        var policy = ForegroundRefreshPolicy()
        policy.began(at: start); policy.failed(at: start)
        XCTAssertTrue(policy.shouldFetch(now: start, updatedAt: nil, nearby: true, hasCoverage: false, isTracking: true, force: true))
    }
}
