import Testing
@testable import FrostscribeCore
import Foundation

// MARK: - Test doubles

final class SpyMakeMKVRunner: MakeMKVRunning, @unchecked Sendable {
    private(set) var ripCallCount = 0
    private(set) var lastTitleNumber: Int?
    var ripError: Error?

    func scan(onMessage: @escaping @Sendable (String) -> Void) async throws -> DiscScanResult {
        DiscScanResult(titles: [], discName: nil, discType: nil)
    }

    func rip(
        titleNumber: Int,
        to destination: URL,
        onMessage: @escaping @Sendable (String) -> Void,
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws {
        ripCallCount += 1
        lastTitleNumber = titleNumber
        if let error = ripError { throw error }
        // Create a fake MKV so RipUseCase.findMKV() succeeds
        FileManager.default.createFile(atPath: destination.appending(path: "t01.mkv").path, contents: nil)
    }
}

final class SpyQueueManager: QueueManaging, @unchecked Sendable {
    struct AddCall {
        let input: URL
        let output: URL
        let preset: String
        let title: String
        let episode: String?
        let audioTracks: [Int]?
    }

    private(set) var addCalls: [AddCall] = []
    var addError: Error?

    func read() throws -> [EncodeJob] { [] }
    func activeJobs() throws -> [EncodeJob] { [] }

    func add(input: URL, output: URL, preset: String, title: String, episode: String?, audioTracks: [Int]?) throws {
        if let error = addError { throw error }
        addCalls.append(AddCall(input: input, output: output, preset: preset, title: title, episode: episode, audioTracks: audioTracks))
    }

    func updateProgress(id: UUID, progress: String) throws {}
    func updateStatus(id: UUID, status: EncodeJob.Status, progress: String?, completedAt: Date?) throws {}
}

final class SpyStatusManager: StatusManaging, @unchecked Sendable {
    struct WriteCall {
        let status: StatusManager.RipperStatus
        let job: RipJob?
    }

    private(set) var writeCalls: [WriteCall] = []

    func read() throws -> StatusManager.StatusFile {
        StatusManager.StatusFile(status: .idle, updatedAt: .now, currentJob: nil, history: [])
    }

    func write(status: StatusManager.RipperStatus, job: RipJob?) throws {
        writeCalls.append(WriteCall(status: status, job: job))
    }
}

final class SpyDiscEjector: DiscEjecting, @unchecked Sendable {
    private(set) var ejectCallCount = 0
    func eject() -> Bool { ejectCallCount += 1; return true }
}

// MARK: - Tests

@Suite("RipUseCase")
struct RipUseCaseTests {
    private func makeTemp() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "riptest-\(UUID().uuidString)")
    }

    private func makeInput(baseTemp: URL, titleNumber: Int = 1, episode: String? = nil) -> RipInput {
        RipInput(
            titleNumber: titleNumber,
            baseTemp: baseTemp,
            outputURL: URL(fileURLWithPath: "/output/Movie.mkv"),
            preset: "H.265 MKV 1080p30",
            jobLabel: "The Matrix (1999)",
            mediaType: .movie,
            title: "The Matrix",
            episode: episode
        )
    }

    private func makeUseCase(
        runner: any MakeMKVRunning = SpyMakeMKVRunner(),
        queue: any QueueManaging = SpyQueueManager(),
        status: any StatusManaging = SpyStatusManager(),
        ejector: any DiscEjecting = SpyDiscEjector()
    ) -> RipUseCase {
        RipUseCase(runner: runner, queue: queue, status: status, ejector: ejector)
    }

    // MARK: - Success path

    @Test func successWritesRippingThenIdle() async throws {
        let status = SpyStatusManager()
        let useCase = makeUseCase(status: status)

        try await useCase.execute(makeInput(baseTemp: makeTemp()), onProgress: { _ in })

        #expect(status.writeCalls.count == 2)
        #expect(status.writeCalls[0].status == .ripping)
        #expect(status.writeCalls[1].status == .idle)
    }

    @Test func successRippingStatusIncludesJobLabel() async throws {
        let status = SpyStatusManager()
        let useCase = makeUseCase(status: status)

        try await useCase.execute(makeInput(baseTemp: makeTemp()), onProgress: { _ in })

        #expect(status.writeCalls[0].job?.title == "The Matrix (1999)")
    }

    @Test func successCallsEjectorOnce() async throws {
        let ejector = SpyDiscEjector()
        let useCase = makeUseCase(ejector: ejector)

        try await useCase.execute(makeInput(baseTemp: makeTemp()), onProgress: { _ in })

        #expect(ejector.ejectCallCount == 1)
    }

    @Test func successAddsOneJobToQueue() async throws {
        let queue = SpyQueueManager()
        let useCase = makeUseCase(queue: queue)

        try await useCase.execute(makeInput(baseTemp: makeTemp()), onProgress: { _ in })

        #expect(queue.addCalls.count == 1)
    }

    @Test func successPassesCorrectTitleAndPresetToQueue() async throws {
        let queue = SpyQueueManager()
        let useCase = makeUseCase(queue: queue)

        try await useCase.execute(makeInput(baseTemp: makeTemp()), onProgress: { _ in })

        #expect(queue.addCalls[0].title == "The Matrix")
        #expect(queue.addCalls[0].preset == "H.265 MKV 1080p30")
        #expect(queue.addCalls[0].output == URL(fileURLWithPath: "/output/Movie.mkv"))
    }

    @Test func successPassesEpisodeLabelToQueue() async throws {
        let queue = SpyQueueManager()
        let useCase = makeUseCase(queue: queue)

        try await useCase.execute(
            makeInput(baseTemp: makeTemp(), episode: "S01E01"),
            onProgress: { _ in }
        )

        #expect(queue.addCalls[0].episode == "S01E01")
    }

    @Test func successPassesCorrectTitleNumberToRunner() async throws {
        let runner = SpyMakeMKVRunner()
        let useCase = makeUseCase(runner: runner)

        try await useCase.execute(makeInput(baseTemp: makeTemp(), titleNumber: 7), onProgress: { _ in })

        #expect(runner.lastTitleNumber == 7)
    }

    @Test func successCallsRunnerOnce() async throws {
        let runner = SpyMakeMKVRunner()
        let useCase = makeUseCase(runner: runner)

        try await useCase.execute(makeInput(baseTemp: makeTemp()), onProgress: { _ in })

        #expect(runner.ripCallCount == 1)
    }

    // MARK: - Failure path

    @Test func ripErrorResetsStatusToIdle() async throws {
        let runner = SpyMakeMKVRunner()
        runner.ripError = FrostscribeError.makemkvFailed(exitCode: 1)
        let status = SpyStatusManager()
        let useCase = makeUseCase(runner: runner, status: status)

        try? await useCase.execute(makeInput(baseTemp: makeTemp()), onProgress: { _ in })

        #expect(status.writeCalls.count == 2)
        #expect(status.writeCalls[0].status == .ripping)
        #expect(status.writeCalls[1].status == .idle)
    }

    @Test func ripErrorSkipsQueueAdd() async throws {
        let runner = SpyMakeMKVRunner()
        runner.ripError = FrostscribeError.makemkvFailed(exitCode: 1)
        let queue = SpyQueueManager()
        let useCase = makeUseCase(runner: runner, queue: queue)

        try? await useCase.execute(makeInput(baseTemp: makeTemp()), onProgress: { _ in })

        #expect(queue.addCalls.isEmpty)
    }

    @Test func ripErrorSkipsEjector() async throws {
        let runner = SpyMakeMKVRunner()
        runner.ripError = FrostscribeError.makemkvFailed(exitCode: 1)
        let ejector = SpyDiscEjector()
        let useCase = makeUseCase(runner: runner, ejector: ejector)

        try? await useCase.execute(makeInput(baseTemp: makeTemp()), onProgress: { _ in })

        #expect(ejector.ejectCallCount == 0)
    }

    @Test func ripErrorPropagates() async throws {
        let runner = SpyMakeMKVRunner()
        runner.ripError = FrostscribeError.makemkvFailed(exitCode: 99)
        let useCase = makeUseCase(runner: runner)

        do {
            try await useCase.execute(makeInput(baseTemp: makeTemp()), onProgress: { _ in })
            #expect(Bool(false), "Expected error to propagate")
        } catch FrostscribeError.makemkvFailed(let code) {
            #expect(code == 99)
        }
    }
}
