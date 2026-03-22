import Foundation
import FrostscribeCore

/// The core encode worker — polls the queue and encodes jobs sequentially.
final class EncodeWorker: @unchecked Sendable {
    private let appSupportURL: URL
    private let queueManager: QueueManager
    private var running = false
    private let pollInterval: TimeInterval = 10

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.appSupportURL = base.appending(path: "Frostscribe")
        self.queueManager = QueueManager(appSupportURL: appSupportURL)
    }

    func start() {
        running = true
        log("Frostscribe worker started (pid \(ProcessInfo.processInfo.processIdentifier))")
        scheduleNextPoll()
    }

    func stop() {
        log("Frostscribe worker shutting down…")
        running = false
        exit(0)
    }

    // MARK: - Private

    private func scheduleNextPoll() {
        guard running else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + pollInterval) { [weak self] in
            self?.poll()
        }
    }

    private func poll() {
        guard running else { return }
        defer { scheduleNextPoll() }

        let jobs: [EncodeJob]
        do {
            jobs = try queueManager.read()
        } catch {
            log("Failed to read queue: \(error)")
            return
        }

        guard let job = jobs.first(where: { $0.status == .pending }) else { return }
        encode(job)
    }

    private func encode(_ job: EncodeJob) {
        log("Starting encode: \(job.label)")
        do {
            try queueManager.updateStatus(id: job.id, status: .encoding)

            let runner = HandBrakeRunner()
            let input  = URL(fileURLWithPath: job.input)
            let output = URL(fileURLWithPath: job.output)

            try runner.encode(input: input, output: output, preset: job.preset) { [weak self] pct in
                let label = String(format: "%.1f%%", pct)
                try? self?.queueManager.updateProgress(id: job.id, progress: label)
            }

            log("Encode complete: \(job.label)")
            try queueManager.updateStatus(id: job.id, status: .done, completedAt: .now)
        } catch {
            log("Encode failed for \(job.label): \(error)")
            try? queueManager.updateStatus(id: job.id, status: .error)
        }
    }

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] \(message)")
        fflush(stdout)
    }
}
