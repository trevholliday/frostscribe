import ArgumentParser
import Foundation
import FrostscribeCore

struct RipCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rip",
        abstract: "Start an interactive disc ripping session."
    )

    func run() async throws {
        let config: Config
        do { config = try ConfigManager().load() }
        catch FrostscribeError.configNotFound {
            Colors.error("Not configured — run 'frostscribe init' first.")
            throw ExitCode.failure
        }

        Colors.section("Frostscribe Rip")
        print()

        let scanResult = try await scanDisc(config: config)

        guard !scanResult.titles.isEmpty else {
            Colors.error("No titles found. Is a disc inserted?")
            throw ExitCode.failure
        }

        printTitles(scanResult.titles)
        let chosen = pickTitle(from: scanResult.titles)

        print()
        let isTV = Prompt.pick("Media type", options: ["Movie", "TV Show"]) == "TV Show"

        print()
        let (title, year, _) = try await lookupMedia(discName: scanResult.discName, isTV: isTV, config: config)

        var episodeLabel: String? = nil
        var season = 1
        var episode = 1

        if isTV {
            print()
            season  = Int(Prompt.ask("Season number", default: "1")) ?? 1
            episode = Int(Prompt.ask("Starting episode number", default: "1")) ?? 1
            episodeLabel = String(format: "S%02dE%02d", season, episode)
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

        print()
        let jobLabel = [title, episodeLabel].compactMap { $0 }.joined(separator: " — ")
        let statusManager = StatusManager(appSupportURL: ConfigManager.appSupportURL)
        let ripJob = RipJob(type: isTV ? .tvshow : .movie, title: jobLabel)
        try statusManager.write(status: .ripping, job: ripJob)
        defer { try? statusManager.write(status: .idle) }

        let mkv = try await ripTitle(chosen, config: config)

        if !DiscEjector.eject() {
            Colors.info("Could not eject disc — please eject manually.")
        }

        let queueManager = QueueManager(appSupportURL: ConfigManager.appSupportURL)
        try queueManager.add(
            input: mkv,
            output: outputURL,
            preset: EncoderPreset.preset(for: scanResult.discType),
            title: title,
            episode: episodeLabel
        )

        print()
        Colors.success("\(jobLabel) added to encode queue.")
        Colors.info("Run \(Colors.bold)frostscribe queue\(Colors.reset) to check progress.")
        print()
    }

    // MARK: - Scan

    private func scanDisc(config: Config) async throws -> MakeMKVRunner.ScanResult {
        let runner = MakeMKVRunner(binPath: config.makemkvBin)

        let spinner = Task {
            var tick = 0
            while !Task.isCancelled {
                print("\r  \(Colors.frostCyan)\(ProgressBar.spin(tick))\(Colors.reset) Scanning disc...", terminator: "")
                fflush(stdout)
                try? await Task.sleep(nanoseconds: 100_000_000)
                tick += 1
            }
        }

        let result = try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global().async {
                do { cont.resume(returning: try runner.scan()) }
                catch { cont.resume(throwing: error) }
            }
        }

        spinner.cancel()
        print("\r  \(Colors.teal)✔\(Colors.reset) \(Colors.bold)Scan complete.\(Colors.reset)                              ")
        return result
    }

    // MARK: - Title selection

    private func printTitles(_ titles: [DiscTitle]) {
        let rule = "\(Colors.dim)\(String(repeating: "─", count: 72))\(Colors.reset)"
        print("  \(rule)")
        for t in titles {
            let num  = "[\(t.number)]".padding(toLength: 5, withPad: " ", startingAt: 0)
            let name = t.name.prefix(24).padding(toLength: 24, withPad: " ", startingAt: 0)
            let audio = formatAudio(t.audioTracks)
            print("  \(Colors.glacier)\(num)\(Colors.reset) \(name)  \(Colors.dim)\(t.duration)  \(t.chapters)ch  \(t.sizeFormatted)\(Colors.reset)  \(audio)")
        }
        print("  \(rule)")
    }

    private func formatAudio(_ tracks: [AudioTrack]) -> String {
        guard !tracks.isEmpty else { return "\(Colors.dim)No audio\(Colors.reset)" }
        return tracks.map { track in
            let label = "\(track.language) (\(track.codec))"
            return track.isLossless
                ? "\(Colors.teal)\(label)\(Colors.reset)"
                : "\(Colors.dim)\(label)\(Colors.reset)"
        }.joined(separator: ", ")
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
        isTV: Bool,
        config: Config
    ) async throws -> (title: String, year: String, tmdbId: Int?) {
        let tmdb = TMDBClient(apiKey: config.tmdbApiKey)
        guard tmdb.isConfigured else { return manualEntry() }

        let defaultQuery = discName.map {
            cleanForTMDB($0.replacingOccurrences(of: "_", with: " ").capitalized)
        }

        let query = Prompt.ask("Search TMDB", default: defaultQuery ?? "")
        Colors.info("Searching…")

        let all = try await tmdb.searchMulti(query: query)

        if all.isEmpty {
            Colors.info("No results found.")
            return manualEntry()
        }

        let results = all.filter { isTV ? $0.mediaType == .tv : $0.mediaType == .movie }
        let list    = results.isEmpty ? all : results

        print()
        for (i, r) in list.enumerated() {
            let type = r.mediaType == .tv ? "TV" : "Movie"
            print("  \(Colors.dim)[\(i + 1)]\(Colors.reset) \(r.title) \(Colors.dim)(\(r.year)) [\(type)]\(Colors.reset)")
        }
        print("  \(Colors.dim)[\(list.count + 1)] None of these — enter manually\(Colors.reset)")
        print()

        while true {
            let input = Prompt.ask("Pick a result", default: "1")
            guard let n = Int(input) else { continue }
            if n == list.count + 1 { return manualEntry() }
            if n >= 1, n <= list.count {
                let r = list[n - 1]
                return (r.title, r.year, r.id)
            }
            Colors.error("Enter a number between 1 and \(list.count + 1).")
        }
    }

    private func manualEntry() -> (title: String, year: String, tmdbId: Int?) {
        let title = Prompt.ask("Title")
        let year  = Prompt.ask("Year", default: String(Calendar.current.component(.year, from: Date())))
        return (title, year, nil)
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

    // MARK: - Rip

    private func ripTitle(_ title: DiscTitle, config: Config) async throws -> URL {
        let tempDir = URL(fileURLWithPath: config.tempDir).appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let startTime = Date()
        let runner    = MakeMKVRunner(binPath: config.makemkvBin)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.global().async {
                do {
                    try runner.rip(titleNumber: title.number, to: tempDir, onMessage: { _ in }) { pct in
                        let tick = Int(Date().timeIntervalSince(startTime) * 10)
                        ProgressBar.printRip(percent: pct, message: title.name, tick: tick)
                    }
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }

        print("\r  \(Colors.teal)✔\(Colors.reset) \(Colors.bold)Rip complete.\(Colors.reset)                                        ")
        return try findMKV(in: tempDir)
    }

    private func findMKV(in dir: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        guard let mkv = contents.first(where: { $0.pathExtension.lowercased() == "mkv" }) else {
            throw FrostscribeError.noMKVFound(directory: dir)
        }
        return mkv
    }
}
