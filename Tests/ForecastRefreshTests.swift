import XCTest
#if canImport(FryDay)
@testable import FryDay
#else
@testable import ExposureCore
#endif

final class ForecastRefreshTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_789_812_000)
    private func snapshot() -> WeatherSnapshot {
        WeatherSnapshot(latitude: 37.7, longitude: -122.4, updatedAt: start,
            samples: [UVSample(date: start, uv: 8), UVSample(date: start.addingTimeInterval(3600), uv: 4), UVSample(date: start.addingTimeInterval(7200), uv: 0)],
            maxUV: 8, sunrise: nil, sunset: nil)
    }
    func testWidgetUVAdvancesWithoutNetworkFetch() throws {
        let value = snapshot()
        XCTAssertEqual(try XCTUnwrap(ForecastRefreshPolicy.uv(at: start.addingTimeInterval(900), snapshot: value)), 7, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(ForecastRefreshPolicy.uv(at: start.addingTimeInterval(1800), snapshot: value)), 6, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(ForecastRefreshPolicy.uv(at: start.addingTimeInterval(5400), snapshot: value)), 2, accuracy: 0.001)
    }
    func testFreshForecastDoesNotRequestNetworkRefresh() {
        XCTAssertFalse(ForecastRefreshPolicy.shouldRefresh(now: start.addingTimeInterval(3600), updatedAt: start, lastAttempt: nil))
        XCTAssertTrue(ForecastRefreshPolicy.shouldRefresh(now: start.addingTimeInterval(10800), updatedAt: start, lastAttempt: nil))
    }
    func testFailureRetryIsThrottled() {
        let now = start.addingTimeInterval(15000)
        XCTAssertFalse(ForecastRefreshPolicy.shouldRefresh(now: now, updatedAt: start, lastAttempt: now.addingTimeInterval(-60)))
        XCTAssertTrue(ForecastRefreshPolicy.shouldRefresh(now: now, updatedAt: start, lastAttempt: now.addingTimeInterval(-10800)))
    }
    func testOutOfCoverageNeverDisplaysFrozenUV() {
        XCTAssertNil(ForecastRefreshPolicy.uv(at: start.addingTimeInterval(8000), snapshot: snapshot()))
    }
    func testOldForecastExpiresEvenWithCoverage() {
        var value = snapshot()
        value.updatedAt = start.addingTimeInterval(-90000)
        XCTAssertNil(ForecastRefreshPolicy.uv(at: start.addingTimeInterval(900), snapshot: value))
    }
    func testTimelineHasQuarterHourEntriesAndExpiryCoverage() {
        let dates = ForecastRefreshPolicy.timelineDates(from: start)
        XCTAssertEqual(dates.count, 97)
        XCTAssertEqual(dates[1].timeIntervalSince(dates[0]), 900)
        XCTAssertEqual(dates.last?.timeIntervalSince(start), 86400)
    }
}
