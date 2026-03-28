import Foundation
import FrostscribeCore

@MainActor
@Observable
final class RipFlowViewModel {

    // MARK: - Phase

    enum Phase {
        case idle
        case scanning
        case identify(DiscScanResult)                         // TMDB search + media type selection
        case tvEpisode(DiscScanResult, title: String, year: String)
        case titleSelection(DiscScanResult, title: String, year: String, isTV: Bool, season: Int, episode: Int)
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

    // Persisted across phases for the left panel / carousel
    private(set) var posterURL: URL?
    private(set) var backdropURLs: [URL] = []
    private(set) var confirmedTitle: String?
    private(set) var confirmedYear: String?
    private(set) var confirmedEncodeInput: EncodeInput?
    private(set) var mediaDetails: MediaDetails?

    var carouselURLs: [URL] {
        backdropURLs.isEmpty ? [posterURL].compactMap { $0 } : backdropURLs
    }

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
            phase = .identify(result)
        } catch {
            phase = .error("Scan failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Identify / TMDB

    func searchTMDB(query: String, scanResult: DiscScanResult, isTV: Bool) {
        triggerSearch(query: query, scanResult: scanResult, isTV: isTV)
    }

    private func triggerSearch(query: String, scanResult: DiscScanResult, isTV: Bool) {
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

    func confirmTMDB(result: TMDBClient.SearchResult, scanResult: DiscScanResult, isTV: Bool) {
        posterURL = result.posterURL
        if let config = storedConfig {
            Task {
                let tmdb = TMDBClient(apiKey: config.tmdbApiKey)
                async let backdropFetch = tmdb.backdrops(id: result.id, mediaType: result.mediaType)
                async let detailsFetch  = tmdb.details(id: result.id, mediaType: result.mediaType)
                let urls = (try? await backdropFetch) ?? []
                backdropURLs = urls.isEmpty ? [result.backdropURL].compactMap { $0 } : urls
                mediaDetails = try? await detailsFetch
            }
        }
        advance(title: result.title, year: result.year, scanResult: scanResult, isTV: isTV)
    }

    func enterManually(title: String, year: String, scanResult: DiscScanResult, isTV: Bool) {
        // Attempt a background TMDB lookup to fetch images even for manual entries
        if let config = storedConfig, !config.tmdbApiKey.isEmpty {
            Task {
                let tmdb = TMDBClient(apiKey: config.tmdbApiKey)
                let query = year.isEmpty ? title : "\(title) \(year)"
                if let results = try? await tmdb.searchMulti(query: query),
                   let best = results.first {
                    posterURL = best.posterURL
                    async let backdropFetch = tmdb.backdrops(id: best.id, mediaType: best.mediaType)
                    async let detailsFetch  = tmdb.details(id: best.id, mediaType: best.mediaType)
                    let urls = (try? await backdropFetch) ?? []
                    backdropURLs = urls.isEmpty ? [best.backdropURL].compactMap { $0 } : urls
                    mediaDetails = try? await detailsFetch
                }
            }
        }
        advance(title: title, year: year, scanResult: scanResult, isTV: isTV)
    }

    private func advance(title: String, year: String, scanResult: DiscScanResult, isTV: Bool) {
        confirmedTitle = title
        confirmedYear = year
        if isTV {
            phase = .tvEpisode(scanResult, title: title, year: year)
        } else {
            phase = .titleSelection(scanResult, title: title, year: year,
                                    isTV: false, season: 1, episode: 1)
        }
    }

    // MARK: - TV episode

    func setEpisode(season: Int, episode: Int, scanResult: DiscScanResult,
                    title: String, year: String) {
        phase = .titleSelection(scanResult, title: title, year: year,
                                isTV: true, season: season, episode: episode)
    }

    // MARK: - Title selection

    func selectTitle(_ discTitle: DiscTitle, scanResult: DiscScanResult,
                     mediaTitle: String, year: String,
                     isTV: Bool, season: Int, episode: Int) {
        advanceToAudioOrConfirmation(chosenTitle: discTitle, scanResult: scanResult,
                                     title: mediaTitle, year: year,
                                     isTV: isTV, season: season, episode: episode)
    }

    // MARK: - Audio tracks

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
            selectedAudioTracks: selectedTracks,
            quality: EncoderPreset.quality(for: scanResult.discType, config: config)
        )
        confirmedEncodeInput = encodeInput
        phase = .confirmation(ripInput, encodeInput)
    }

    // MARK: - Enqueue rip (handed off to background worker)

    func confirm(_ ripInput: RipInput, _ encodeInput: EncodeInput) {
        let job = RipQueueJob(
            titleNumber: ripInput.titleNumber,
            baseTempPath: ripInput.baseTemp.path,
            mediaType: ripInput.mediaType.rawValue,
            jobLabel: ripInput.jobLabel,
            discType: ripInput.discType.rawValue,
            titleSizeBytes: ripInput.titleSizeBytes,
            outputPath: encodeInput.outputURL.path,
            preset: encodeInput.preset,
            encodeTitle: encodeInput.title,
            episode: encodeInput.episode,
            audioTracks: encodeInput.selectedAudioTracks,
            quality: encodeInput.quality
        )

        let ripQueue = RipQueueManager(appSupportURL: ConfigManager.appSupportURL)
        do {
            try ripQueue.add(job)
        } catch {
            phase = .error("Failed to queue rip: \(error.localizedDescription)")
            return
        }

        phase = .ripping(title: ripInput.jobLabel, progress: 0)
        let jobId = job.id
        let title = ripInput.jobLabel
        ripTask = Task { await pollRip(jobId: jobId, title: title) }
    }

    private func pollRip(jobId: String, title: String) async {
        let ripQueue  = RipQueueManager(appSupportURL: ConfigManager.appSupportURL)
        let statusMgr = StatusManager(appSupportURL: ConfigManager.appSupportURL)

        while !Task.isCancelled {
            // Reflect live progress from the status file (written by worker's RipUseCase)
            if let file = try? statusMgr.read(),
               file.status == .ripping,
               let currentJob = file.currentJob {
                let pct = Int(currentJob.progress.replacingOccurrences(of: "%", with: "")) ?? 0
                phase = .ripping(title: title, progress: pct)
            }

            // Check rip queue for terminal state
            if let jobs = try? ripQueue.read() {
                if let job = jobs.first(where: { $0.id == jobId }) {
                    switch job.status {
                    case .done:
                        phase = .done(title: title)
                        return
                    case .error:
                        phase = .error(job.errorMessage ?? "Rip failed")
                        return
                    default:
                        break
                    }
                } else {
                    // Job was removed (e.g. queue cleared) — reset to idle
                    phase = .idle
                    return
                }
            }

            try? await Task.sleep(for: .seconds(2))
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
        backdropURLs = []
        mediaDetails = nil
        confirmedTitle = nil
        confirmedYear = nil
        confirmedEncodeInput = nil
        ripEstimate = nil
        phase = .idle
    }
}
