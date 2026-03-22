import Foundation

public final class StatusManager: Sendable {
    public enum RipperStatus: String, Codable, Sendable {
        case idle
        case ripping
        case encoding
        case error
    }

    public struct StatusFile: Codable, Sendable {
        public var status: RipperStatus
        public var updatedAt: Date
        public var currentJob: RipJob?
        public var history: [RipJob]
    }

    private let fileURL: URL

    public init(appSupportURL: URL) {
        self.fileURL = appSupportURL.appending(path: "status.json")
    }

    public func read() throws -> StatusFile {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return StatusFile(status: .idle, updatedAt: .now, currentJob: nil, history: [])
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.frostscribe.decode(StatusFile.self, from: data)
    }

    public func write(status: RipperStatus, job: RipJob? = nil) throws {
        let existing = (try? read()) ?? StatusFile(status: .idle, updatedAt: .now, currentJob: nil, history: [])
        var history = existing.history

        if status == .idle, let completed = existing.currentJob {
            history.insert(completed, at: 0)
            if history.count > 20 { history = Array(history.prefix(20)) }
        }

        let updated = StatusFile(status: status, updatedAt: .now, currentJob: job, history: history)
        let data = try JSONEncoder.frostscribe.encode(updated)
        try data.writeAtomically(to: fileURL)
    }
}
