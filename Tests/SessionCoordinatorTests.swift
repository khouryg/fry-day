#if canImport(FryDay)
import XCTest
@testable import FryDay

final class SessionCoordinatorTests: XCTestCase {
    @MainActor
    func testTodayCacheUpdatesAfterManualSaveDeleteAndReload() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SessionFileStore(url: folder.appendingPathComponent("sessions.json"))
        let coordinator = VitaminDCalculator(store: store)
        let now = Date(), day = Calendar.current.startOfDay(for: now)
        let end = now.addingTimeInterval(-0.1), start = max(day, end.addingTimeInterval(-60))
        let forecast = [UVSample(date: start, uv: 5), UVSample(date: now, uv: 5)]
        XCTAssertTrue(coordinator.addManualSession(start: start, end: end, settings: ExposureSettings(), forecast: forecast))
        let saved = try XCTUnwrap(coordinator.completed.first)
        let expected = saved.totals(until: end).iu
        XCTAssertEqual(coordinator.todayTotal, expected, accuracy: 0.000001)
        coordinator.refresh()
        XCTAssertEqual(coordinator.todayTotal, expected, accuracy: 0.000001)
        coordinator.reload()
        XCTAssertEqual(coordinator.todayTotal, expected, accuracy: 0.000001)
        coordinator.deleteSession(id: saved.id)
        XCTAssertEqual(coordinator.todayTotal, 0)
    }

    @MainActor
    func testSavingPendingSessionDoesNotDoubleCountCachedTotal() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SessionFileStore(url: folder.appendingPathComponent("sessions.json"))
        let now = Date(), start = now.addingTimeInterval(-60)
        let pending = ExposureSession(start: start, end: now, reminderDate: now,
            segments: [ExposureSegment(start: start, settings: ExposureSettings(),
                forecast: [UVSample(date: start, uv: 5), UVSample(date: now, uv: 5)])])
        try store.save(SessionArchive(active: pending))
        let coordinator = VitaminDCalculator(store: store)
        let before = coordinator.todayTotal
        XCTAssertTrue(coordinator.saveSession(end: now))
        XCTAssertNil(coordinator.active)
        XCTAssertEqual(coordinator.completed.count, 1)
        XCTAssertEqual(coordinator.todayTotal, before, accuracy: 0.000001)
        XCTAssertFalse(coordinator.saveSession(end: now))
        XCTAssertEqual(coordinator.todayTotal, before, accuracy: 0.000001)
    }
}
#endif
