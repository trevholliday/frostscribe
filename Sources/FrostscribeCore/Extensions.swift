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
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // ISO 8601 with timezone + fractional seconds (frostscribe native)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: string) { return date }

            // ISO 8601 with timezone, no fractional seconds
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: string) { return date }

            // Python ripper naive datetimes: "2026-03-21T19:38:54.163428" (no timezone)
            let naive = DateFormatter()
            naive.locale = Locale(identifier: "en_US_POSIX")
            naive.timeZone = TimeZone(identifier: "UTC")
            for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {
                naive.dateFormat = fmt
                if let date = naive.date(from: string) { return date }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date from: \(string)"
            )
        }
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
