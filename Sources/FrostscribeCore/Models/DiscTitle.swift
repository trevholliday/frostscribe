public struct DiscTitle: Sendable {
    public var number: Int
    public var name: String
    public var duration: String
    public var chapters: String
    public var sizeBytes: Int
    public var angle: Int?
    public var audioTracks: [AudioTrack]
    /// Video resolution reported by MakeMKV, e.g. "1920x1080", "3840x2160".
    public var videoResolution: String?
    /// Number of subtitle tracks.
    public var subtitleCount: Int
    /// MakeMKV order weight — 0 means this is a primary title candidate. Lower = more likely main feature.
    public var orderWeight: Int

    public var sizeFormatted: String {
        let gb = Double(sizeBytes) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }

    /// True when MakeMKV flags this as a primary title (orderWeight == 0).
    public var isMainTitleCandidate: Bool { orderWeight == 0 }

    /// True if the video stream appears to be 4K (width ≥ 3840).
    public var is4K: Bool {
        guard let res = videoResolution,
              let widthStr = res.split(separator: "x").first,
              let width = Int(widthStr) else { return false }
        return width >= 3840
    }

    public init(
        number: Int,
        name: String,
        duration: String,
        chapters: String,
        sizeBytes: Int,
        angle: Int? = nil,
        audioTracks: [AudioTrack] = [],
        videoResolution: String? = nil,
        subtitleCount: Int = 0,
        orderWeight: Int = 0
    ) {
        self.number = number
        self.name = name
        self.duration = duration
        self.chapters = chapters
        self.sizeBytes = sizeBytes
        self.angle = angle
        self.audioTracks = audioTracks
        self.videoResolution = videoResolution
        self.subtitleCount = subtitleCount
        self.orderWeight = orderWeight
    }
}
