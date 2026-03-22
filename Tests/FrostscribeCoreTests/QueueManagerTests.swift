import Testing
@testable import FrostscribeCore
import Foundation

@Suite("QueueManager")
struct QueueManagerTests {
    private func makeTemp() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "frostscribe-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Read empty queue

    @Test func readReturnsEmptyWhenNoFile() throws {
        let qm = QueueManager(appSupportURL: makeTemp())
        let jobs = try qm.read()
        #expect(jobs.isEmpty)
    }

    // MARK: - Add

    @Test func addCreatesJob() throws {
        let dir = makeTemp()
        let qm = QueueManager(appSupportURL: dir)

        try qm.add(
            input: URL(fileURLWithPath: "/tmp/input.mkv"),
            output: URL(fileURLWithPath: "/tmp/output.mkv"),
            preset: "H.265 MKV 1080p30",
            title: "The Matrix"
        )

        let jobs = try qm.read()
        #expect(jobs.count == 1)
        #expect(jobs[0].title == "The Matrix")
        #expect(jobs[0].status == .pending)
        #expect(jobs[0].progress == "—")
    }

    @Test func addMultipleJobsPreservesOrder() throws {
        let dir = makeTemp()
        let qm = QueueManager(appSupportURL: dir)

        try qm.add(input: URL(fileURLWithPath: "/a.mkv"), output: URL(fileURLWithPath: "/a-out.mkv"), preset: "preset", title: "Alpha")
        try qm.add(input: URL(fileURLWithPath: "/b.mkv"), output: URL(fileURLWithPath: "/b-out.mkv"), preset: "preset", title: "Beta")

        let jobs = try qm.read()
        #expect(jobs.count == 2)
        #expect(jobs[0].title == "Alpha")
        #expect(jobs[1].title == "Beta")
    }

    @Test func addWithEpisodeLabel() throws {
        let dir = makeTemp()
        let qm = QueueManager(appSupportURL: dir)

        try qm.add(
            input: URL(fileURLWithPath: "/tmp/input.mkv"),
            output: URL(fileURLWithPath: "/tmp/output.mkv"),
            preset: "preset",
            title: "Breaking Bad",
            episode: "S01E01"
        )

        let jobs = try qm.read()
        #expect(jobs[0].episode == "S01E01")
        #expect(jobs[0].label == "Breaking Bad — S01E01")
    }

    // MARK: - Update status

    @Test func updateStatusToDone() throws {
        let dir = makeTemp()
        let qm = QueueManager(appSupportURL: dir)
        try qm.add(input: URL(fileURLWithPath: "/a.mkv"), output: URL(fileURLWithPath: "/a-out.mkv"), preset: "p", title: "Alpha")
        let id = try qm.read()[0].id

        try qm.updateStatus(id: id, status: .done, completedAt: .now)

        let jobs = try qm.read()
        #expect(jobs[0].status == .done)
        #expect(jobs[0].completedAt != nil)
    }

    @Test func updateStatusToEncoding() throws {
        let dir = makeTemp()
        let qm = QueueManager(appSupportURL: dir)
        try qm.add(input: URL(fileURLWithPath: "/a.mkv"), output: URL(fileURLWithPath: "/a-out.mkv"), preset: "p", title: "Alpha")
        let id = try qm.read()[0].id

        try qm.updateStatus(id: id, status: .encoding)

        let jobs = try qm.read()
        #expect(jobs[0].status == .encoding)
    }

    @Test func updateStatusIgnoresUnknownID() throws {
        let dir = makeTemp()
        let qm = QueueManager(appSupportURL: dir)
        try qm.add(input: URL(fileURLWithPath: "/a.mkv"), output: URL(fileURLWithPath: "/a-out.mkv"), preset: "p", title: "Alpha")

        try qm.updateStatus(id: UUID(), status: .done)

        let jobs = try qm.read()
        #expect(jobs[0].status == .pending)
    }

    // MARK: - Update progress

    @Test func updateProgress() throws {
        let dir = makeTemp()
        let qm = QueueManager(appSupportURL: dir)
        try qm.add(input: URL(fileURLWithPath: "/a.mkv"), output: URL(fileURLWithPath: "/a-out.mkv"), preset: "p", title: "Alpha")
        let id = try qm.read()[0].id

        try qm.updateProgress(id: id, progress: "42.5%")

        let jobs = try qm.read()
        #expect(jobs[0].progress == "42.5%")
    }

    // MARK: - Active jobs

    @Test func activeJobsFiltersCorrectly() throws {
        let dir = makeTemp()
        let qm = QueueManager(appSupportURL: dir)
        try qm.add(input: URL(fileURLWithPath: "/a.mkv"), output: URL(fileURLWithPath: "/a-out.mkv"), preset: "p", title: "Alpha")
        try qm.add(input: URL(fileURLWithPath: "/b.mkv"), output: URL(fileURLWithPath: "/b-out.mkv"), preset: "p", title: "Beta")

        let firstID = try qm.read()[0].id
        try qm.updateStatus(id: firstID, status: .done)

        let active = try qm.activeJobs()
        #expect(active.count == 1)
        #expect(active[0].title == "Beta")
    }

    // MARK: - isActive property

    @Test func isActiveTrueForPendingAndEncoding() {
        let pending = EncodeJob(title: "A", input: "/a", output: "/b", preset: "p", status: .pending)
        let encoding = EncodeJob(title: "A", input: "/a", output: "/b", preset: "p", status: .encoding)
        let done = EncodeJob(title: "A", input: "/a", output: "/b", preset: "p", status: .done)
        let error = EncodeJob(title: "A", input: "/a", output: "/b", preset: "p", status: .error)

        #expect(pending.isActive)
        #expect(encoding.isActive)
        #expect(!done.isActive)
        #expect(!error.isActive)
    }
}
