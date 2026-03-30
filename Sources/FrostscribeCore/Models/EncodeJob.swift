import Foundation

public struct EncodeJob: Codable, Identifiable, Sendable {
    public enum Status: String, Codable, Sendable {
        case pending
        case encoding
        case done
        case error
    }

    public var id: String
    public var title: String
    public var episode: String?
    public var input: String
    public var output: String
    public var preset: String
    public var audioTracks: [Int]?
    public var status: Status
    public var progress: String
    public var addedAt: Date
    public var startedAt: Date?
    public var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, episode, input, output, preset, status, progress
        case audioTracks = "audio_tracks"
        case addedAt = "added_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        episode = try c.decodeIfPresent(String.self, forKey: .episode)
        input = try c.decode(String.self, forKey: .input)
        output = try c.decode(String.self, forKey: .output)
        preset = try c.decode(String.self, forKey: .preset)
        audioTracks = try c.decodeIfPresent([Int].self, forKey: .audioTracks)
        status = (try? c.decode(Status.self, forKey: .status)) ?? .pending
        progress = (try? c.decode(String.self, forKey: .progress)) ?? "—"
        addedAt = (try? c.decodeIfPresent(Date.self, forKey: .addedAt)) ?? .now
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    public var label: String {
        if let episode { return "\(title) — \(episode)" }
        return title
    }

    public var isActive: Bool {
        status == .pending || status == .encoding
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        episode: String? = nil,
        input: String,
        output: String,
        preset: String,
        audioTracks: [Int]? = nil,
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
        self.audioTracks = audioTracks
        self.status = status
        self.progress = progress
        self.addedAt = addedAt
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}
