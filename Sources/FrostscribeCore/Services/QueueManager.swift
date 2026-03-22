import Foundation

public final class QueueManager: Sendable {
    private struct QueueFile: Codable {
        var jobs: [EncodeJob]
    }

    private let fileURL: URL

    public init(appSupportURL: URL) {
        self.fileURL = appSupportURL.appending(path: "queue.json")
    }

    public func read() throws -> [EncodeJob] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.frostscribe.decode(QueueFile.self, from: data).jobs
    }

    public func activeJobs() throws -> [EncodeJob] {
        try read().filter(\.isActive)
    }

    public func add(
        input: URL,
        output: URL,
        preset: String,
        title: String,
        episode: String? = nil
    ) throws {
        var jobs = (try? read()) ?? []
        let job = EncodeJob(
            title: title,
            episode: episode,
            input: input.path,
            output: output.path,
            preset: preset
        )
        jobs.append(job)
        try write(jobs)
    }

    public func updateProgress(id: UUID, progress: String) throws {
        var jobs = try read()
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].progress = progress
        try write(jobs)
    }

    public func updateStatus(
        id: UUID,
        status: EncodeJob.Status,
        progress: String? = nil,
        completedAt: Date? = nil
    ) throws {
        var jobs = try read()
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].status = status
        if let progress { jobs[index].progress = progress }
        if let completedAt { jobs[index].completedAt = completedAt }
        try write(jobs)
    }

    private func write(_ jobs: [EncodeJob]) throws {
        let file = QueueFile(jobs: jobs)
        let data = try JSONEncoder.frostscribe.encode(file)
        try data.writeAtomically(to: fileURL)
    }
}
