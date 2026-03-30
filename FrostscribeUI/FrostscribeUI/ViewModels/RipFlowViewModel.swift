import Foundation
import FrostscribeCore

@MainActor
@Observable
final class RipFlowCoordinator {

    // MARK: - Phase

    enum Phase {
        case idle
        case scanning
        case identify(DiscScanResult)
        case tvEpisode(DiscScanResult, title: String, year: String)
        case titleSelection(DiscScanResult, title: String, year: String, isTV: Bool, season: Int, episode: Int)
        case audioTrackSelection(DiscTitle, DiscScanResult, title: String, year: String,
                                 isTV: Bool, season: Int, episode: Int)
        case confirmation(RipInput, EncodeInput)
        case ripping(title: String, progress: Int)
        case done(title: String)
        case error(String)
    }

    // MARK: - State

    private(set) var phase: Phase = .idle
    private(set) var tmdbResults: [TMDBClient.SearchResult] = []
    private(set) var isSearching = false
    private(set) var scanMessage: String = ""
    private(set) var ripMessage: String = ""
    private(set) var suggestedTitleNumber: Int?

    private(set) var posterURL: URL?
    private(set) var backdropURLs: [URL] = []
    private(set) var confirmedTitle: String?
    private(set) var confirmedYear: String?
    private(set) var confirmedEncodeInput: EncodeInput?
    private(set) var mediaDetails: MediaDetails?
    private(set) var confirmedTmdbId: Int?
    private(set) var confirmedTmdbMediaType: String?

    var carouselURLs: [URL] {
        backdropURLs.isEmpty ? [posterURL].compactMap { $0 } : backdropURLs
    }

    private(set) var ripEstimate: RipEstimate?

    private var phaseStack: [Phase] = []

    var canGoBack: Bool { !phaseStack.isEmpty }

    func goBack() {
        guard !phaseStack.isEmpty else { return }
        phase = phaseStack.removeLast()
    }

    var filterMovieTitles: Bool { storedConfig?.filterMovieTitles ?? true }

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

    var canAbort: Bool {
        switch phase {
        case .idle, .done, .error: return false
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

    // MARK: - Dependencies

    private let configLoader: any ConfigLoading
    private let ripQueue: any RipQueueManaging
    private let makeMKVFactory: @Sendable (String) -> any MakeMKVRunning
    private let tmdbFactory: @Sendable (String) -> any TMDBSearching

    // MARK: - Private state

    private var storedConfig: Config?
    private var ripTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var currentRipJobId: String?

    // MARK: - Init

    init(
        configLoader: any ConfigLoading = ConfigManager(),
        ripQueue: any RipQueueManaging = RipQueueManager(appSupportURL: ConfigManager.appSupportURL),
        makeMKVFactory: @escaping @Sendable (String) -> any MakeMKVRunning = { MakeMKVRunner(binPath: $0) },
        tmdbFactory: @escaping @Sendable (String) -> any TMDBSearching = { TMDBClient(apiKey: $0) }
    ) {
        self.configLoader = configLoader
        self.ripQueue = ripQueue
        self.makeMKVFactory = makeMKVFactory
        self.tmdbFactory = tmdbFactory
    }

    // MARK: - Navigation

    func goBack() {
        guard !phaseStack.isEmpty else { return }
        phase = phaseStack.removeLast()
    }

    func ejectDisc() {
        Task.detached { DiscEjector().eject() }
    }

    // MARK: - Initialize (resume in-progress rip on launch)

    func initialize() {
        guard case .idle = phase else { return }
        let statusMgr = StatusManager(appSupportURL: ConfigManager.appSupportURL)

        guard let file = try? statusMgr.read(),
              file.status == .ripping,
              let currentJob = file.currentJob,
              let jobs = try? ripQueue.read(),
              let queueJob = jobs.first(where: { $0.isActive }) else { return }

        let pct   = Int(currentJob.progress.replacing("%", with: "")) ?? 0
        let title = queueJob.encodeTitle
        let yearMatch = queueJob.jobLabel.range(of: #"\((\d{4})\)"#, options: .regularExpression)
        let year = yearMatch.map { String(queueJob.jobLabel[$0].dropFirst().dropLast()) } ?? ""

        confirmedTitle = title
        confirmedYear  = year

        let discType = DiscType(rawValue: queueJob.discType) ?? .unknown
        let store = RipHistoryStore(appSupportURL: ConfigManager.appSupportURL)
        ripEstimate = RipEstimator(store: store).estimate(discType: discType, sizeBytes: queueJob.titleSizeBytes)

        currentRipJobId = queueJob.id
        phase = .ripping(title: queueJob.jobLabel, progress: pct)
        ripTask = Task { await pollRip(jobId: queueJob.id, title: queueJob.jobLabel) }

        guard let config = try? configLoader.load(), !config.tmdbApiKey.isEmpty else { return }
        storedConfig = config
        let isTV = queueJob.mediaType == "tvshow"
        let storedTmdbId = queueJob.tmdbId
        let storedTmdbType = queueJob.tmdbMediaType
        let tmdb = tmdbFactory(config.tmdbApiKey)
        Task {
            let resolvedId: Int
            let resolvedType: TMDBClient.MediaType

            if let tmdbId = storedTmdbId,
               let typeStr = storedTmdbType,
               let mediaType = TMDBClient.MediaType(rawValue: typeStr) {
                resolvedId = tmdbId
                resolvedType = mediaType
            } else {
                let query = year.isEmpty ? title : "\(title) \(year)"
                guard let results = try? await tmdb.searchMulti(query: query),
                      let best = results.first(where: { isTV ? $0.mediaType == .tv : $0.mediaType == .movie })
                               ?? results.first else { return }
                posterURL = best.posterURL
                resolvedId = best.id
                resolvedType = best.mediaType
            }

            async let backdropFetch = tmdb.backdrops(id: resolvedId, mediaType: resolvedType)
            async let detailsFetch  = tmdb.details(id: resolvedId, mediaType: resolvedType)
            let urls = (try? await backdropFetch) ?? []
            backdropURLs = urls.isEmpty ? [] : urls
            mediaDetails = try? await detailsFetch
        }
    }

    // MARK: - Flow entry

    func startRip() {
        guard case .idle = phase else { return }
        phase = .scanning
        ripTask = Task { await scan() }
    }

    private func scan() async {
        do {
            let config = try configLoader.load()
            storedConfig = config
            let runner = makeMKVFactory(config.makemkvBin)
            let result = try await runner.scan { [weak self] line in
                guard let self else { return }
                switch MakeMKVParser.parse(line) {
                case .message(let msg) where !msg.isEmpty:
                    Task { @MainActor in self.scanMessage = msg }
                case .progressTitle(let msg) where !msg.isEmpty:
                    Task { @MainActor in self.scanMessage = msg }
                default:
                    break
                }
            }
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
        guard let config = storedConfig, !config.tmdbApiKey.isEmpty else { return }
        searchTask?.cancel()
        isSearching = true
        tmdbResults = []

        let tmdb = tmdbFactory(config.tmdbApiKey)
        searchTask = Task {
            defer { isSearching = false }
            guard let results = try? await tmdb.searchMulti(query: query) else { return }
            let filtered = results.filter { isTV ? $0.mediaType == .tv : $0.mediaType == .movie }
            tmdbResults = filtered.isEmpty ? results : filtered
        }
    }

    func confirmTMDB(result: TMDBClient.SearchResult, scanResult: DiscScanResult, isTV: Bool) {
        confirmedTmdbId = result.id
        confirmedTmdbMediaType = result.mediaType == .tv ? "tv" : "movie"
        posterURL = result.posterURL
        if let config = storedConfig {
            let tmdb = tmdbFactory(config.tmdbApiKey)
            Task {
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
        if let config = storedConfig, !config.tmdbApiKey.isEmpty {
            let tmdb = tmdbFactory(config.tmdbApiKey)
            Task {
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
        phaseStack.append(phase)
        confirmedTitle = title
        confirmedYear = year
        if isTV {
            phase = .tvEpisode(scanResult, title: title, year: year)
        } else {
            suggestedTitleNumber = HeuristicTitleSuggester().suggest(from: scanResult.titles)?.number
            phase = .titleSelection(scanResult, title: title, year: year,
                                    isTV: false, season: 1, episode: 1)
        }
    }

    // MARK: - TV episode

    func setEpisode(season: Int, episode: Int, scanResult: DiscScanResult,
                    title: String, year: String) {
        phaseStack.append(phase)
        suggestedTitleNumber = HeuristicTitleSuggester().suggest(from: scanResult.titles)?.number
        phase = .titleSelection(scanResult, title: title, year: year,
                                isTV: true, season: season, episode: episode)
    }

    // MARK: - Title selection

    func selectTitle(_ discTitle: DiscTitle, scanResult: DiscScanResult,
                     mediaTitle: String, year: String,
                     isTV: Bool, season: Int, episode: Int) {
        phaseStack.append(phase)
        let mediaType: RipJob.MediaType = isTV ? .tvshow : .movie
        Task.detached {
            TitleSelectionStore(appSupportURL: ConfigManager.appSupportURL).record(
                selected: discTitle,
                allTitles: scanResult.titles,
                discType: scanResult.discType,
                mediaType: mediaType,
                discName: scanResult.discName
            )
        }
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
                               year: year, isTV: isTV, season: season, episode: episode,
                               selectedTracks: nil)
        }
    }

    func selectAudioTracks(_ tracks: [Int]?, chosenTitle: DiscTitle, scanResult: DiscScanResult,
                           title: String, year: String, isTV: Bool, season: Int, episode: Int) {
        phaseStack.append(phase)
        buildConfirmation(chosenTitle: chosenTitle, scanResult: scanResult, title: title,
                           year: year, isTV: isTV, season: season, episode: episode,
                           selectedTracks: tracks)
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
            titleSizeBytes: chosenTitle.sizeBytes,
            tmdbId: confirmedTmdbId,
            tmdbMediaType: confirmedTmdbMediaType
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

    // MARK: - Enqueue rip

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
            tmdbId: ripInput.tmdbId,
            tmdbMediaType: ripInput.tmdbMediaType
        )

        do {
            try ripQueue.add(job)
        } catch {
            phase = .error("Failed to queue rip: \(error.localizedDescription)")
            return
        }

        kickWorker()

        currentRipJobId = job.id
        phase = .ripping(title: ripInput.jobLabel, progress: 0)
        let jobId = job.id
        let title = ripInput.jobLabel
        ripTask = Task { await pollRip(jobId: jobId, title: title) }
    }

    private func kickWorker() {
        Task.detached {
            let check = Process()
            check.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            check.arguments = ["list"]
            let pipe = Pipe()
            check.standardOutput = pipe
            check.standardError = FileHandle.nullDevice
            try? check.run()
            check.waitUntilExit()

            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let workerLine = output.split(separator: "\n").first { $0.contains("com.frostscribe.worker") }
            let pid = workerLine?.split(separator: "\t").first.map(String.init)?
                .trimmingCharacters(in: .whitespaces) ?? "-"
            guard pid == "-" else { return }

            let start = Process()
            start.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            start.arguments = ["start", "com.frostscribe.worker"]
            start.standardOutput = FileHandle.nullDevice
            start.standardError = FileHandle.nullDevice
            try? start.run()
        }
    }

    private func pollRip(jobId: String, title: String) async {
        let statusMgr = StatusManager(appSupportURL: ConfigManager.appSupportURL)

        while !Task.isCancelled {
            if let file = try? statusMgr.read(),
               file.status == .ripping,
               let currentJob = file.currentJob {
                let pct = Int(currentJob.progress.replacing("%", with: "")) ?? 0
                phase = .ripping(title: title, progress: pct)
                if let msg = currentJob.currentItem, !msg.isEmpty {
                    ripMessage = msg
                }
            }

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
                    phase = .idle
                    return
                }
            }

            try? await Task.sleep(for: .seconds(2))
        }
    }

    // MARK: - Reset

    func reset() {
        if let jobId = currentRipJobId {
            try? ripQueue.markCancelled(id: jobId)
        }
        currentRipJobId = nil
        ripTask?.cancel()
        phaseStack = []
        searchTask?.cancel()
        ripTask = nil
        searchTask = nil
        storedConfig = nil
        tmdbResults = []
        isSearching = false
        scanMessage = ""
        ripMessage = ""
        suggestedTitleNumber = nil
        posterURL = nil
        backdropURLs = []
        mediaDetails = nil
        confirmedTitle = nil
        confirmedYear = nil
        confirmedEncodeInput = nil
        confirmedTmdbId = nil
        confirmedTmdbMediaType = nil
        ripEstimate = nil
        phase = .idle
    }
}

// MARK: - Compatibility typealias

/// Retained so Xcode's project file reference remains valid.
typealias RipFlowViewModel = RipFlowCoordinator
