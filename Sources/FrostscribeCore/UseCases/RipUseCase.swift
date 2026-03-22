import Foundation

public struct RipInput: Sendable {
    public let titleNumber: Int
    public let baseTemp: URL
    public let outputURL: URL
    public let preset: String
    public let jobLabel: String
    public let mediaType: RipJob.MediaType
    public let title: String
    public let episode: String?
    public let selectedAudioTracks: [Int]?

    public init(
        titleNumber: Int,
        baseTemp: URL,
        outputURL: URL,
        preset: String,
        jobLabel: String,
        mediaType: RipJob.MediaType,
        title: String,
        episode: String?,
        selectedAudioTracks: [Int]? = nil
    ) {
        self.titleNumber = titleNumber
        self.baseTemp = baseTemp
        self.outputURL = outputURL
        self.preset = preset
        self.jobLabel = jobLabel
        self.mediaType = mediaType
        self.title = title
        self.episode = episode
        self.selectedAudioTracks = selectedAudioTracks
    }
}

public final class RipUseCase: Sendable {
    private let runner: any MakeMKVRunning
    private let queue: any QueueManaging
    private let status: any StatusManaging
    private let ejector: any DiscEjecting

    public init(
        runner: any MakeMKVRunning,
        queue: any QueueManaging,
        status: any StatusManaging,
        ejector: any DiscEjecting
    ) {
        self.runner = runner
        self.queue = queue
        self.status = status
        self.ejector = ejector
    }

    public func execute(
        _ input: RipInput,
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws {
        let ripJob = RipJob(type: input.mediaType, title: input.jobLabel)
        try status.write(status: .ripping, job: ripJob)
        defer { try? status.write(status: .idle, job: nil) }

        let tempDir = input.baseTemp.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        try await runner.rip(
            titleNumber: input.titleNumber,
            to: tempDir,
            onMessage: { _ in },
            onProgress: onProgress
        )

        let mkv = try findMKV(in: tempDir)
        ejector.eject()

        try queue.add(
            input: mkv,
            output: input.outputURL,
            preset: input.preset,
            title: input.title,
            episode: input.episode,
            audioTracks: input.selectedAudioTracks
        )
    }

    private func findMKV(in dir: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        guard let mkv = contents.first(where: { $0.pathExtension.lowercased() == "mkv" }) else {
            throw FrostscribeError.noMKVFound(directory: dir)
        }
        return mkv
    }
}
