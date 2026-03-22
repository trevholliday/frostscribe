import ArgumentParser
import Foundation
import FrostscribeCore

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Run the first-time setup wizard."
    )

    @Flag(name: .long, help: "Overwrite existing config without prompting.")
    var force = false

    func run() throws {
        let manager = ConfigManager()

        Colors.section("Frostscribe Setup")

        if manager.exists && !force {
            Colors.info("A config already exists at Application Support/Frostscribe/config.json")
            guard Prompt.confirm("Overwrite it?", default: false) else {
                Colors.info("Setup cancelled.")
                return
            }
        }

        print()
        Colors.info("Which media server should output paths be formatted for?")
        let server = Prompt.pick("Media server", options: MediaServer.allCases, default: 0)

        print()
        Colors.info("Where should ripped and encoded files be stored?")
        let moviesDir = Prompt.ask("Movies directory", default: expandingTilde("~/Movies"))
        let tvDir     = Prompt.ask("TV Shows directory", default: expandingTilde("~/TV Shows"))
        let tempDir   = Prompt.ask(
            "Temp rip directory",
            default: ConfigManager.appSupportURL.appending(path: "temp").path
        )

        print()
        Colors.info("API keys (press Enter to skip and configure later).")
        let tmdbKey    = askOptional("TMDB API key")
        let makemkvKey = askOptional("MakeMKV beta key")

        print()
        Colors.info("Paths to required CLI tools.")
        let makemkvBin   = Prompt.ask("makemkvcon path", default: detectBin("makemkvcon"))
        let handbrakeBin = Prompt.ask("HandBrakeCLI path", default: detectBin("HandBrakeCLI"))

        print()
        let vigil = Prompt.confirm(
            "Enable Vigil Mode? (auto-rip when a disc is inserted)",
            default: false
        )

        let config = Config(
            mediaServer: server,
            moviesDir: moviesDir,
            tvDir: tvDir,
            tempDir: tempDir,
            tmdbApiKey: tmdbKey,
            makemkvKey: makemkvKey,
            makemkvBin: makemkvBin,
            handbrakeBin: handbrakeBin,
            notificationsEnabled: false,
            vigilMode: vigil
        )

        print()
        do {
            try manager.save(config)
            try manager.createDirectories(for: config)
            Colors.success("Config saved to \(ConfigManager.appSupportURL.path)/config.json")
            print()
            Colors.info("Run \(Colors.bold)frostscribe rip\(Colors.reset) to start ripping.")
        } catch {
            Colors.error("Failed to save config: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    private func askOptional(_ label: String) -> String {
        print("  \(Colors.cyan)›\(Colors.reset) \(label) \(Colors.dim)(optional)\(Colors.reset): ", terminator: "")
        fflush(stdout)
        return (readLine(strippingNewline: true) ?? "").trimmingCharacters(in: .whitespaces)
    }

    private func detectBin(_ name: String) -> String {
        let commonPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
        ]
        return commonPaths.first {
            FileManager.default.fileExists(atPath: $0)
        } ?? name
    }

    private func expandingTilde(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}

extension MediaServer: CustomStringConvertible {
    public var description: String { rawValue }
}
