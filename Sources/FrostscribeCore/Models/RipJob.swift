import Foundation

public struct RipJob: Codable, Sendable {
    public enum MediaType: String, Codable, Sendable {
        case movie
        case tvshow
    }

    public enum Phase: String, Codable, Sendable {
        case ripping
        case encoding
    }

    public var type: MediaType
    public var title: String
    public var startedAt: Date
    public var phase: Phase
    public var progress: String
    public var currentItem: String?

    public init(
        type: MediaType,
        title: String,
        startedAt: Date = .now,
        phase: Phase = .ripping,
        progress: String = "0%",
        currentItem: String? = nil
    ) {
        self.type = type
        self.title = title
        self.startedAt = startedAt
        self.phase = phase
        self.progress = progress
        self.currentItem = currentItem
    }
}
