import Foundation

public enum FrostscribeError: Error, LocalizedError {
    case makemkvFailed(exitCode: Int32)
    case makemkvCriticalError(code: Int, message: String)
    case handbrakeFailed(exitCode: Int32)
    case noMKVFound(directory: URL)
    case configNotFound
    case configInvalid(reason: String)
    case tmdbUnavailable

    public var errorDescription: String? {
        switch self {
        case .makemkvFailed(let code):
            return "makemkvcon failed with exit code \(code)"
        case .makemkvCriticalError(let code, let message):
            return "MakeMKV critical error \(code): \(message)"
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
