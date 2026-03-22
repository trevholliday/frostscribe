import Foundation
import FrostscribeCore

actor EncodeWorker {
    private let queueManager: any QueueManaging
    private let handbrakeRunner: any HandBrakeRunning
    private let notificationService: any NotificationServing
    private var running = false
    private let pollInterval: TimeInterval = 10

    init(
        queueManager: any QueueManaging,
        handbrakeRunner: any HandBrakeRunning,
        notificationService: any NotificationServing
    ) {
        self.queueManager = queueManager
        self.handbrakeRunner = handbrakeRunner
        self.notificationService = notificationService
    }

    func start() async {
        await notificationService.requestAuthorizationIfNeeded()
        running = true
        log("Frostscribe worker started (pid \(ProcessInfo.processInfo.processIdentifier))")
        while running {
            await poll()
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }

    func stop() {
        log("Frostscribe worker shutting down…")
        running = false
        exit(0)
    }

    private func poll() async {
        let jobs: [EncodeJob]
        do {
            jobs = try queueManager.read()
        } catch {
            log("Failed to read queue: \(error)")
            return
        }

        guard let job = jobs.first(where: { $0.status == .pending }) else { return }
        await encode(job)
    }

    private func encode(_ job: EncodeJob) async {
        log("Starting encode: \(job.label)")
        do {
            try queueManager.updateStatus(id: job.id, status: .encoding)

            let input  = URL(fileURLWithPath: job.input)
            let output = URL(fileURLWithPath: job.output)
            let id     = job.id
            let qm     = queueManager

            try FileManager.default.createDirectory(
                at: output.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            try await handbrakeRunner.encode(input: input, output: output, preset: job.preset) { pct in
                let label = String(format: "%.1f%%", pct)
                try? qm.updateProgress(id: id, progress: label)
            }

            log("Encode complete: \(job.label)")
            try queueManager.updateStatus(id: job.id, status: .done, completedAt: .now)

            let rawMKV = URL(fileURLWithPath: job.input)
            try? FileManager.default.removeItem(at: rawMKV)
            try? FileManager.default.removeItem(at: rawMKV.deletingLastPathComponent())

            notificationService.send(title: "Encode Complete", body: job.label)
        } catch {
            log("Encode failed for \(job.label): \(error)")
            try? queueManager.updateStatus(id: job.id, status: .error)
            notificationService.send(title: "Encode Failed", body: job.label)
        }
    }

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] \(message)")
        fflush(stdout)
    }
}
