public enum EncoderPreset {
    public static let bluray = "H.265 MKV 2160p60 4K"
    public static let dvd    = "H.265 MKV 1080p30"

    public static func preset(for discType: DiscType) -> String {
        switch discType {
        case .uhd, .bluray: return bluray
        case .dvd, .unknown: return dvd
        }
    }

    public static func arguments(input: String, output: String, preset: String, audioTracks: [Int]? = nil) -> [String] {
        let audio = audioArgs(tracks: audioTracks)
        return [
            "-i", input,
            "-o", output,
            "--preset", preset,
            "--encoder", "vt_h265",
            "--quality", "80",
            "--encoder-level", "auto",
            "--subtitle", "none",
        ] + audio
    }

    // Generates --audio / --aencoder / --ab / --aname arguments.
    // nil → default dual-track (AAC stereo + AC3 passthrough from track 1).
    // [N, M, ...] → one AAC stream per selected track.
    private static func audioArgs(tracks: [Int]?) -> [String] {
        guard let tracks, !tracks.isEmpty else {
            return ["--audio", "1,1", "--aencoder", "ca_aac,copy:ac3", "--ab", "160,auto", "--aname", "AAC Stereo,Surround"]
        }
        let audioList  = tracks.map(String.init).joined(separator: ",")
        let encoders   = Array(repeating: "ca_aac", count: tracks.count).joined(separator: ",")
        let bitrates   = Array(repeating: "160", count: tracks.count).joined(separator: ",")
        let names      = tracks.enumerated().map { i, t in "Track \(t)" }.joined(separator: ",")
        return ["--audio", audioList, "--aencoder", encoders, "--ab", bitrates, "--aname", names]
    }
}
