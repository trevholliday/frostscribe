import Foundation

public protocol QueueManaging: Sendable {
    func read() throws -> [EncodeJob]
    func activeJobs() throws -> [EncodeJob]
    func add(input: URL, output: URL, preset: String, title: String, episode: String?) throws
    func updateProgress(id: UUID, progress: String) throws
    func updateStatus(id: UUID, status: EncodeJob.Status, progress: String?, completedAt: Date?) throws
}

public extension QueueManaging {
    func updateStatus(id: UUID, status: EncodeJob.Status) throws {
        try updateStatus(id: id, status: status, progress: nil, completedAt: nil)
    }

    func updateStatus(id: UUID, status: EncodeJob.Status, completedAt: Date?) throws {
        try updateStatus(id: id, status: status, progress: nil, completedAt: completedAt)
    }
}
