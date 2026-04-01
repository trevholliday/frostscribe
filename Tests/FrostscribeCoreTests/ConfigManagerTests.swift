import Testing
@testable import FrostscribeCore
import Foundation

// ConfigManager is hardwired to the real app support directory, so we test
// Config encoding/decoding and the save/load round-trip by using a helper
// that writes to a temp URL directly.

@Suite("Config Codable")
struct ConfigCodableTests {

    // MARK: - Defaults

    @Test func defaultsAreReasonable() {
        let config = Config()
        #expect(config.moviesDir == "")
        #expect(config.tvDir == "")
        #expect(config.tempDir == "")
        #expect(config.vigilMode == true)
        #expect(config.filterMovieTitles == true)
        #expect(config.qualityDVD == .rf20)
        #expect(config.qualityBluray == .rf18)
        #expect(config.qualityUHD == .rf18)
        #expect(config.selectAudioTracks == false)
        #expect(config.encoderTypeDVD == .software)
        #expect(config.encoderTypeBluray == .hardware)
        #expect(config.encoderTypeUHD == .hardware)
    }

    // MARK: - Round-trip

    @Test func saveAndLoadRoundTripsAllFields() throws {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "config-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var config = Config()
        config.moviesDir = "/movies"
        config.tvDir = "/tv"
        config.tempDir = "/tmp/rip"
        config.tmdbApiKey = "key123"
        config.makemkvKey = "mk456"
        config.makemkvBin = "/usr/local/bin/makemkvcon"
        config.handbrakeBin = "/usr/local/bin/HandBrakeCLI"
        config.eventHook = "notify.sh"
        config.vigilMode = false
        config.selectAudioTracks = true
        config.encoderTypeDVD = .hardware
        config.encoderTypeBluray = .software
        config.encoderTypeUHD = .software
        config.qualityDVD = .rf22
        config.qualityBluray = .rf24
        config.qualityUHD = .rf26
        config.filterMovieTitles = false

        let fileURL = dir.appending(path: "config.json")
        let data = try JSONEncoder.frostscribe.encode(config)
        try data.writeAtomically(to: fileURL)

        let loaded = try JSONDecoder.frostscribe.decode(Config.self, from: Data(contentsOf: fileURL))
        #expect(loaded.moviesDir == "/movies")
        #expect(loaded.tvDir == "/tv")
        #expect(loaded.tempDir == "/tmp/rip")
        #expect(loaded.tmdbApiKey == "key123")
        #expect(loaded.makemkvKey == "mk456")
        #expect(loaded.makemkvBin == "/usr/local/bin/makemkvcon")
        #expect(loaded.handbrakeBin == "/usr/local/bin/HandBrakeCLI")
        #expect(loaded.eventHook == "notify.sh")
        #expect(loaded.vigilMode == false)
        #expect(loaded.selectAudioTracks == true)
        #expect(loaded.encoderTypeDVD == .hardware)
        #expect(loaded.encoderTypeBluray == .software)
        #expect(loaded.encoderTypeUHD == .software)
        #expect(loaded.qualityDVD == .rf22)
        #expect(loaded.qualityBluray == .rf24)
        #expect(loaded.qualityUHD == .rf26)
        #expect(loaded.filterMovieTitles == false)
    }

    @Test func filterMovieTitlesPersistsTrue() throws {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "config-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var config = Config()
        config.filterMovieTitles = true

        let fileURL = dir.appending(path: "config.json")
        let data = try JSONEncoder.frostscribe.encode(config)
        try data.writeAtomically(to: fileURL)

        let loaded = try JSONDecoder.frostscribe.decode(Config.self, from: Data(contentsOf: fileURL))
        #expect(loaded.filterMovieTitles == true)
    }

    @Test func filterMovieTitlesPersistsFalse() throws {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "config-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var config = Config()
        config.filterMovieTitles = false

        let fileURL = dir.appending(path: "config.json")
        let data = try JSONEncoder.frostscribe.encode(config)
        try data.writeAtomically(to: fileURL)

        let loaded = try JSONDecoder.frostscribe.decode(Config.self, from: Data(contentsOf: fileURL))
        #expect(loaded.filterMovieTitles == false)
    }

    @Test func qualityDVDPersists() throws {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "config-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var config = Config()
        config.qualityDVD = .rf24

        let fileURL = dir.appending(path: "config.json")
        let data = try JSONEncoder.frostscribe.encode(config)
        try data.writeAtomically(to: fileURL)

        let loaded = try JSONDecoder.frostscribe.decode(Config.self, from: Data(contentsOf: fileURL))
        #expect(loaded.qualityDVD == .rf24)
    }

    @Test func qualityBlurayPersists() throws {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "config-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var config = Config()
        config.qualityBluray = .rf18

        let fileURL = dir.appending(path: "config.json")
        let data = try JSONEncoder.frostscribe.encode(config)
        try data.writeAtomically(to: fileURL)

        let loaded = try JSONDecoder.frostscribe.decode(Config.self, from: Data(contentsOf: fileURL))
        #expect(loaded.qualityBluray == .rf18)
    }

    @Test func qualityUHDPersists() throws {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "config-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var config = Config()
        config.qualityUHD = .rf22

        let fileURL = dir.appending(path: "config.json")
        let data = try JSONEncoder.frostscribe.encode(config)
        try data.writeAtomically(to: fileURL)

        let loaded = try JSONDecoder.frostscribe.decode(Config.self, from: Data(contentsOf: fileURL))
        #expect(loaded.qualityUHD == .rf22)
    }

    @Test func encoderTypePersists() throws {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "config-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var config = Config()
        config.encoderTypeDVD = .hardware
        config.encoderTypeBluray = .software
        config.encoderTypeUHD = .software

        let fileURL = dir.appending(path: "config.json")
        let data = try JSONEncoder.frostscribe.encode(config)
        try data.writeAtomically(to: fileURL)

        let loaded = try JSONDecoder.frostscribe.decode(Config.self, from: Data(contentsOf: fileURL))
        #expect(loaded.encoderTypeDVD == .hardware)
        #expect(loaded.encoderTypeBluray == .software)
        #expect(loaded.encoderTypeUHD == .software)
    }

    @Test func unknownKeysAreIgnoredGracefully() throws {
        // Write JSON with an extra unknown key — decoder should still produce valid Config
        let json = """
        {
            "moviesDir": "/movies",
            "tvDir": "/tv",
            "tempDir": "/tmp",
            "unknownFutureKey": "someValue",
            "vigilMode": false
        }
        """
        let data = json.data(using: .utf8)!
        let loaded = try JSONDecoder.frostscribe.decode(Config.self, from: data)
        #expect(loaded.moviesDir == "/movies")
        #expect(loaded.vigilMode == false)
        // Unknown key doesn't cause a throw and defaults are applied
        #expect(loaded.qualityDVD == .rf20)
    }

    @Test func missingKeysUseDefaults() throws {
        // Minimal JSON — all missing keys should fall back to defaults
        let json = """
        {
            "moviesDir": "/mymovies"
        }
        """
        let data = json.data(using: .utf8)!
        let loaded = try JSONDecoder.frostscribe.decode(Config.self, from: data)
        #expect(loaded.moviesDir == "/mymovies")
        #expect(loaded.tvDir == "")
        #expect(loaded.vigilMode == true)
        #expect(loaded.filterMovieTitles == true)
        #expect(loaded.qualityDVD == .rf20)
        #expect(loaded.qualityBluray == .rf18)
    }
}
