public enum EncoderPreset {
    public static let bluray = "H.265 MKV 2160p60 4K"
    public static let dvd    = "H.265 MKV 1080p30"

    public static func preset(for discType: String?) -> String {
        guard let discType else { return dvd }
        return discType.lowercased().contains("blu") ? bluray : dvd
    }

    public static func arguments(input: String, output: String, preset: String) -> [String] {
        [
            "-i", input,
            "-o", output,
            "--preset", preset,
            "--encoder", "vt_h265",
            "--quality", "80",
            "--encoder-level", "auto",
            "--subtitle", "none",
            "--audio", "1,1",
            "--aencoder", "ca_aac,copy:ac3",
            "--ab", "160,auto",
            "--aname", "AAC Stereo,Surround",
        ]
    }
}
