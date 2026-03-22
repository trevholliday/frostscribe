import Foundation

/// Represents a single entry in the encode queue.
public struct EncodeJob: Codable, Identifiable, Sendable {
    public enum Status: String, Codable, Sendable {
        case pending
        case encoding
        case done
        case error
    }

    public var id: UUID
    public var title: String
    public var episode: String?
    public var input: String
    public var output: String
    public var preset: String
    public var status: Status
    public var progress: String
    public var addedAt: Date
    public var startedAt: Date?
    public var completedAt: Date?

    /// Returns a display label combining title and episode if present.
    public var label: String {
        if let episode { return "\(title) — \(episode)" }
        return title
    }

    public var isActive: Bool {
        status == .pending || status == .encoding
    }

    public init(
        id: UUID = UUID(),
        title: String,
        episode: String? = nil,
        input: String,
        output: String,
        preset: String,
        status: Status = .pending,
        progress: String = "—",
        addedAt: Date = .now,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.episode = episode
        self.input = input
        self.output = output
        self.preset = preset
        self.status = status
        self.progress = progress
        self.addedAt = addedAt
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}
