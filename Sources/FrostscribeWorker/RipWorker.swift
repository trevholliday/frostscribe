import Foundation
import FrostscribeCore

actor RipWorker {
    private let ripQueueManager: RipQueueManager
    private let encodeQueueManager: any QueueManaging
    private let statusManager: StatusManager
    private let makemkvBin: String
    private let hookRunner: HookRunner
    private let logStore: LogStore
    private var running = false
    private var activeRipTask: Task<Void, Error>? = nil
    private let pollInterval: TimeInterval = 5
    private let dateFormatter: ISO8601DateFormatter = ISO8601DateFormatter()

    init(
        ripQueueManager: RipQueueManager,
        encodeQueueManager: any QueueManaging,
        statusManager: StatusManager,
        makemkvBin: String,
        hookRunner: HookRunner,
        logStore: LogStore
    ) {
        self.ripQueueManager    = ripQueueManager
        self.encodeQueueManager = encodeQueueManager
        self.statusManager      = statusManager
        self.makemkvBin         = makemkvBin
        self.hookRunner         = hookRunner
        self.logStore           = logStore
    }

    func start() async {
        running = true
        log("Rip worker ready")
        while running {
            await poll()
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }

    func stop() {
        running = false
        // Cancel any in-flight rip so makemkvcon doesn't outlive the worker.
        activeRipTask?.cancel()
        activeRipTask = nil
        // Reset any in-flight rip back to pending so the next start retries it.
        if let count = try? ripQueueManager.resetStuck(), count > 0 {
            log("Reset \(count) interrupted rip job(s) to pending")
        }
    }

    // MARK: - Poll

    private func poll() async {
        let jobs: [RipQueueJob]
        do {
            jobs = try ripQueueManager.read()
        } catch {
            log("Failed to read rip queue: \(error)", level: "error")
            return
        }
        guard let job = jobs.first(where: { $0.status == .pending }) else { return }
        await rip(job)
    }

    // MARK: - Rip

    private func rip(_ job: RipQueueJob) async {
        log("Starting rip: \(job.jobLabel)")
        do {
            try ripQueueManager.updateStatus(id: job.id, status: .ripping, startedAt: .now)

            let mediaType = RipJob.MediaType(rawValue: job.mediaType) ?? .movie
            let discType  = DiscType(rawValue: job.discType) ?? .unknown
            let ripInput  = RipInput(
                titleNumber: job.titleNumber,
                baseTemp: URL(fileURLWithPath: job.baseTempPath),
                mediaType: mediaType,
                jobLabel: job.jobLabel,
                discType: discType,
                titleSizeBytes: job.titleSizeBytes
            )
            let ripUseCase = RipUseCase(
                runner: MakeMKVRunner(binPath: makemkvBin),
                status: statusManager,
                ejector: DiscEjector(),
                historyStore: RipHistoryStore(appSupportURL: ConfigManager.appSupportURL)
            )

            // Wrap in a Task so the cancellation watcher (and stop()) can cancel it.
            let ripTask = Task { try await ripUseCase.execute(ripInput) { _ in } }
            activeRipTask = ripTask

            // Watch for a cancellation signal written to the queue by the UI.
            let queueManager = ripQueueManager
            let watchTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    if let updated = try? queueManager.read().first(where: { $0.id == job.id }),
                       updated.status == .cancelled {
                        ripTask.cancel()
                        return
                    }
                }
            }

            let mkvURL: URL
            do {
                mkvURL = try await ripTask.value
                activeRipTask = nil
            } catch {
                activeRipTask = nil
                watchTask.cancel()
                if error is CancellationError || ripTask.isCancelled {
                    log("Rip cancelled: \(job.jobLabel)")
                    try? ripQueueManager.updateStatus(id: job.id, status: .cancelled)
                } else {
                    log("Rip failed for \(job.jobLabel): \(error)", level: "error")
                    try? ripQueueManager.updateStatus(id: job.id, status: .error,
                                                     errorMessage: error.localizedDescription)
                    hookRunner.fire(event: "rip_failed", title: "Rip Failed", body: job.jobLabel)
                }
                return
            }
            watchTask.cancel()

            let config     = (try? ConfigManager().load()) ?? Config()
            let skipEncode = config.skipEncodingDVD && (discType == .dvd || discType == .unknown)

            if skipEncode {
                // Move raw MKV directly to the library, skipping HandBrake.
                let outputURL = URL(fileURLWithPath: job.outputPath)
                try FileManager.default.createDirectory(
                    at: outputURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? FileManager.default.removeItem(at: outputURL)
                try FileManager.default.moveItem(at: mkvURL, to: outputURL)
                try? FileManager.default.removeItem(at: mkvURL.deletingLastPathComponent())
                log("Rip complete, raw MKV moved to library (encoding skipped): \(job.jobLabel)")
                try ripQueueManager.updateStatus(id: job.id, status: .done, completedAt: .now)
                hookRunner.fire(event: "rip_complete", title: "Rip Complete", body: job.jobLabel)
            } else {
                // Hand off to encode queue
                try encodeQueueManager.add(
                    input: mkvURL,
                    output: URL(fileURLWithPath: job.outputPath),
                    preset: job.preset,
                    discType: job.discType,
                    title: job.encodeTitle,
                    episode: job.episode,
                    audioTracks: job.audioTracks
                )
                log("Rip complete, queued encode: \(job.jobLabel)")
                try ripQueueManager.updateStatus(id: job.id, status: .done, completedAt: .now)
                hookRunner.fire(event: "rip_complete", title: "Rip Complete",
                                body: "\(job.jobLabel) added to encode queue")
            }
        } catch {
            let nsErr = error as NSError
            if nsErr.domain == NSCocoaErrorDomain && nsErr.code == 513 {
                log("NAS write permission denied for \(job.jobLabel) — stopping worker. Check NAS access and restart.", level: "error")
                hookRunner.fire(event: "nas_permission_error", title: "NAS Permission Error", body: "Worker stopped — check NAS write access.")
                stop()
                return
            }
            log("Rip failed for \(job.jobLabel): \(error)", level: "error")
            try? ripQueueManager.updateStatus(id: job.id, status: .error,
                                              errorMessage: error.localizedDescription)
            hookRunner.fire(event: "rip_failed", title: "Rip Failed", body: job.jobLabel)
        }
    }

    private func log(_ message: String, level: String = "info") {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] \(message)")
        fflush(stdout)
        logStore.append(timestamp: timestamp, message: message, level: level)
    }
}
