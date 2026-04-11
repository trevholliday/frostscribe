public enum EncodeQuality: Int, Codable, Sendable, CaseIterable {
    case rf18 = 18
    case rf20 = 20
    case rf22 = 22
    case rf24 = 24
    case rf26 = 26

    public var displayName: String {
        switch self {
        case .rf18: return "RF 18 — Maximum"
        case .rf20: return "RF 20 — High"
        case .rf22: return "RF 22 — Balanced"
        case .rf24: return "RF 24 — Efficient"
        case .rf26: return "RF 26 — Very Efficient"
        }
    }

    /// Equivalent quality on the vt_h265 0–100 scale (higher = better).
    public var hardwareQuality: Int {
        switch self {
        case .rf18: return 80
        case .rf20: return 82
        case .rf22: return 75
        case .rf24: return 67
        case .rf26: return 60
        }
    }

    public func value(for encoderType: EncoderType) -> Int {
        switch encoderType {
        case .software: return rawValue
        case .hardware: return hardwareQuality
        }
    }
}
