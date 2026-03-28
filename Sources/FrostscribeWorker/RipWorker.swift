import Foundation
import FrostscribeCore

actor RipWorker {
    private let ripQueueManager: RipQueueManager
    private let encodeQueueManager: any QueueManaging
    private let statusManager: StatusManager
    private let makemkvBin: String
    private let hookRunner: HookRunner
    private var running = false
    private let pollInterval: TimeInterval = 5

    init(
        ripQueueManager: RipQueueManager,
        encodeQueueManager: any QueueManaging,
        statusManager: StatusManager,
        makemkvBin: String,
        hookRunner: HookRunner
    ) {
        self.ripQueueManager    = ripQueueManager
        self.encodeQueueManager = encodeQueueManager
        self.statusManager      = statusManager
        self.makemkvBin         = makemkvBin
        self.hookRunner         = hookRunner
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
    }

    // MARK: - Poll

    private func poll() async {
        let jobs: [RipQueueJob]
        do {
            jobs = try ripQueueManager.read()
        } catch {
            log("Failed to read rip queue: \(error)")
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

            let ripInput = RipInput(
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

            let mkvURL = try await ripUseCase.execute(ripInput) { _ in }

            // Hand off to encode queue
            try encodeQueueManager.add(
                input: mkvURL,
                output: URL(fileURLWithPath: job.outputPath),
                preset: job.preset,
                title: job.encodeTitle,
                episode: job.episode,
                audioTracks: job.audioTracks,
                quality: job.quality
            )

            log("Rip complete, queued encode: \(job.jobLabel)")
            try ripQueueManager.updateStatus(id: job.id, status: .done, completedAt: .now)
            hookRunner.fire(event: "rip_complete", title: "Rip Complete",
                            body: "\(job.jobLabel) added to encode queue")
        } catch {
            log("Rip failed for \(job.jobLabel): \(error)")
            try? ripQueueManager.updateStatus(id: job.id, status: .error,
                                              errorMessage: error.localizedDescription)
            hookRunner.fire(event: "rip_failed", title: "Rip Failed", body: job.jobLabel)
        }
    }

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] \(message)")
        fflush(stdout)
    }
}
