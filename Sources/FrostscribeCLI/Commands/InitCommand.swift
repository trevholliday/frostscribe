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

        Colors.banner()
        Colors.section("Setup")

        if manager.exists && !force {
            Colors.info("A config already exists at Application Support/Frostscribe/config.json")
            guard Prompt.confirm("Overwrite it?", default: false) else {
                Colors.info("Setup cancelled.")
                return
            }
        }

        // ── Media server ──────────────────────────────────────────────────────
        print()
        Colors.info("Which media server should output paths be formatted for?")
        let server = Prompt.pick("Media server", options: MediaServer.allCases, default: 0)

        // ── Output paths ──────────────────────────────────────────────────────
        print()
        Colors.info("Where should ripped and encoded files be stored?")
        let moviesDir = Prompt.ask("Movies directory", default: expandingTilde("~/Movies"))
        let tvDir     = Prompt.ask("TV Shows directory", default: expandingTilde("~/TV Shows"))
        let tempDir   = Prompt.ask(
            "Temp rip directory",
            default: ConfigManager.appSupportURL.appending(path: "temp").path
        )

        // ── API keys ──────────────────────────────────────────────────────────
        print()
        Colors.info("API keys (press Enter to skip and configure later).")
        let tmdbKey    = askOptional("TMDB API key")
        let makemkvKey = askOptional("MakeMKV beta key")

        // ── Tool detection & installation ─────────────────────────────────────
        print()
        Colors.section("Tools")
        print()
        Colors.info("Checking for required tools…")
        print()

        let makemkvBin = resolveMakeMKV()

        print()

        let handbrakeBin = resolveOrInstall(
            displayName: "HandBrakeCLI",
            binName: "HandBrakeCLI",
            brewFormula: "handbrake",
            postInstallPaths: [],
            manualURL: "https://handbrake.fr/downloads2.php"
        )

        // ── Options ───────────────────────────────────────────────────────────
        print()
        Colors.section("Options")
        print()

        let selectAudio   = Prompt.confirm(
            "Prompt to select audio tracks before each rip?",
            default: false
        )
        let vigil = Prompt.confirm(
            "Enable Vigil Mode? (auto-rip when a disc is inserted — macOS app only)",
            default: false
        )

        // ── Save ──────────────────────────────────────────────────────────────
        let config = Config(
            mediaServer:          server,
            moviesDir:            moviesDir,
            tvDir:                tvDir,
            tempDir:              tempDir,
            tmdbApiKey:           tmdbKey,
            makemkvKey:           makemkvKey,
            makemkvBin:           makemkvBin,
            handbrakeBin:         handbrakeBin,
            vigilMode:            vigil,
            selectAudioTracks:    selectAudio
        )

        print()
        do {
            try manager.save(config)
            try manager.createDirectories(for: config)
            Colors.success("Config saved to \(ConfigManager.appSupportURL.path)/config.json")
            print()
            Colors.info("Start the encode worker:  \(Colors.bold)frostscribe worker start\(Colors.reset)")
            Colors.info("Then rip your first disc:  \(Colors.bold)frostscribe rip\(Colors.reset)")
            print()
        } catch {
            Colors.error("Failed to save config: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    // MARK: - Tool detection & installation

    /// MakeMKV has no Homebrew formula — guide the user to download it directly.
    private func resolveMakeMKV() -> String {
        let knownPaths = [
            "/Applications/MakeMKV.app/Contents/MacOS/makemkvcon",
            "/opt/homebrew/bin/makemkvcon",
            "/usr/local/bin/makemkvcon",
        ]
        if let found = knownPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            Colors.success("MakeMKV \(Colors.dim)→ \(found)\(Colors.reset)")
            return found
        }
        Colors.info("MakeMKV not found.")
        Colors.info("Download and install it from: \(Colors.dim)https://www.makemkv.com\(Colors.reset)")
        Colors.info("Then open /Applications/MakeMKV.app once to activate your licence key.")
        print()
        return Prompt.ask("makemkvcon path", default: "/Applications/MakeMKV.app/Contents/MacOS/makemkvcon")
    }

    private func resolveOrInstall(
        displayName: String,
        binName: String,
        brewFormula: String,
        postInstallPaths: [String],
        manualURL: String
    ) -> String {
        let candidates = [
            "/opt/homebrew/bin/\(binName)",
            "/usr/local/bin/\(binName)",
        ] + postInstallPaths

        if let existing = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            Colors.success("\(displayName) \(Colors.dim)→ \(existing)\(Colors.reset)")
            return existing
        }

        Colors.info("\(displayName) not found.")

        if let brew = detectBrew() {
            guard Prompt.confirm("Install \(displayName) via Homebrew?", default: true) else {
                return Prompt.ask("\(displayName) path", default: binName)
            }

            print()
            Colors.info("Running: \(Colors.dim)brew install \(brewFormula)\(Colors.reset)")
            print()

            let ok = runBrew(brew: brew, formula: brewFormula)
            print()

            if ok {
                let postCandidates = postInstallPaths + [
                    "/opt/homebrew/bin/\(binName)",
                    "/usr/local/bin/\(binName)",
                ]
                if let installed = postCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                    Colors.success("\(displayName) installed \(Colors.dim)→ \(installed)\(Colors.reset)")
                    return installed
                }
                Colors.info("Installed, but path could not be detected — enter it below.")
            } else {
                Colors.error("Homebrew install failed. Enter the path manually or install from:")
                Colors.info("  \(Colors.dim)\(manualURL)\(Colors.reset)")
            }
        } else {
            Colors.error("Homebrew not found.")
            Colors.info("Install Homebrew first: \(Colors.dim)https://brew.sh\(Colors.reset)")
            Colors.info("Then run: \(Colors.dim)brew install \(brewFormula)\(Colors.reset)")
            Colors.info("Or download from: \(Colors.dim)\(manualURL)\(Colors.reset)")
            print()
        }

        return Prompt.ask("\(displayName) path", default: binName)
    }

    private func detectBrew() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.fileExists(atPath: $0) }
    }

    @discardableResult
    private func runBrew(brew: String, formula: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: brew)
        process.arguments = ["install", formula]
        do {
            try process.run()
        } catch {
            Colors.error("Failed to launch brew: \(error.localizedDescription)")
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    // MARK: - Helpers

    private func askOptional(_ label: String) -> String {
        print("  \(Colors.frostCyan)›\(Colors.reset) \(label) \(Colors.dim)(optional)\(Colors.reset): ", terminator: "")
        fflush(stdout)
        return (readLine(strippingNewline: true) ?? "").trimmingCharacters(in: .whitespaces)
    }

    private func expandingTilde(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}

extension MediaServer: CustomStringConvertible {
    public var description: String { rawValue }
}
