import Foundation

/// Unified error type for all Frostscribe operations.
public enum FrostscribeError: Error, LocalizedError {
    case makemkvFailed(exitCode: Int32)
    case handbrakeFailed(exitCode: Int32)
    case noMKVFound(directory: URL)
    case configNotFound
    case configInvalid(reason: String)
    case tmdbUnavailable

    public var errorDescription: String? {
        switch self {
        case .makemkvFailed(let code):
            return "makemkvcon failed with exit code \(code)"
        case .handbrakeFailed(let code):
            return "HandBrakeCLI failed with exit code \(code)"
        case .noMKVFound(let dir):
            return "No MKV file found in \(dir.path) after ripping"
        case .configNotFound:
            return "Config file not found — run 'frostscribe init' to set up"
        case .configInvalid(let reason):
            return "Invalid config: \(reason)"
        case .tmdbUnavailable:
            return "TMDB is unavailable — check your API key"
        }
    }
}
