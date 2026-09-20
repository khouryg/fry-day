#if canImport(FryDay) && canImport(HealthKit)
import XCTest
import HealthKit
@testable import FryDay

@MainActor
final class HealthExportTests: XCTestCase {
    private func session() -> ExposureSession {
        let start = Date(timeIntervalSince1970: 1_789_812_000)
        let end = start.addingTimeInterval(60)
        return ExposureSession(start: start, end: end, reminderDate: end, segments: [ExposureSegment(start: start, settings: ExposureSettings(), forecast: [UVSample(date: start, uv: 5), UVSample(date: end, uv: 5)])])
    }
    func testExportConvertsIUToMicrogramsAndPreservesInterval() throws {
        let value = session()
        let sample = try XCTUnwrap(HealthManager.vitaminDSample(for: value))
        XCTAssertEqual(sample.quantity.doubleValue(for: .gramUnit(with: .micro)), value.totals(until: value.end!).iu * 0.025, accuracy: 0.000001)
        XCTAssertEqual(sample.startDate, value.start)
        XCTAssertEqual(sample.endDate, value.end)
        XCTAssertEqual(sample.quantityType.identifier, HKQuantityTypeIdentifier.dietaryVitaminD.rawValue)
        XCTAssertTrue((sample.metadata?["FryDayEstimateSource"] as? String)?.contains("not food or supplements") == true)
    }
    func testRetryUsesSameSyncIdentityAndDistinctSessionsDoNotCollide() throws {
        let first = session()
        var second = first; second.id = UUID()
        let a = try XCTUnwrap(HealthManager.vitaminDSample(for: first))
        let retry = try XCTUnwrap(HealthManager.vitaminDSample(for: first))
        let b = try XCTUnwrap(HealthManager.vitaminDSample(for: second))
        XCTAssertEqual(a.metadata?[HKMetadataKeySyncIdentifier] as? String, retry.metadata?[HKMetadataKeySyncIdentifier] as? String)
        XCTAssertNotEqual(a.metadata?[HKMetadataKeySyncIdentifier] as? String, b.metadata?[HKMetadataKeySyncIdentifier] as? String)
        XCTAssertEqual(a.metadata?[HKMetadataKeySyncVersion] as? Int, 1)
    }
    func testCorrectedEndExportsOnlySavedInterval() throws {
        var value = session(); value.end = value.start.addingTimeInterval(30)
        let sample = try XCTUnwrap(HealthManager.vitaminDSample(for: value))
        XCTAssertEqual(sample.quantity.doubleValue(for: .gramUnit(with: .micro)), ExposureSettings().hourlyIU(uv: 5) / 120 * 0.025, accuracy: 0.000001)
    }
    func testNoExportForActiveZeroOrInvalidInterval() {
        var value = session(); value.end = nil
        XCTAssertNil(HealthManager.vitaminDSample(for: value))
        value.end = value.start
        XCTAssertNil(HealthManager.vitaminDSample(for: value))
        value = session(); value.segments = []
        XCTAssertNil(HealthManager.vitaminDSample(for: value))
    }
}
#endif
