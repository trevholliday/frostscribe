import Foundation

// @unchecked Sendable is intentional: NSLock below serializes all file operations,
// preventing TOCTOU races between the CLI and the worker daemon.
public final class QueueManager: QueueManaging, @unchecked Sendable {
    private struct QueueFile: Codable {
        var jobs: [EncodeJob]
    }

    private let lock = NSLock()
    private let fileURL: URL

    public init(appSupportURL: URL) {
        self.fileURL = appSupportURL.appending(path: "queue.json")
    }

    public func read() throws -> [EncodeJob] {
        try lock.withLock {
            try _read()
        }
    }

    public func activeJobs() throws -> [EncodeJob] {
        try read().filter(\.isActive)
    }

    public func add(
        input: URL,
        output: URL,
        preset: String,
        title: String,
        episode: String? = nil,
        audioTracks: [Int]? = nil
    ) throws {
        try lock.withLock {
            var jobs = (try? _read()) ?? []
            let job = EncodeJob(
                title: title,
                episode: episode,
                input: input.path,
                output: output.path,
                preset: preset,
                audioTracks: audioTracks
            )
            jobs.append(job)
            try _write(jobs)
        }
    }

    public func updateProgress(id: UUID, progress: String) throws {
        try lock.withLock {
            var jobs = try _read()
            guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
            jobs[index].progress = progress
            try _write(jobs)
        }
    }

    public func updateStatus(
        id: UUID,
        status: EncodeJob.Status,
        progress: String? = nil,
        completedAt: Date? = nil
    ) throws {
        try lock.withLock {
            var jobs = try _read()
            guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
            jobs[index].status = status
            if let progress { jobs[index].progress = progress }
            if let completedAt { jobs[index].completedAt = completedAt }
            try _write(jobs)
        }
    }

    private func _read() throws -> [EncodeJob] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.frostscribe.decode(QueueFile.self, from: data).jobs
    }

    private func _write(_ jobs: [EncodeJob]) throws {
        let file = QueueFile(jobs: jobs)
        let data = try JSONEncoder.frostscribe.encode(file)
        try data.writeAtomically(to: fileURL)
    }
}
