/// Supported media server output formats.
public enum MediaServer: String, Codable, CaseIterable, Sendable {
    case jellyfin
    case plex
    case kodi
}
