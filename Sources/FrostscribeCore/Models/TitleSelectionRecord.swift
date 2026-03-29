import Foundation

/// One row per title per disc scan event.
/// `isSelected` is true for exactly the title the user picked.
/// All rows with the same `selectionId` form one training example.
public struct TitleSelectionRecord: Identifiable, Sendable {
    public var id: UUID
    /// Groups all title rows from a single disc scan + selection event.
    public var selectionId: UUID
    public var timestamp: Date
    public var discType: String       // DiscType.rawValue
    public var mediaType: String      // RipJob.MediaType.rawValue
    public var discName: String?
    public var totalTitleCount: Int
    public var isSelected: Bool

    // ── Title features ──────────────────────────────────────────────────────
    public var titleNumber: Int
    public var durationMinutes: Int
    public var chapters: Int
    public var sizeBytes: Int
    public var angle: Int             // 0 when absent
    public var audioTrackCount: Int
    public var hasLosslessAudio: Bool
    public var videoWidth: Int        // 0 when unknown
    public var videoHeight: Int       // 0 when unknown
    public var subtitleCount: Int
    public var orderWeight: Int

    // ── Relative features (computed at record time) ──────────────────────────
    /// 1 = longest title on disc
    public var durationRank: Int
    /// 1 = largest title on disc
    public var sizeRank: Int

    public init(
        id: UUID = UUID(),
        selectionId: UUID,
        timestamp: Date = .now,
        discType: String,
        mediaType: String,
        discName: String?,
        totalTitleCount: Int,
        isSelected: Bool,
        titleNumber: Int,
        durationMinutes: Int,
        chapters: Int,
        sizeBytes: Int,
        angle: Int,
        audioTrackCount: Int,
        hasLosslessAudio: Bool,
        videoWidth: Int,
        videoHeight: Int,
        subtitleCount: Int,
        orderWeight: Int,
        durationRank: Int,
        sizeRank: Int
    ) {
        self.id = id
        self.selectionId = selectionId
        self.timestamp = timestamp
        self.discType = discType
        self.mediaType = mediaType
        self.discName = discName
        self.totalTitleCount = totalTitleCount
        self.isSelected = isSelected
        self.titleNumber = titleNumber
        self.durationMinutes = durationMinutes
        self.chapters = chapters
        self.sizeBytes = sizeBytes
        self.angle = angle
        self.audioTrackCount = audioTrackCount
        self.hasLosslessAudio = hasLosslessAudio
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.subtitleCount = subtitleCount
        self.orderWeight = orderWeight
        self.durationRank = durationRank
        self.sizeRank = sizeRank
    }
}
