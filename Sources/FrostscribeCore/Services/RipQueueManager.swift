import Foundation

// @unchecked Sendable is intentional: NSLock serializes all file operations,
// preventing TOCTOU races between the UI process and the worker daemon.
public final class RipQueueManager: RipQueueManaging, @unchecked Sendable {
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

    /// Mark a job as cancelled so the worker terminates it.
    public func markCancelled(id: String) throws {
        try lock.withLock {
            var jobs = try _read()
            guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
            jobs[index].status = .cancelled
            try _write(jobs)
        }
    }

    /// Remove all jobs in a terminal state (done / error / cancelled), keeping pending and ripping.
    public func removeTerminal() throws {
        try lock.withLock {
            let jobs = try _read()
            try _write(jobs.filter { $0.status == .pending || $0.status == .ripping })
        }
    }

    /// Reset any job stuck in `.ripping` back to `.pending` so the worker retries it.
    public func resetStuck() throws -> Int {
        try lock.withLock {
            var jobs = try _read()
            var count = 0
            for i in jobs.indices where jobs[i].status == .ripping {
                jobs[i].status = .pending
                count += 1
            }
            try _write(jobs)
            return count
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
