import Foundation

public final class ConfigManager: Sendable {

    public static let appSupportURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Frostscribe")
    }()

    private let fileURL: URL

    public init() {
        self.fileURL = Self.appSupportURL.appending(path: "config.json")
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    public func load() throws -> Config {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw FrostscribeError.configNotFound
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.frostscribe.decode(Config.self, from: data)
    }

    public func save(_ config: Config) throws {
        try FileManager.default.createDirectory(
            at: Self.appSupportURL,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.frostscribe.encode(config)
        try data.writeAtomically(to: fileURL)
    }

    // ConfigLoading conformance is declared in an extension below.

    public func createDirectories(for config: Config) throws {
        let fm = FileManager.default
        for path in [config.moviesDir, config.tvDir, config.tempDir] where !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            if !fm.fileExists(atPath: url.path) {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }
}

extension ConfigManager: ConfigLoading {}
