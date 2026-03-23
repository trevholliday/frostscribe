public enum EncodeQuality: Int, Codable, Sendable, CaseIterable {
    case q60 = 60
    case q65 = 65
    case q70 = 70
    case q75 = 75
    case q80 = 80

    public var displayName: String {
        switch self {
        case .q60: return "60 — Efficient"
        case .q65: return "65 — Balanced"
        case .q70: return "70 — High"
        case .q75: return "75 — Very High"
        case .q80: return "80 — Maximum"
        }
    }
}
