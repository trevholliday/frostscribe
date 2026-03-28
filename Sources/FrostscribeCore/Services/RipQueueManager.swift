import Foundation

// @unchecked Sendable is intentional: NSLock serializes all file operations,
// preventing TOCTOU races between the UI process and the worker daemon.
public final class RipQueueManager: @unchecked Sendable {
    private struct QueueFile: Codable {
        var jobs: [RipQueueJob]
    }

    private let lock = NSLock()
    private let fileURL: URL

    public init(appSupportURL: URL) {
        self.fileURL = appSupportURL.appending(path: "rip_queue.json")
    }

    public func read() throws -> [RipQueueJob] {
        try lock.withLock { try _read() }
    }

    public func add(_ job: RipQueueJob) throws {
        try lock.withLock {
            var jobs = (try? _read()) ?? []
            jobs.append(job)
            try _write(jobs)
        }
    }

    public func updateStatus(
        id: String,
        status: RipQueueJob.Status,
        errorMessage: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) throws {
        try lock.withLock {
            var jobs = try _read()
            guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
            jobs[index].status = status
            if let errorMessage { jobs[index].errorMessage = errorMessage }
            if let startedAt    { jobs[index].startedAt    = startedAt   }
            if let completedAt  { jobs[index].completedAt  = completedAt }
            try _write(jobs)
        }
    }

    private func _read() throws -> [RipQueueJob] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.frostscribe.decode(QueueFile.self, from: data).jobs
    }

    private func _write(_ jobs: [RipQueueJob]) throws {
        let data = try JSONEncoder.frostscribe.encode(QueueFile(jobs: jobs))
        try data.writeAtomically(to: fileURL)
    }
}
