import Foundation

struct ForegroundRefreshPolicy {
    private(set) var lastAttempt: Date?
    private(set) var failureCount = 0
    private(set) var retryAfter: Date?

    func shouldFetch(now: Date, updatedAt: Date?, nearby: Bool, hasCoverage: Bool,
                     isTracking: Bool, force: Bool = false) -> Bool {
        if force { return true }
        if let retryAfter, now < retryAfter { return false }
        // Bound automatic requests even when multiple location callbacks arrive while traveling.
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < 60 { return false }
        let interval: TimeInterval = isTracking ? 300 : 600
        return !nearby || !hasCoverage || (updatedAt.map { now.timeIntervalSince($0) >= interval } ?? true)
    }
    mutating func began(at date: Date) { lastAttempt = date }
    mutating func succeeded() { failureCount = 0; retryAfter = nil }
    mutating func failed(at date: Date) {
        failureCount = min(failureCount + 1, 5)
        retryAfter = date.addingTimeInterval(min(900, 60 * pow(2, Double(failureCount - 1))))
    }
}
