import Foundation

public struct RipInput: Sendable {
    public let titleNumber: Int
    public let baseTemp: URL
    public let mediaType: RipJob.MediaType
    public let jobLabel: String
    public let discType: DiscType
    public let titleSizeBytes: Int
    public let tmdbId: Int?
    public let tmdbMediaType: String?

    public init(
        titleNumber: Int,
        baseTemp: URL,
        mediaType: RipJob.MediaType,
        jobLabel: String,
        discType: DiscType = .unknown,
        titleSizeBytes: Int = 0,
        tmdbId: Int? = nil,
        tmdbMediaType: String? = nil
    ) {
        self.titleNumber = titleNumber
        self.baseTemp = baseTemp
        self.mediaType = mediaType
        self.jobLabel = jobLabel
        self.discType = discType
        self.titleSizeBytes = titleSizeBytes
        self.tmdbId = tmdbId
        self.tmdbMediaType = tmdbMediaType
    }
}

public final class RipUseCase: Sendable {
    private let runner: any MakeMKVRunning
    private let status: any StatusManaging
    private let ejector: any DiscEjecting
    private let historyStore: RipHistoryStore?

    public init(
        runner: any MakeMKVRunning,
        status: any StatusManaging,
        ejector: any DiscEjecting,
        historyStore: RipHistoryStore? = nil
    ) {
        self.runner = runner
        self.status = status
        self.ejector = ejector
        self.historyStore = historyStore
    }

    /// Rips the selected title to a temp directory, ejects the disc, and returns the raw MKV URL.
    public func execute(
        _ input: RipInput,
        onMessage: @escaping @Sendable (String) -> Void = { _ in },
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws -> URL {
        let startDate = Date.now
        let ripJob = RipJob(type: input.mediaType, title: input.jobLabel)
        try status.write(status: .ripping, job: ripJob)
        defer { try? status.write(status: .idle, job: nil) }

        let safeName = input.jobLabel
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let tempDir = input.baseTemp.appending(path: safeName)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let progressJob = ProgressJobRef(base: ripJob)

        // Intercept messages to surface them in status.json for the UI
        let wrappedMessage: @Sendable (String) -> Void = { msg in
            progressJob.update(message: msg)
            try? self.status.write(status: .ripping, job: progressJob.job)
            onMessage(msg)
        }

        // Poll file size every 500ms for real-time progress — PRGV:current resets per segment.
        let expectedBytes = input.titleSizeBytes
        let sizePoller = Task {
            while !Task.isCancelled {
                if expectedBytes > 0, let written = dirBytes(tempDir) {
                    let pct = min(Int(Double(written) / Double(expectedBytes) * 100), 99)
                    progressJob.update(pct: pct)
                    try? self.status.write(status: .ripping, job: progressJob.job)
                    onProgress(pct)
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }

        try await runner.rip(
            titleNumber: input.titleNumber,
            to: tempDir,
            onMessage: wrappedMessage,
            onProgress: { _ in }   // progress now driven by file size above
        )
        sizePoller.cancel()

        // Write 100% before defer transitions to idle so history captures completion
        var completedJob = ripJob
        completedJob.progress = "100%"
        try? status.write(status: .ripping, job: completedJob)
        onProgress(100)

        let mkv = try findMKV(in: tempDir)
        ejector.eject()

        if input.titleSizeBytes > 0 {
            let record = RipRecord(
                discType: input.discType,
                titleSizeBytes: input.titleSizeBytes,
                ripDurationSeconds: Date.now.timeIntervalSince(startDate),
                jobLabel: input.jobLabel,
                success: true
            )
            try? historyStore?.append(record)
        }

        return mkv
    }

}

private final class ProgressJobRef: @unchecked Sendable {
    private(set) var job: RipJob
    init(base: RipJob) { self.job = base }
    func update(pct: Int) { job.progress = "\(pct)%" }
    func update(message: String) { job.currentItem = message }
}

extension RipUseCase {
    private func findMKV(in dir: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        guard let mkv = contents.first(where: { $0.pathExtension.lowercased() == "mkv" }) else {
            throw FrostscribeError.noMKVFound(directory: dir)
        }
        return mkv
    }

    private func dirBytes(_ dir: URL) -> Int? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return nil }
        return contents.compactMap {
            try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize
        }.reduce(0, +)
    }
}
