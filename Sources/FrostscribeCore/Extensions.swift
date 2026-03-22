import Foundation

extension JSONEncoder {
    /// Standard encoder used across Frostscribe — ISO8601 dates, pretty printed.
    static let frostscribe: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    /// Standard decoder used across Frostscribe — ISO8601 dates.
    static let frostscribe: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension Data {
    /// Writes data atomically by writing to a temp file then renaming.
    func writeAtomically(to url: URL) throws {
        let tmp = url.deletingLastPathComponent().appending(path: "\(url.lastPathComponent).tmp")
        try write(to: tmp, options: .atomic)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }
}

extension MediaServer {
    // Placeholder for Emby support (same format as Jellyfin)
    static var emby: MediaServer { .jellyfin }
}
