import Foundation

/// Keeps fully elapsed integration steps in memory. The unfinished step is recalculated,
/// so a one-second UI tick gives the same estimate as a fresh calculation after relaunch.
struct ExposureTotalsAccumulator {
    private struct Progress {
        var cursor: Date
        var totals = ExposureTotals()
    }
    private var previousSession: ExposureSession?
    private var previousSince: Date?
    private var previousEnd = Date.distantPast
    private var progress: [Int: Progress] = [:]
    private(set) var evaluatedSteps = 0

    mutating func totals(for session: ExposureSession, until end: Date, since: Date? = nil) -> ExposureTotals {
        if session != previousSession || since != previousSince || end < previousEnd {
            progress = [:]
            previousSession = session
            previousSince = since
        }
        previousEnd = end
        evaluatedSteps = 0
        let finish = min(session.end ?? end, end)
        let begin = max(session.start, since ?? session.start)
        guard finish > begin else { return ExposureTotals() }
        var result = ExposureTotals()
        for index in session.segments.indices {
            let segment = session.segments[index]
            guard let first = segment.forecast.first, let last = segment.forecast.last else { continue }
            let next = index + 1 < session.segments.count ? session.segments[index + 1].start : Date.distantFuture
            let stop = min(next, last.date, session.end ?? .distantFuture)
            var state = progress[index] ?? Progress(cursor: max(begin, segment.start, first.date))
            var partial = ExposureTotals()
            while state.cursor < min(stop, finish) {
                let boundary = segment.forecast.first(where: { $0.date > state.cursor })?.date ?? stop
                let fullStepEnd = min(stop, state.cursor.addingTimeInterval(60), boundary)
                let stepEnd = min(finish, fullStepEnd)
                let delta = Self.integrate(segment, from: state.cursor, to: stepEnd)
                evaluatedSteps += 1
                if stepEnd == fullStepEnd {
                    state.totals.add(delta)
                    state.cursor = stepEnd
                } else {
                    partial = delta
                    break
                }
            }
            progress[index] = state
            result.add(state.totals)
            result.add(partial)
        }
        return result
    }

    private static func integrate(_ segment: ExposureSegment, from start: Date, to end: Date) -> ExposureTotals {
        guard let a = ExposureSession.uv(at: start, in: segment.forecast),
              let b = ExposureSession.uv(at: end, in: segment.forecast) else { return ExposureTotals() }
        let seconds = end.timeIntervalSince(start)
        return ExposureTotals(
            iu: (segment.settings.hourlyIU(uv: a) + segment.settings.hourlyIU(uv: b)) / 2 * seconds / 3600,
            med: segment.settings.medPerSecond(uv: (a + b) / 2) * seconds,
            coveredSeconds: seconds, uvSeconds: (a + b) / 2 * seconds, peakUV: max(a, b))
    }
}

private extension ExposureTotals {
    mutating func add(_ other: ExposureTotals) {
        iu += other.iu
        med += other.med
        coveredSeconds += other.coveredSeconds
        uvSeconds += other.uvSeconds
        peakUV = max(peakUV, other.peakUV)
    }
}
