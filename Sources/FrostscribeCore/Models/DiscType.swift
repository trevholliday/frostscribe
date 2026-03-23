import Foundation

public enum DiscType: String, Codable, Sendable, CaseIterable {
    case dvd     = "dvd"
    case bluray  = "bluray"
    case uhd     = "uhd"
    case unknown = "unknown"

    /// Parse from the raw string MakeMKV emits in CINFO:1.
    public init(makeMKVString: String) {
        let lower = makeMKVString.lowercased()
        if lower.contains("ultra") || lower.contains("uhd") {
            self = .uhd
        } else if lower.contains("blu") {
            self = .bluray
        } else if lower.contains("dvd") {
            self = .dvd
        } else {
            self = .unknown
        }
    }

    public var displayName: String {
        switch self {
        case .dvd:     return "DVD"
        case .bluray:  return "Blu-ray"
        case .uhd:     return "UHD"
        case .unknown: return "Unknown"
        }
    }
}
