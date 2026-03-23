import Foundation
import FrostscribeCore

@MainActor
@Observable
final class RipFlowViewModel {

    // MARK: - Phase

    enum Phase {
        case idle
        case scanning
        case titleSelection(DiscScanResult)
        case mediaType(DiscTitle, DiscScanResult)
        case tmdbSearch(DiscTitle, DiscScanResult, isTV: Bool)
        case tvEpisode(DiscTitle, DiscScanResult, title: String, year: String)
        case audioTrackSelection(DiscTitle, DiscScanResult, title: String, year: String,
                                 isTV: Bool, season: Int, episode: Int)
        case confirmation(RipInput, EncodeInput)
        case ripping(title: String, progress: Int)
        case done(title: String)
        case error(String)
    }

    // MARK: - Published state

    private(set) var phase: Phase = .idle
    private(set) var tmdbResults: [TMDBClient.SearchResult] = []
    private(set) var isSearching = false

    // Persisted across phases for the left panel
    private(set) var posterURL: URL?
    private(set) var confirmedTitle: String?
    private(set) var confirmedYear: String?
    private(set) var confirmedEncodeInput: EncodeInput?

    // Rip estimation
    private(set) var ripEstimate: RipEstimate?

    var estimatedSecondsRemaining: Double? {
        guard let estimate = ripEstimate,
              case .ripping(_, let progress) = phase,
              progress > 0, progress < 100 else { return nil }
        return estimate.seconds * (1.0 - Double(progress) / 100.0)
    }

    var canCancel: Bool {
        switch phase {
        case .idle, .ripping, .done, .error: return false
        default: return true
        }
    }

    var isRipping: Bool {
        if case .ripping = phase { return true }
        return false
    }

    var isTMDBConfigured: Bool {
        !(storedConfig?.tmdbApiKey.isEmpty ?? true)
    }

    // MARK: - Private

    private var storedConfig: Config?
    private var ripTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    // MARK: - Flow entry

    func startRip() {
        guard case .idle = phase else { return }
        phase = .scanning
        ripTask = Task { await scan() }
    }

    private func scan() async {
        do {
            let config = try ConfigManager().load()
            storedConfig = config
            let runner = MakeMKVRunner(binPath: config.makemkvBin)
            let result = try await runner.scan()
            guard !result.titles.isEmpty else {
                phase = .error("No titles found. Is a disc inserted?")
                return
            }
            phase = .titleSelection(result)
        } catch {
            phase = .error("Scan failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Step transitions

    func selectTitle(_ title: DiscTitle, from scanResult: DiscScanResult) {
        phase = .mediaType(title, scanResult)
    }

    func selectMediaType(isTV: Bool, chosenTitle: DiscTitle, scanResult: DiscScanResult) {
        phase = .tmdbSearch(chosenTitle, scanResult, isTV: isTV)

        // Auto-search if TMDB is configured and we have a disc name to start with
        if let name = scanResult.discName, !name.isEmpty, isTMDBConfigured {
            let query = name.replacingOccurrences(of: "_", with: " ").capitalized
            triggerSearch(query: query, chosenTitle: chosenTitle, scanResult: scanResult, isTV: isTV)
        }
    }

    func searchTMDB(query: String, chosenTitle: DiscTitle, scanResult: DiscScanResult, isTV: Bool) {
        triggerSearch(query: query, chosenTitle: chosenTitle, scanResult: scanResult, isTV: isTV)
    }

    private func triggerSearch(query: String, chosenTitle: DiscTitle, scanResult: DiscScanResult, isTV: Bool) {
        guard let config = storedConfig, !config.tmdbApiKey.isEmpty else { return }
        searchTask?.cancel()
        isSearching = true
        tmdbResults = []

        searchTask = Task {
            defer { isSearching = false }
            let tmdb = TMDBClient(apiKey: config.tmdbApiKey)
            guard let results = try? await tmdb.searchMulti(query: query) else { return }
            let filtered = results.filter { isTV ? $0.mediaType == .tv : $0.mediaType == .movie }
            tmdbResults = filtered.isEmpty ? results : filtered
        }
    }

    func confirmTMDB(result: TMDBClient.SearchResult, chosenTitle: DiscTitle,
                     scanResult: DiscScanResult, isTV: Bool) {
        posterURL = result.posterURL
        advance(title: result.title, year: result.year,
                chosenTitle: chosenTitle, scanResult: scanResult, isTV: isTV)
    }

    func enterManually(title: String, year: String, chosenTitle: DiscTitle,
                       scanResult: DiscScanResult, isTV: Bool) {
        advance(title: title, year: year,
                chosenTitle: chosenTitle, scanResult: scanResult, isTV: isTV)
    }

    private func advance(title: String, year: String, chosenTitle: DiscTitle,
                         scanResult: DiscScanResult, isTV: Bool) {
        confirmedTitle = title
        confirmedYear = year
        if isTV {
            phase = .tvEpisode(chosenTitle, scanResult, title: title, year: year)
        } else {
            advanceToAudioOrConfirmation(chosenTitle: chosenTitle, scanResult: scanResult,
                                         title: title, year: year, isTV: false, season: 1, episode: 1)
        }
    }

    func setEpisode(season: Int, episode: Int, chosenTitle: DiscTitle,
                    scanResult: DiscScanResult, title: String, year: String) {
        advanceToAudioOrConfirmation(chosenTitle: chosenTitle, scanResult: scanResult,
                                     title: title, year: year, isTV: true, season: season, episode: episode)
    }

    private func advanceToAudioOrConfirmation(chosenTitle: DiscTitle, scanResult: DiscScanResult,
                                               title: String, year: String, isTV: Bool,
                                               season: Int, episode: Int) {
        let config = storedConfig ?? Config()
        if config.selectAudioTracks && chosenTitle.audioTracks.count > 1 {
            phase = .audioTrackSelection(chosenTitle, scanResult, title: title, year: year,
                                         isTV: isTV, season: season, episode: episode)
        } else {
            buildConfirmation(chosenTitle: chosenTitle, scanResult: scanResult, title: title,
                               year: year, isTV: isTV, season: season, episode: episode, selectedTracks: nil)
        }
    }

    func selectAudioTracks(_ tracks: [Int]?, chosenTitle: DiscTitle, scanResult: DiscScanResult,
                           title: String, year: String, isTV: Bool, season: Int, episode: Int) {
        buildConfirmation(chosenTitle: chosenTitle, scanResult: scanResult, title: title,
                           year: year, isTV: isTV, season: season, episode: episode, selectedTracks: tracks)
    }

    private func buildConfirmation(chosenTitle: DiscTitle, scanResult: DiscScanResult,
                                   title: String, year: String, isTV: Bool,
                                   season: Int, episode: Int, selectedTracks: [Int]?) {
        let config = storedConfig ?? Config()
        let episodeLabel: String?
        let mediaType: RipJob.MediaType
        let outputURL: URL

        if isTV {
            episodeLabel = String(format: "S%02dE%02d", season, episode)
            mediaType = .tvshow
            outputURL = PathBuilder.episodePath(
                show: title, year: year, season: season, episode: episode,
                baseDir: URL(fileURLWithPath: config.tvDir),
                mediaServer: config.mediaServer
            )
        } else {
            episodeLabel = nil
            mediaType = .movie
            outputURL = PathBuilder.moviePath(
                title: title, year: year,
                baseDir: URL(fileURLWithPath: config.moviesDir),
                mediaServer: config.mediaServer
            )
        }

        let jobLabel = [title, episodeLabel].compactMap { $0 }.joined(separator: " — ")
        let store = RipHistoryStore(appSupportURL: ConfigManager.appSupportURL)
        ripEstimate = RipEstimator(store: store).estimate(
            discType: scanResult.discType,
            sizeBytes: chosenTitle.sizeBytes
        )
        let ripInput = RipInput(
            titleNumber: chosenTitle.number,
            baseTemp: URL(fileURLWithPath: config.tempDir),
            mediaType: mediaType,
            jobLabel: jobLabel,
            discType: scanResult.discType,
            titleSizeBytes: chosenTitle.sizeBytes
        )
        let encodeInput = EncodeInput(
            outputURL: outputURL,
            preset: EncoderPreset.preset(for: scanResult.discType),
            title: title,
            episode: episodeLabel,
            selectedAudioTracks: selectedTracks
        )
        confirmedEncodeInput = encodeInput
        phase = .confirmation(ripInput, encodeInput)
    }

    // MARK: - Execute rip

    func confirm(_ ripInput: RipInput, _ encodeInput: EncodeInput) {
        let config = storedConfig ?? Config()
        phase = .ripping(title: ripInput.jobLabel, progress: 0)
        ripTask = Task { await executeRip(ripInput, encode: encodeInput, config: config) }
    }

    private func executeRip(_ ripInput: RipInput, encode encodeInput: EncodeInput, config: Config) async {
        let ripUseCase = RipUseCase(
            runner: MakeMKVRunner(binPath: config.makemkvBin),
            status: StatusManager(appSupportURL: ConfigManager.appSupportURL),
            ejector: DiscEjector(),
            historyStore: RipHistoryStore(appSupportURL: ConfigManager.appSupportURL)
        )
        let encodeUseCase = EncodeUseCase(
            queue: QueueManager(appSupportURL: ConfigManager.appSupportURL)
        )

        do {
            let mkvURL = try await ripUseCase.execute(ripInput) { [weak self] pct in
                Task { @MainActor [weak self] in
                    self?.phase = .ripping(title: ripInput.jobLabel, progress: pct)
                }
            }
            try encodeUseCase.execute(encodeInput, inputMKV: mkvURL)
            if config.notificationsEnabled {
                let svc = NotificationService.shared
                await svc.requestAuthorizationIfNeeded()
                svc.send(title: "Rip Complete", body: "\(ripInput.jobLabel) added to encode queue")
            }
            phase = .done(title: ripInput.jobLabel)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: - Reset

    func reset() {
        ripTask?.cancel()
        searchTask?.cancel()
        ripTask = nil
        searchTask = nil
        storedConfig = nil
        tmdbResults = []
        isSearching = false
        posterURL = nil
        confirmedTitle = nil
        confirmedYear = nil
        confirmedEncodeInput = nil
        ripEstimate = nil
        phase = .idle
    }
}
