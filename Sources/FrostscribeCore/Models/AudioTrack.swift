public struct AudioTrack: Sendable {
    public var language: String
    public var codec: String

    public var isLossless: Bool {
        let lossless = ["DTS-HD MA", "TrueHD", "FLAC", "PCM", "LPCM"]
        return lossless.contains(where: { codec.contains($0) })
    }

    public init(language: String, codec: String) {
        self.language = language
        self.codec = codec
    }
}
