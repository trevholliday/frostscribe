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
        switch discType {
        case .uhd:            return config.qualityUHD.rawValue
        case .bluray:         return config.qualityBluray.rawValue
        case .dvd, .unknown:  return config.qualityDVD.rawValue
        }
    }

    public static func arguments(input: String, output: String, preset: String, audioTracks: [Int]?, quality: Int) -> [String] {
        let audio = audioArgs(tracks: audioTracks)
        let isDVD = preset == dvd
        var args: [String] = [
            "-i", input,
            "-o", output,
            "--preset", preset,
            "--encoder", "x265",
            "--encoder-preset", "medium",
            "--quality", String(quality),
            "--encoder-level", "auto",
            "--subtitle", "1,2,3,4,5,6,7,8",
        ]
        if isDVD {
            args += ["--width", "1920", "--height", "1080", "--comb-detect", "--decomb"]
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
