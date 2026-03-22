import Foundation

extension JSONEncoder {
    static let frostscribe: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let frostscribe: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension Data {
    func writeAtomically(to url: URL) throws {
        let tmp = url.deletingLastPathComponent().appending(path: "\(url.lastPathComponent).tmp")
        try write(to: tmp, options: .atomic)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }
}

extension MediaServer {
    // Emby uses the same folder structure as Jellyfin.
    static var emby: MediaServer { .jellyfin }
}
