import ArgumentParser
import Foundation
import FrostscribeCore

struct RipCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rip",
        abstract: "Start an interactive disc ripping session."
    )

    @Flag(name: .shortAndLong, help: "Show detailed output.")
    var verbose = false

    func run() async throws {
        let config: Config
        do { config = try ConfigManager().load() }
        catch FrostscribeError.configNotFound {
            Colors.error("Not configured — run 'frostscribe init' first.")
            throw ExitCode.failure
        }

        if verbose {
            Colors.verbose("Config: \(ConfigManager.appSupportURL.path)/config.json")
            Colors.verbose("makemkvcon   → \(config.makemkvBin)")
            Colors.verbose("HandBrakeCLI → \(config.handbrakeBin)")
            Colors.verbose("Temp dir     → \(config.tempDir)")
            Colors.verbose("Movies dir   → \(config.moviesDir)")
            Colors.verbose("TV dir       → \(config.tvDir)")
            print()
        }

        Colors.banner()
        Colors.section("Rip")
        print()

        // Build concrete services
        let runner       = MakeMKVRunner(binPath: config.makemkvBin)
        let queueManager = QueueManager(appSupportURL: ConfigManager.appSupportURL)
        let statusManager = StatusManager(appSupportURL: ConfigManager.appSupportURL)
        let ejector      = DiscEjector()

        // Scan
        Colors.section("Disc Scan")
        let scanResult = try await scanDisc(runner: runner)

        guard !scanResult.titles.isEmpty else {
            Colors.error("No titles found. Is a disc inserted?")
            throw ExitCode.failure
        }

        if verbose {
            Colors.verbose("Disc type: \(scanResult.discType.displayName)")
            if let name = scanResult.discName { Colors.verbose("Disc name: \(name)") }
            Colors.verbose("Titles found: \(scanResult.titles.count)")
        }

        // Identify media before presenting titles
        Colors.section("Identify Media")
        let (title, year, isTV, _) = try await lookupMedia(discName: scanResult.discName, config: config)

        var episodeLabel: String? = nil
        var season = 1
        var episode = 1

        if isTV {
            print()
            season  = Int(Prompt.ask("Season number", default: "1")) ?? 1
            episode = Int(Prompt.ask("Starting episode number", default: "1")) ?? 1
            episodeLabel = String(format: "S%02dE%02d", season, episode)
        }

        Colors.section("Select Title")
        printTitles(scanResult.titles)
        let chosen = pickTitle(from: scanResult.titles)

        if verbose {
            print()
            Colors.verbose("Title #\(chosen.number): \(chosen.name)")
            Colors.verbose("  Duration: \(chosen.duration)  Size: \(chosen.sizeFormatted)  Chapters: \(chosen.chapters)")
            if let res = chosen.videoResolution { Colors.verbose("  Resolution: \(res)") }
            Colors.verbose("  Subtitles: \(chosen.subtitleCount)")
            for track in chosen.audioTracks {
                let lossless = track.isLossless ? " [lossless]" : ""
                Colors.verbose("  Audio: \(track.language) (\(track.codec))\(lossless)")
            }
        }

        let outputURL = buildOutputURL(
            title: title, year: year, season: season, episode: episode,
            isTV: isTV, config: config
        )

        print()
        Colors.info("Output  \(Colors.dim)\(outputURL.path)\(Colors.reset)")
        print()
        guard Prompt.confirm("Start ripping?") else {
            Colors.info("Cancelled.")
            return
        }

        // Audio track selection (optional)
        var selectedAudioTracks: [Int]? = nil
        if config.selectAudioTracks, chosen.audioTracks.count > 1 {
            print()
            Colors.section("Audio Tracks")
            for (i, track) in chosen.audioTracks.enumerated() {
                let label = "\(Colors.dim)[\(i + 1)]\(Colors.reset) \(track.language) (\(track.codec))"
                let losslessTag = track.isLossless ? " \(Colors.teal)✦ lossless\(Colors.reset)" : ""
                print("  \(label)\(losslessTag)")
            }
            print()
            let raw = Prompt.ask("Tracks to include (e.g. 1,3) or press Enter for all")
            if !raw.isEmpty {
                selectedAudioTracks = raw.split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    .filter { $0 >= 1 && $0 <= chosen.audioTracks.count }
            }
        }

        // Build use case inputs
        let jobLabel = [title, episodeLabel].compactMap { $0 }.joined(separator: " — ")
        let ripInput = RipInput(
            titleNumber: chosen.number,
            baseTemp: URL(fileURLWithPath: config.tempDir),
            mediaType: isTV ? .tvshow : .movie,
            jobLabel: jobLabel,
            discType: scanResult.discType,
            titleSizeBytes: chosen.sizeBytes
        )
        let encodeInput = EncodeInput(
            outputURL: outputURL,
            preset: EncoderPreset.preset(for: scanResult.discType),
            title: title,
            episode: episodeLabel,
            selectedAudioTracks: selectedAudioTracks,
            quality: EncoderPreset.quality(for: scanResult.discType, config: config)
        )

        if verbose {
            Colors.verbose("Preset:  \(encodeInput.preset)")
            Colors.verbose("Quality: \(encodeInput.quality)")
            if let tracks = encodeInput.selectedAudioTracks {
                Colors.verbose("Audio tracks: \(tracks.map(String.init).joined(separator: ", "))")
            } else {
                Colors.verbose("Audio tracks: all (default)")
            }
        }

        let ripUseCase = RipUseCase(runner: runner, status: statusManager, ejector: ejector)
        let encodeUseCase = EncodeUseCase(queue: queueManager)

        print()
        let ripState = RipProgressState()
        let spinnerTask = Task {
            var tick = 0
            while !Task.isCancelled {
                ProgressBar.printRip(percent: ripState.pct, message: ripState.msg, tick: tick)
                tick += 1
                try? await Task.sleep(nanoseconds: 45_000_000)
            }
        }
        let mkvURL = try await ripUseCase.execute(
            ripInput,
            onMessage: { msg in ripState.msg = msg },
            onProgress: { pct in ripState.pct = pct }
        )
        spinnerTask.cancel()
        if verbose { Colors.verbose("MKV: \(mkvURL.path)") }
        try encodeUseCase.execute(encodeInput, inputMKV: mkvURL)

        HookRunner(command: config.eventHook).fire(
            event: "rip_complete", title: "Rip Complete", body: jobLabel
        )

        print("\r  \(Colors.teal)✔\(Colors.reset) \(Colors.bold)Rip complete.\(Colors.reset)                                        ")

        print()
        Colors.success("\(jobLabel) added to encode queue.")
        Colors.info("Run \(Colors.bold)frostscribe queue\(Colors.reset) to check progress.")
        print()
    }

    // MARK: - Scan

    private func scanDisc(runner: any MakeMKVRunning) async throws -> DiscScanResult {
        print()
        let spinner = Task {
            var tick = 0
            while !Task.isCancelled {
                print("\r  \(Colors.frostCyan)\(ProgressBar.spin(tick))\(Colors.reset) Scanning disc...", terminator: "")
                fflush(stdout)
                try? await Task.sleep(nanoseconds: 100_000_000)
                tick += 1
            }
        }

        let result = try await runner.scan()
        spinner.cancel()
        print("\r  \(Colors.teal)✔\(Colors.reset) \(Colors.bold)Scan complete.\(Colors.reset)                              ")
        return result
    }

    // MARK: - Title selection

    private func printTitles(_ titles: [DiscTitle]) {
        let maxBytes = titles.map(\.sizeBytes).max() ?? 0
        let rule = "\(Colors.dim)\(String(repeating: "─", count: 80))\(Colors.reset)"

        print()
        let header = "# ".padding(toLength: 5, withPad: " ", startingAt: 0)
            + "Duration".padding(toLength: 12, withPad: " ", startingAt: 0)
            + " " + "Description".padding(toLength: 28, withPad: " ", startingAt: 0)
            + " " + "Audio".padding(toLength: 26, withPad: " ", startingAt: 0)
            + " Title"
        print("  \(Colors.bold)\(Colors.iceWhite)\(header)\(Colors.reset)")
        print("  \(rule)")

        for t in titles {
            let isMain = t.sizeBytes == maxBytes
            let numStr = "\(t.number)".padding(toLength: 5, withPad: " ", startingAt: 0)
            let dur    = t.duration.padding(toLength: 12, withPad: " ", startingAt: 0)
            let desc   = "\(t.chapters)ch, \(t.sizeFormatted)"
            let audioLines = formatAudioLines(t.audioTracks)
            let firstAudio = audioLines.first ?? "\(Colors.dim)—\(Colors.reset)"

            if isMain {
                let descStyled = "\(Colors.dim)\(t.chapters)ch, \(Colors.reset)\(Colors.teal)\(t.sizeFormatted)\(Colors.reset)"
                let descPad = String(repeating: " ", count: max(0, 28 - desc.count))
                print("  \(Colors.iceWhite)\(numStr)\(Colors.reset)\(Colors.iceWhite)\(dur)\(Colors.reset) \(descStyled)\(descPad) \(firstAudio) \(Colors.iceWhite)\(t.name)\(Colors.reset)")
            } else {
                let descPad = String(repeating: " ", count: max(0, 28 - desc.count))
                print("  \(Colors.dim)\(numStr)\(Colors.iceWhite)\(dur)\(Colors.reset) \(Colors.dim)\(desc)\(descPad)\(Colors.reset) \(firstAudio) \(Colors.dim)\(t.name)\(Colors.reset)")
            }

            for extraAudio in audioLines.dropFirst() {
                print("  \(String(repeating: " ", count: 47))\(extraAudio)")
            }
        }

        print("  \(rule)")
    }

    private func formatAudioLines(_ tracks: [AudioTrack]) -> [String] {
        guard !tracks.isEmpty else { return ["\(Colors.dim)—\(Colors.reset)"] }
        return tracks.map { track in
            let label = "\(track.language) (\(track.codec))"
            let padded = label.padding(toLength: 26, withPad: " ", startingAt: 0)
            return track.isLossless
                ? "\(Colors.teal)\(padded)\(Colors.reset)"
                : "\(Colors.dim)\(padded)\(Colors.reset)"
        }
    }

    private func pickTitle(from titles: [DiscTitle]) -> DiscTitle {
        print()
        while true {
            let input = Prompt.ask("Title number")
            if let n = Int(input), let title = titles.first(where: { $0.number == n }) {
                return title
            }
            Colors.error("Enter a title number from the list above.")
        }
    }

    // MARK: - TMDB / manual lookup

    private func lookupMedia(
        discName: String?,
        config: Config
    ) async throws -> (title: String, year: String, isTV: Bool, tmdbId: Int?) {
        let tmdb = TMDBClient(apiKey: config.tmdbApiKey)

        if tmdb.isConfigured, let discName = discName {
            let query = cleanForTMDB(discName.replacingOccurrences(of: "_", with: " ").capitalized)
            Colors.info("Searching TMDB: \(Colors.bold)\(query)\(Colors.reset)")

            let results = try await tmdb.searchMulti(query: query)

            if !results.isEmpty {
                print()
                for (i, r) in results.enumerated() {
                    let type = r.mediaType == .tv ? "TV" : "Movie"
                    print("  \(Colors.dim)[\(i + 1)]\(Colors.reset) \(r.title) \(Colors.dim)(\(r.year)) [\(type)]\(Colors.reset)")
                }
                print("  \(Colors.dim)[0] Enter manually\(Colors.reset)")
                print()

                while true {
                    let input = Prompt.ask("Pick [0-\(results.count)]")
                    guard let n = Int(input) else {
                        Colors.error("Enter a number between 0 and \(results.count).")
                        continue
                    }
                    if n == 0 { break }
                    if n >= 1, n <= results.count {
                        let r = results[n - 1]
                        return (r.title, r.year, r.mediaType == .tv, r.id)
                    }
                    Colors.error("Enter a number between 0 and \(results.count).")
                }
            } else {
                Colors.info("No results found.")
            }
        }

        return manualEntry()
    }

    private func manualEntry() -> (title: String, year: String, isTV: Bool, tmdbId: Int?) {
        let isTV = Prompt.pick("Media type", options: ["Movie", "TV Show"]) == "TV Show"
        let title = Prompt.ask("Title")
        let year  = Prompt.ask("Year", default: String(Calendar.current.component(.year, from: Date())))
        return (title, year, isTV, nil)
    }

    private func cleanForTMDB(_ name: String) -> String {
        let stopPattern = #"\b(bluray|blu-ray|dvd|disc|disk|remux|uhd|hdr|4k)\b"#
        var result = name.replacingOccurrences(of: stopPattern, with: "", options: [.regularExpression, .caseInsensitive])
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Output path



    private func buildOutputURL(
        title: String, year: String, season: Int, episode: Int,
        isTV: Bool, config: Config
    ) -> URL {
        if isTV {
            return PathBuilder.episodePath(
                show: title, year: year, season: season, episode: episode,
                baseDir: URL(fileURLWithPath: config.tvDir),
                mediaServer: config.mediaServer
            )
        } else {
            return PathBuilder.moviePath(
                title: title, year: year,
                baseDir: URL(fileURLWithPath: config.moviesDir),
                mediaServer: config.mediaServer
            )
        }
    }
}

// Shared mutable state between the 45ms spinner task and the rip callbacks.
// Slight data races on these two Ints are intentional and harmless — worst
// case the spinner renders a stale percent for one frame.
private final class RipProgressState: @unchecked Sendable {
    var pct: Int = 0
    var msg: String = "Starting…"
}
