public struct AudioTrack: Sendable {
    public var language: String
    public var codec: String
    /// Channel layout, e.g. "7.1", "5.1", "2.0". Nil if MakeMKV did not report it.
    public var channels: String?

    public var isLossless: Bool {
        let lossless = ["DTS-HD MA", "TrueHD", "FLAC", "PCM", "LPCM"]
        return lossless.contains(where: { codec.contains($0) })
    }

    /// Human-readable summary, e.g. "English (DTS-HD MA 7.1)"
    public var summary: String {
        var codecPart = codec
        if let ch = channels { codecPart += " \(ch)" }
        if language.isEmpty || language == "Unknown" { return codecPart }
        return "\(language) (\(codecPart))"
    }

    public init(language: String, codec: String, channels: String? = nil) {
        self.language = language
        self.codec = codec
        self.channels = channels
    }
}
