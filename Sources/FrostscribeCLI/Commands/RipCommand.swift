import ArgumentParser
import Foundation
import FrostscribeCore

struct RipCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rip",
        abstract: "Start an interactive disc ripping session."
    )

    func run() throws {
        let config: Config
        do { config = try ConfigManager().load() }
        catch FrostscribeError.configNotFound {
            Colors.error("Not configured — run 'frostscribe init' first.")
            throw ExitCode.failure
        }

        Colors.section("Frostscribe Rip")
        print()

        let scanResult = try scanDisc(config: config)

        guard !scanResult.titles.isEmpty else {
            Colors.error("No titles found. Is a disc inserted?")
            throw ExitCode.failure
        }

        printTitles(scanResult.titles)
        let chosen = pickTitle(from: scanResult.titles)

        print()
        let isTV = Prompt.pick("Media type", options: ["Movie", "TV Show"]) == "TV Show"

        print()
        let (title, year, _) = try lookupMedia(discName: scanResult.discName, isTV: isTV, config: config)

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
        let mkv = try ripTitle(chosen, config: config)

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
        let label = [title, episodeLabel].compactMap { $0 }.joined(separator: " — ")
        Colors.success("\(label) added to encode queue.")
        Colors.info("Run \(Colors.bold)frostscribe queue\(Colors.reset) to check progress.")
        print()
    }

    // MARK: - Scan

    private func scanDisc(config: Config) throws -> MakeMKVRunner.ScanResult {
        let done = Flag()
        let spinQueue = DispatchQueue(label: "frostscribe.spinner")
        spinQueue.async {
            var tick = 0
            while !done.value {
                print("\r  \(Colors.frostCyan)\(ProgressBar.spin(tick))\(Colors.reset) Scanning disc...", terminator: "")
                fflush(stdout)
                Thread.sleep(forTimeInterval: 0.1)
                tick += 1
            }
        }
        let result = try MakeMKVRunner(binPath: config.makemkvBin).scan()
        done.value = true
        Thread.sleep(forTimeInterval: 0.15)
        print("\r  \(Colors.teal)✔\(Colors.reset) \(Colors.bold)Scan complete.\(Colors.reset)                              ")
        return result
    }

    // MARK: - Title selection

    private func printTitles(_ titles: [DiscTitle]) {
        let rule = "\(Colors.dim)\(String(repeating: "─", count: 58))\(Colors.reset)"
        print("  \(rule)")
        for t in titles {
            let num  = "[\(t.number)]".padding(toLength: 5, withPad: " ", startingAt: 0)
            let name = t.name.prefix(28).padding(toLength: 28, withPad: " ", startingAt: 0)
            print("  \(Colors.glacier)\(num)\(Colors.reset) \(name)  \(Colors.dim)\(t.duration)  \(t.chapters)ch  \(t.sizeFormatted)\(Colors.reset)")
        }
        print("  \(rule)")
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
    ) throws -> (title: String, year: String, tmdbId: Int?) {
        let tmdb = TMDBClient(apiKey: config.tmdbApiKey)
        guard tmdb.isConfigured else { return manualEntry() }

        let defaultQuery = discName?
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        let query = Prompt.ask("Search TMDB", default: defaultQuery ?? "")
        Colors.info("Searching…")

        let all = try fetch { try await tmdb.searchMulti(query: query) }

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
        let year  = Prompt.ask("Year", default: currentYear())
        return (title, year, nil)
    }

    // MARK: - Output path

    private func buildOutputURL(
        title: String,
        year: String,
        season: Int,
        episode: Int,
        isTV: Bool,
        config: Config
    ) -> URL {
        if isTV {
            return PathBuilder.episodePath(
                show: title,
                year: year,
                season: season,
                episode: episode,
                baseDir: URL(fileURLWithPath: config.tvDir),
                mediaServer: config.mediaServer
            )
        } else {
            return PathBuilder.moviePath(
                title: title,
                year: year,
                baseDir: URL(fileURLWithPath: config.moviesDir),
                mediaServer: config.mediaServer
            )
        }
    }

    // MARK: - Rip

    private func ripTitle(_ title: DiscTitle, config: Config) throws -> URL {
        let tempDir = URL(fileURLWithPath: config.tempDir).appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let tick = Counter()
        try MakeMKVRunner(binPath: config.makemkvBin).rip(
            titleNumber: title.number,
            to: tempDir,
            onMessage: { _ in },
            onProgress: { pct in
                ProgressBar.printRip(percent: pct, message: title.name, tick: tick.value)
                tick.value += 1
            }
        )

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

    // MARK: - Async bridge

    private func fetch<T: Sendable>(_ block: @Sendable @escaping () async throws -> T) throws -> T {
        let box = ResultBox<T>()
        let sem = DispatchSemaphore(value: 0)
        Task {
            do { box.result = .success(try await block()) }
            catch { box.result = .failure(error) }
            sem.signal()
        }
        sem.wait()
        return try box.result!.get()
    }

    // MARK: - Utilities

    private func currentYear() -> String {
        String(Calendar.current.component(.year, from: Date()))
    }
}

private final class Flag: @unchecked Sendable {
    var value = false
}

private final class Counter: @unchecked Sendable {
    var value = 0
}

private final class ResultBox<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}
