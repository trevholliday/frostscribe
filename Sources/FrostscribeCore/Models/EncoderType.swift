public enum EncoderType: String, Codable, Sendable, CaseIterable {
    case software = "software"
    case hardware = "hardware"

    public var displayName: String {
        switch self {
        case .software: return "Software (x265)"
        case .hardware: return "Hardware (VideoToolbox)"
        }
    }

    public var handbrakeEncoder: String {
        switch self {
        case .software: return "x265"
        case .hardware: return "vt_h265"
        }
    }
}
