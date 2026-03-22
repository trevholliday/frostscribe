public struct DiscTitle: Sendable {
    public var number: Int
    public var name: String
    public var duration: String
    public var chapters: String
    public var sizeBytes: Int
    public var angle: Int?
    public var audioTracks: [AudioTrack]

    public var sizeFormatted: String {
        let gb = Double(sizeBytes) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }

    public init(
        number: Int,
        name: String,
        duration: String,
        chapters: String,
        sizeBytes: Int,
        angle: Int? = nil,
        audioTracks: [AudioTrack] = []
    ) {
        self.number = number
        self.name = name
        self.duration = duration
        self.chapters = chapters
        self.sizeBytes = sizeBytes
        self.angle = angle
        self.audioTracks = audioTracks
    }
}
