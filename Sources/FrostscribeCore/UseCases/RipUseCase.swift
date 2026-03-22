import Foundation

public struct RipInput: Sendable {
    public let titleNumber: Int
    public let baseTemp: URL
    public let mediaType: RipJob.MediaType
    public let jobLabel: String

    public init(
        titleNumber: Int,
        baseTemp: URL,
        mediaType: RipJob.MediaType,
        jobLabel: String
    ) {
        self.titleNumber = titleNumber
        self.baseTemp = baseTemp
        self.mediaType = mediaType
        self.jobLabel = jobLabel
    }
}

public final class RipUseCase: Sendable {
    private let runner: any MakeMKVRunning
    private let status: any StatusManaging
    private let ejector: any DiscEjecting

    public init(
        runner: any MakeMKVRunning,
        status: any StatusManaging,
        ejector: any DiscEjecting
    ) {
        self.runner = runner
        self.status = status
        self.ejector = ejector
    }

    /// Rips the selected title to a temp directory, ejects the disc, and returns the raw MKV URL.
    public func execute(
        _ input: RipInput,
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws -> URL {
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

        // Write 100% before defer transitions to idle so history captures completion
        var completedJob = ripJob
        completedJob.progress = "100%"
        try? status.write(status: .ripping, job: completedJob)
        onProgress(100)

        let mkv = try findMKV(in: tempDir)
        ejector.eject()
        return mkv
    }

    private func findMKV(in dir: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        guard let mkv = contents.first(where: { $0.pathExtension.lowercased() == "mkv" }) else {
            throw FrostscribeError.noMKVFound(directory: dir)
        }
        return mkv
    }
}
