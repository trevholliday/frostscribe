public enum EncoderPreset {
    public static let bluray = "H.265 MKV 2160p60 4K"
    public static let dvd    = "H.265 MKV 1080p30"

    public static func preset(for discType: DiscType) -> String {
        switch discType {
        case .uhd, .bluray: return bluray
        case .dvd, .unknown: return dvd
        }
    }

    public static func quality(for discType: DiscType, config: Config) -> Int {
        let encodeQuality: EncodeQuality
        switch discType {
        case .uhd:            encodeQuality = config.qualityUHD
        case .bluray:         encodeQuality = config.qualityBluray
        case .dvd, .unknown:  encodeQuality = config.qualityDVD
        }
        return encodeQuality.value(for: config.encoderType(for: discType))
    }

    public static func arguments(input: String, output: String, preset: String, audioTracks: [Int]?, quality: Int, encoderType: EncoderType = .software) -> [String] {
        let audio = audioArgs(tracks: audioTracks)
        let isDVD = preset == dvd
        var args: [String] = [
            "-i", input,
            "-o", output,
            "--preset", preset,
            "--encoder", encoderType.handbrakeEncoder,
            "--quality", String(quality),
            "--encoder-level", "auto",
            "--subtitle", "1,2,3,4,5,6,7,8",
        ]
        if encoderType == .software {
            args += ["--encoder-preset", "fast"]
        } else {
            args += ["--encoder-preset", "quality"]
        }
        if isDVD {
            args += ["--comb-detect", "--decomb", "--color-matrix", "601"]
        }
        return args + audio
    }

    // Generates --audio / --aencoder / --ab / --aname arguments.
    // nil → default dual-track (AAC stereo + AC3 passthrough from track 1).
    // [N, M, ...] → one AAC stream per selected track.
    private static func audioArgs(tracks: [Int]?) -> [String] {
        guard let tracks, !tracks.isEmpty else {
            return ["--audio", "1,1", "--aencoder", "ca_aac,copy:ac3", "--ab", "320,auto", "--aname", "AAC Stereo,Surround"]
        }
        let audioList = tracks.map(String.init).joined(separator: ",")
        let encoders  = Array(repeating: "ca_aac", count: tracks.count).joined(separator: ",")
        let bitrates  = Array(repeating: "320", count: tracks.count).joined(separator: ",")
        let names     = tracks.enumerated().map { _, t in "Track \(t)" }.joined(separator: ",")
        return ["--audio", audioList, "--aencoder", encoders, "--ab", bitrates, "--aname", names]
    }
}
