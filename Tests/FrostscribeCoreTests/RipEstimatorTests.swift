import Testing
@testable import FrostscribeCore
import Foundation

@Suite("RipEstimator")
struct RipEstimatorTests {

    private func makeStoreAndEstimator() -> (RipHistoryStore, RipEstimator, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "estimator-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = RipHistoryStore(appSupportURL: dir)
        let estimator = RipEstimator(store: store)
        return (store, estimator, dir)
    }

    // MARK: - Fallback rate when no history

    @Test func estimateReturnsFallbackWhenNoHistory() {
        let (_, estimator, dir) = makeStoreAndEstimator()
        defer { try? FileManager.default.removeItem(at: dir) }

        let estimate = estimator.estimate(discType: .dvd, sizeBytes: 9 * 1024 * 1024)
        if case .fallback = estimate.confidence {
            // expected
        } else {
            #expect(Bool(false), "Expected fallback confidence")
        }
        #expect(estimate.seconds > 0)
    }

    @Test func estimateReturnsFallbackWhenOnlyOneRecord() throws {
        let (store, estimator, dir) = makeStoreAndEstimator()
        defer { try? FileManager.default.removeItem(at: dir) }

        let record = RipRecord(discType: .dvd, titleSizeBytes: 9_000_000, ripDurationSeconds: 60, jobLabel: "x", success: true)
        try store.append(record)

        let estimate = estimator.estimate(discType: .dvd, sizeBytes: 9_000_000)
        if case .fallback = estimate.confidence {
            // expected — needs at least 2 records for measured
        } else {
            #expect(Bool(false), "Expected fallback with only 1 record")
        }
    }

    @Test func estimateUsesMeasuredRateWithTwoOrMoreRecords() throws {
        let (store, estimator, dir) = makeStoreAndEstimator()
        defer { try? FileManager.default.removeItem(at: dir) }

        let size = 9_000_000
        let r1 = RipRecord(discType: .dvd, titleSizeBytes: size, ripDurationSeconds: 60, jobLabel: "r1", success: true)
        let r2 = RipRecord(discType: .dvd, titleSizeBytes: size, ripDurationSeconds: 60, jobLabel: "r2", success: true)
        try store.append(r1)
        try store.append(r2)

        let estimate = estimator.estimate(discType: .dvd, sizeBytes: size)
        if case .measured(let count) = estimate.confidence {
            #expect(count == 2)
        } else {
            #expect(Bool(false), "Expected measured confidence")
        }
    }

    // MARK: - BD rate differs from DVD rate

    @Test func blurayRateDiffersFromDVDRate() {
        let (_, estimator, dir) = makeStoreAndEstimator()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Same size, fallback rates: Blu-ray should be faster (fewer seconds)
        let sizeBytes = 18 * 1024 * 1024
        let dvdEst = estimator.estimate(discType: .dvd, sizeBytes: sizeBytes)
        let bdEst = estimator.estimate(discType: .bluray, sizeBytes: sizeBytes)
        // Blu-ray fallback rate is ~18 MB/s vs DVD ~9 MB/s => BD is twice as fast
        #expect(bdEst.seconds < dvdEst.seconds)
    }

    @Test func uhdRateIsFasterThanBluray() {
        let (_, estimator, dir) = makeStoreAndEstimator()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sizeBytes = 30 * 1024 * 1024
        let bdEst = estimator.estimate(discType: .bluray, sizeBytes: sizeBytes)
        let uhdEst = estimator.estimate(discType: .uhd, sizeBytes: sizeBytes)
        #expect(uhdEst.seconds < bdEst.seconds)
    }

    // MARK: - Estimate scales with size

    @Test func estimateScalesWithSize() {
        let (_, estimator, dir) = makeStoreAndEstimator()
        defer { try? FileManager.default.removeItem(at: dir) }

        let small = estimator.estimate(discType: .dvd, sizeBytes: 1_000_000)
        let large = estimator.estimate(discType: .dvd, sizeBytes: 10_000_000)
        #expect(large.seconds > small.seconds)
    }

    @Test func estimateIsProportionalToSize() {
        let (_, estimator, dir) = makeStoreAndEstimator()
        defer { try? FileManager.default.removeItem(at: dir) }

        let base = estimator.estimate(discType: .dvd, sizeBytes: 9_000_000)
        let double = estimator.estimate(discType: .dvd, sizeBytes: 18_000_000)
        // With fallback rates, doubling size should double seconds
        #expect(abs(double.seconds - base.seconds * 2) < 0.001)
    }

    // MARK: - formattedMinutes on RipEstimate

    @Test func formattedMinutesUnderOneMinute() {
        let estimate = RipEstimate(seconds: 30, confidence: .fallback)
        #expect(estimate.formattedMinutes == "<1 min")
    }

    @Test func formattedMinutesExactlyOneMinute() {
        let estimate = RipEstimate(seconds: 60, confidence: .fallback)
        #expect(estimate.formattedMinutes == "~1 min")
    }

    @Test func formattedMinutesFiveMinutes() {
        let estimate = RipEstimate(seconds: 300, confidence: .fallback)
        #expect(estimate.formattedMinutes == "~5 min")
    }

    @Test func formattedMinutesRoundsDown() {
        let estimate = RipEstimate(seconds: 89, confidence: .fallback)
        // 89 / 60 = 1.48 → Int truncates to 1
        #expect(estimate.formattedMinutes == "~1 min")
    }

    @Test func formattedMinutesZeroSeconds() {
        let estimate = RipEstimate(seconds: 0, confidence: .fallback)
        #expect(estimate.formattedMinutes == "<1 min")
    }
}
