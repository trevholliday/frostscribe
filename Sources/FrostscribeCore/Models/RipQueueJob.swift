import Foundation

public struct RipQueueJob: Codable, Identifiable, Sendable {
    public enum Status: String, Codable, Sendable {
        case pending
        case ripping
        case done
        case error
        case cancelled
    }

    public var id: String
    // Rip parameters
    public var titleNumber: Int
    public var baseTempPath: String       // baseTemp dir; RipUseCase creates the jobLabel subdir
    public var mediaType: String          // RipJob.MediaType rawValue
    public var jobLabel: String
    public var discType: String           // DiscType rawValue
    public var titleSizeBytes: Int
    // Encode parameters (worker queues encode after rip completes)
    public var outputPath: String
    public var preset: String
    public var encodeTitle: String
    public var episode: String?
    public var audioTracks: [Int]?
    // TMDB reference (stored at queue time for reliable resume)
    public var tmdbId: Int?
    public var tmdbMediaType: String?
    // Status tracking
    public var status: Status
    public var errorMessage: String?
    public var addedAt: Date
    public var startedAt: Date?
    public var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case titleNumber   = "title_number"
        case baseTempPath  = "base_temp_path"
        case mediaType     = "media_type"
        case jobLabel      = "job_label"
        case discType      = "disc_type"
        case titleSizeBytes = "title_size_bytes"
        case outputPath    = "output_path"
        case preset
        case encodeTitle   = "encode_title"
        case episode
        case audioTracks   = "audio_tracks"
        case tmdbId        = "tmdb_id"
        case tmdbMediaType = "tmdb_media_type"
        case status
        case errorMessage  = "error_message"
        case addedAt       = "added_at"
        case startedAt     = "started_at"
        case completedAt   = "completed_at"
    }

    public init(
        id: String = UUID().uuidString,
        titleNumber: Int,
        baseTempPath: String,
        mediaType: String,
        jobLabel: String,
        discType: String,
        titleSizeBytes: Int,
        outputPath: String,
        preset: String,
        encodeTitle: String,
        episode: String? = nil,
        audioTracks: [Int]? = nil,
        tmdbId: Int? = nil,
        tmdbMediaType: String? = nil,
        status: Status = .pending,
        errorMessage: String? = nil,
        addedAt: Date = .now,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id            = id
        self.titleNumber   = titleNumber
        self.baseTempPath  = baseTempPath
        self.mediaType     = mediaType
        self.jobLabel      = jobLabel
        self.discType      = discType
        self.titleSizeBytes = titleSizeBytes
        self.outputPath    = outputPath
        self.preset        = preset
        self.encodeTitle   = encodeTitle
        self.episode       = episode
        self.audioTracks   = audioTracks
        self.tmdbId        = tmdbId
        self.tmdbMediaType = tmdbMediaType
        self.status        = status
        self.errorMessage  = errorMessage
        self.addedAt       = addedAt
        self.startedAt     = startedAt
        self.completedAt   = completedAt
    }

    public var isActive: Bool {
        status == .pending || status == .ripping
    }
}
