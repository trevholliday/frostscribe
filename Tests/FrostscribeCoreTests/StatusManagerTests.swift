import Testing
@testable import FrostscribeCore
import Foundation

@Suite("StatusManager")
struct StatusManagerTests {

    private func makeStatusManager() -> StatusManager {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "status-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return StatusManager(appSupportURL: dir)
    }

    // MARK: - Read when file is missing

    @Test func readReturnsIdleWhenFileMissing() throws {
        let sm = makeStatusManager()
        let file = try sm.read()
        #expect(file.status == .idle)
        #expect(file.currentJob == nil)
        #expect(file.history.isEmpty)
    }

    // MARK: - Write + read round-trip

    @Test func writeAndReadRoundTripsStatus() throws {
        let sm = makeStatusManager()
        try sm.write(status: .ripping, job: nil)
        let file = try sm.read()
        #expect(file.status == .ripping)
    }

    @Test func writeAndReadRoundTripsJob() throws {
        let sm = makeStatusManager()
        let job = RipJob(type: .movie, title: "Inception")
        try sm.write(status: .ripping, job: job)
        let file = try sm.read()
        #expect(file.currentJob?.title == "Inception")
        #expect(file.currentJob?.type == .movie)
    }

    @Test func writeAndReadRoundTripsEncoding() throws {
        let sm = makeStatusManager()
        try sm.write(status: .encoding, job: nil)
        let file = try sm.read()
        #expect(file.status == .encoding)
    }

    // MARK: - Status transitions

    @Test func statusTransitionsFromRippingToIdle() throws {
        let sm = makeStatusManager()
        try sm.write(status: .ripping, job: RipJob(type: .movie, title: "Test"))
        try sm.write(status: .idle, job: nil)
        let file = try sm.read()
        #expect(file.status == .idle)
        #expect(file.currentJob == nil)
    }

    // MARK: - History: currentJob appended when going idle

    @Test func historyAppendedWhenTransitioningToIdle() throws {
        let sm = makeStatusManager()
        let job = RipJob(type: .movie, title: "The Matrix")
        try sm.write(status: .ripping, job: job)
        try sm.write(status: .idle, job: nil)

        let file = try sm.read()
        #expect(file.history.count == 1)
        #expect(file.history[0].title == "The Matrix")
    }

    @Test func historyNotAppendedWhenTransitioningToNonIdle() throws {
        let sm = makeStatusManager()
        let job = RipJob(type: .movie, title: "Movie A")
        try sm.write(status: .ripping, job: job)
        try sm.write(status: .encoding, job: nil)

        let file = try sm.read()
        #expect(file.history.isEmpty)
    }

    @Test func historyNotAppendedWhenNoCurrentJobAtIdle() throws {
        let sm = makeStatusManager()
        try sm.write(status: .ripping, job: nil)
        try sm.write(status: .idle, job: nil)

        let file = try sm.read()
        #expect(file.history.isEmpty)
    }

    // MARK: - History capped at 20

    @Test func historyIsCappedAt20Entries() throws {
        let sm = makeStatusManager()

        for i in 1...21 {
            try sm.write(status: .ripping, job: RipJob(type: .movie, title: "Movie \(i)"))
            try sm.write(status: .idle, job: nil)
        }

        let file = try sm.read()
        #expect(file.history.count == 20)
    }

    @Test func historyMostRecentIsFirst() throws {
        let sm = makeStatusManager()

        for i in 1...3 {
            try sm.write(status: .ripping, job: RipJob(type: .movie, title: "Movie \(i)"))
            try sm.write(status: .idle, job: nil)
        }

        let file = try sm.read()
        // history is inserted at index 0, so newest first
        #expect(file.history[0].title == "Movie 3")
        #expect(file.history[1].title == "Movie 2")
        #expect(file.history[2].title == "Movie 1")
    }

    @Test func multipleWritesAccumulateHistory() throws {
        let sm = makeStatusManager()
        for i in 1...5 {
            try sm.write(status: .ripping, job: RipJob(type: .tvshow, title: "Episode \(i)"))
            try sm.write(status: .idle, job: nil)
        }

        let file = try sm.read()
        #expect(file.history.count == 5)
    }
}
