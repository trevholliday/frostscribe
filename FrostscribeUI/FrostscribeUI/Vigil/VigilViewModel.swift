import Foundation
import FrostscribeCore

@MainActor
@Observable
final class VigilViewModel {

    // MARK: - State

    enum Phase: Equatable {
        case idle
        case scanning
        case ripping(progress: Int)
        case error(String)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.scanning, .scanning): return true
            case (.ripping(let a), .ripping(let b)): return a == b
            case (.error(let a), .error(let b)):     return a == b
            default: return false
            }
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var currentTitle: String = ""
    var isWatching: Bool { watcher != nil }

    // MARK: - Private

    private var watcher: VigilWatcher?
    private var observerTask: Task<Void, Never>?
    private var ripTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func startWatchingIfEnabled() {
        let config = (try? ConfigManager().load()) ?? Config()
        // vigilMode=true means user is present (guided/interactive). AutoScribe runs only when vigilMode=false.
        guard !config.vigilMode else { return }

        let w = VigilWatcher()
        observerTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .vigilDiscInserted) {
                await self?.discInserted()
            }
        }
        w.start()
        watcher = w
    }

    func stopWatching() {
        watcher?.stop()
        watcher = nil
        observerTask?.cancel()
        observerTask = nil
        ripTask?.cancel()
        ripTask = nil
    }

    // MARK: - Disc handling

    private func discInserted() {
        guard phase == .idle else { return }
        // Don't start a new rip if one is already running (e.g. via CLI or a previous vigil trigger)
        let status = try? StatusManager(appSupportURL: ConfigManager.appSupportURL).read()
        guard status?.status != .ripping else { return }
        ripTask = Task { await autoRip() }
    }

    private func autoRip() async {
        let config: Config
        do { config = try ConfigManager().load() }
        catch {
            phase = .error("Config missing — run frostscribe init")
            await resetAfterDelay()
            return
        }

        phase = .scanning

        let runner = MakeMKVRunner(binPath: config.makemkvBin)
        let hook = HookRunner(command: config.eventHook)

        let scanResult: DiscScanResult
        do { scanResult = try await runner.scan() }
        catch {
            // Not a supported disc — ignore silently
            phase = .idle
            return
        }

        guard let largestTitle = scanResult.titles.max(by: { $0.sizeBytes < $1.sizeBytes }) else {
            phase = .idle
            return
        }

        let (mediaTitle, year, mediaType) = await lookupTitle(discName: scanResult.discName, config: config)
        guard let mediaTitle else {
            hook.fire(event: "vigil_unknown_disc", title: "Unknown Disc",
                      body: "Vigil Mode could not identify this disc. Run 'frostscribe rip' manually.")
            phase = .idle
            return
        }

        // TV shows need interactive episode selection — hand off to the user
        if mediaType == .tv {
            hook.fire(event: "vigil_tv_identified", title: "TV Disc Identified: \(mediaTitle)",
                      body: "Run 'frostscribe rip' to select episodes and start ripping.")
            phase = .idle
            return
        }

        currentTitle = mediaTitle

        let outputURL = PathBuilder.moviePath(
            title: mediaTitle,
            year: year,
            baseDir: URL(fileURLWithPath: config.moviesDir),
            mediaServer: config.mediaServer
        )

        let ripInput = RipInput(
            titleNumber: largestTitle.number,
            baseTemp: URL(fileURLWithPath: config.tempDir),
            mediaType: .movie,
            jobLabel: mediaTitle,
            discType: scanResult.discType,
            titleSizeBytes: largestTitle.sizeBytes
        )

        let encodeInput = EncodeInput(
            outputURL: outputURL,
            preset: EncoderPreset.preset(for: scanResult.discType),
            title: mediaTitle,
            quality: EncoderPreset.quality(for: scanResult.discType, config: config)
        )

        hook.fire(event: "ripping_started", title: "Ripping Started", body: mediaTitle)

        let ripUseCase = RipUseCase(
            runner: runner,
            status: StatusManager(appSupportURL: ConfigManager.appSupportURL),
            ejector: DiscEjector(),
            historyStore: RipHistoryStore(appSupportURL: ConfigManager.appSupportURL)
        )

        let encodeUseCase = EncodeUseCase(
            queue: QueueManager(appSupportURL: ConfigManager.appSupportURL)
        )

        phase = .ripping(progress: 0)

        do {
            let mkvURL = try await ripUseCase.execute(ripInput) { [weak self] pct in
                Task { @MainActor [weak self] in
                    self?.phase = .ripping(progress: pct)
                }
            }
            try encodeUseCase.execute(encodeInput, inputMKV: mkvURL)
            hook.fire(event: "rip_complete", title: "Rip Complete", body: "\(mediaTitle) — added to encode queue")
        } catch {
            hook.fire(event: "rip_failed", title: "Rip Failed", body: mediaTitle)
            phase = .error(error.localizedDescription)
            await resetAfterDelay()
            return
        }

        phase = .idle
        currentTitle = ""
    }

    // MARK: - TMDB

    private func lookupTitle(discName: String?, config: Config) async -> (String?, String, TMDBClient.MediaType?) {
        let currentYear = String(Calendar.current.component(.year, from: Date()))
        let tmdb = TMDBClient(apiKey: config.tmdbApiKey)
        guard tmdb.isConfigured, let name = discName else { return (nil, currentYear, nil) }

        let query = name
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        guard let results = try? await tmdb.searchMulti(query: query),
              let top = results.first else {
            return (nil, currentYear, nil)
        }
        return (top.title, top.year.isEmpty ? currentYear : top.year, top.mediaType)
    }

    private func resetAfterDelay() async {
        try? await Task.sleep(for: .seconds(8))
        phase = .idle
        currentTitle = ""
    }
}
