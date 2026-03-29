import Testing
@testable import FrostscribeCore
import Foundation

@Suite("RipHistoryStore")
struct RipHistoryStoreTests {

    private func makeStore() -> (RipHistoryStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "riphistory-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = RipHistoryStore(appSupportURL: dir)
        return (store, dir)
    }

    // MARK: - Append + load round-trip

    @Test func appendAndLoadRoundTrips() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let record = RipRecord(
            discType: .dvd,
            titleSizeBytes: 1_000_000,
            ripDurationSeconds: 60.0,
            jobLabel: "The Matrix",
            success: true
        )
        try store.append(record)

        let loaded = store.load()
        #expect(loaded.count == 1)
        #expect(loaded[0].jobLabel == "The Matrix")
        #expect(loaded[0].discType == .dvd)
        #expect(loaded[0].titleSizeBytes == 1_000_000)
        #expect(loaded[0].ripDurationSeconds == 60.0)
        #expect(loaded[0].success == true)
    }

    @Test func multipleRecordsStoredAndRetrieved() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let records = [
            RipRecord(discType: .dvd, titleSizeBytes: 500_000, ripDurationSeconds: 30.0, jobLabel: "Movie A", success: true),
            RipRecord(discType: .bluray, titleSizeBytes: 5_000_000, ripDurationSeconds: 120.0, jobLabel: "Movie B", success: true),
            RipRecord(discType: .uhd, titleSizeBytes: 10_000_000, ripDurationSeconds: 200.0, jobLabel: "Movie C", success: false),
        ]

        for record in records {
            try store.append(record)
        }

        let loaded = store.load()
        #expect(loaded.count == 3)
    }

    // MARK: - success flag persists

    @Test func successFlagPersistsTrue() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let record = RipRecord(discType: .bluray, titleSizeBytes: 2_000_000, ripDurationSeconds: 90.0, jobLabel: "Inception", success: true)
        try store.append(record)

        let loaded = store.load()
        #expect(loaded[0].success == true)
    }

    @Test func successFlagPersistsFalse() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let record = RipRecord(discType: .dvd, titleSizeBytes: 800_000, ripDurationSeconds: 45.0, jobLabel: "Failed Rip", success: false)
        try store.append(record)

        let loaded = store.load()
        #expect(loaded[0].success == false)
    }

    // MARK: - discType persists for all cases

    @Test func discTypeDVDPersists() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let record = RipRecord(discType: .dvd, titleSizeBytes: 1, ripDurationSeconds: 1, jobLabel: "x", success: true)
        try store.append(record)
        let loaded = store.load()
        #expect(loaded[0].discType == .dvd)
    }

    @Test func discTypeBlurayPersists() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let record = RipRecord(discType: .bluray, titleSizeBytes: 1, ripDurationSeconds: 1, jobLabel: "x", success: true)
        try store.append(record)
        let loaded = store.load()
        #expect(loaded[0].discType == .bluray)
    }

    @Test func discTypeUHDPersists() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let record = RipRecord(discType: .uhd, titleSizeBytes: 1, ripDurationSeconds: 1, jobLabel: "x", success: true)
        try store.append(record)
        let loaded = store.load()
        #expect(loaded[0].discType == .uhd)
    }

    @Test func discTypeUnknownPersists() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let record = RipRecord(discType: .unknown, titleSizeBytes: 1, ripDurationSeconds: 1, jobLabel: "x", success: true)
        try store.append(record)
        let loaded = store.load()
        #expect(loaded[0].discType == .unknown)
    }

    // MARK: - Timestamp

    @Test func timestampIsWithinReasonableRange() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Use a small tolerance to account for GRDB storing timestamps at second granularity
        let before = Date(timeIntervalSinceNow: -1)
        let record = RipRecord(discType: .dvd, titleSizeBytes: 1_000, ripDurationSeconds: 10.0, jobLabel: "Quick", success: true)
        try store.append(record)
        let after = Date(timeIntervalSinceNow: 1)

        let loaded = store.load()
        #expect(loaded[0].timestamp >= before)
        #expect(loaded[0].timestamp <= after)
    }

    // MARK: - records(for:near:)

    @Test func recordsForDiscTypeFiltersCorrectly() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let dvd = RipRecord(discType: .dvd, titleSizeBytes: 1_000_000, ripDurationSeconds: 60, jobLabel: "DVD Movie", success: true)
        let bluray = RipRecord(discType: .bluray, titleSizeBytes: 1_000_000, ripDurationSeconds: 30, jobLabel: "BD Movie", success: true)
        try store.append(dvd)
        try store.append(bluray)

        let dvdResults = store.records(for: .dvd, near: 1_000_000)
        #expect(dvdResults.count == 1)
        #expect(dvdResults[0].discType == .dvd)
    }

    @Test func recordsForDiscTypeExcludesFailures() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let failed = RipRecord(discType: .dvd, titleSizeBytes: 1_000_000, ripDurationSeconds: 60, jobLabel: "Failed", success: false)
        try store.append(failed)

        let results = store.records(for: .dvd, near: 1_000_000)
        #expect(results.isEmpty)
    }

    @Test func loadReturnsEmptyWhenNoRecords() {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let loaded = store.load()
        #expect(loaded.isEmpty)
    }

    @Test func loadReturnsNewestFirst() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let older = RipRecord(
            timestamp: Date(timeIntervalSinceNow: -100),
            discType: .dvd, titleSizeBytes: 1, ripDurationSeconds: 1, jobLabel: "Older", success: true
        )
        let newer = RipRecord(
            timestamp: Date(timeIntervalSinceNow: 0),
            discType: .dvd, titleSizeBytes: 1, ripDurationSeconds: 1, jobLabel: "Newer", success: true
        )
        try store.append(older)
        try store.append(newer)

        let loaded = store.load()
        #expect(loaded[0].jobLabel == "Newer")
        #expect(loaded[1].jobLabel == "Older")
    }
}
