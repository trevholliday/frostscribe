import Foundation

public protocol QueueManaging: Sendable {
    func read() throws -> [EncodeJob]
    func activeJobs() throws -> [EncodeJob]
    func add(input: URL, output: URL, preset: String, discType: String, title: String, episode: String?, audioTracks: [Int]?) throws
    func updateProgress(id: String, progress: String) throws
    func updateStatus(id: String, status: EncodeJob.Status, progress: String?, completedAt: Date?) throws
}

public extension QueueManaging {
    func add(input: URL, output: URL, preset: String, discType: String, title: String, episode: String? = nil) throws {
        try add(input: input, output: output, preset: preset, discType: discType, title: title, episode: episode, audioTracks: nil)
    }

    func add(input: URL, output: URL, preset: String, title: String, episode: String? = nil) throws {
        try add(input: input, output: output, preset: preset, discType: DiscType.bluray.rawValue, title: title, episode: episode, audioTracks: nil)
    }

    func updateStatus(id: String, status: EncodeJob.Status) throws {
        try updateStatus(id: id, status: status, progress: nil, completedAt: nil)
    }

    func updateStatus(id: String, status: EncodeJob.Status, completedAt: Date?) throws {
        try updateStatus(id: id, status: status, progress: nil, completedAt: completedAt)
    }
}
