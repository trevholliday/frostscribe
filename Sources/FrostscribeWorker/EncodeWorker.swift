import Foundation
import FrostscribeCore

actor EncodeWorker {
    private let queueManager: QueueManager
    private var running = false
    private let pollInterval: TimeInterval = 10

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appSupportURL = base.appending(path: "Frostscribe")
        self.queueManager = QueueManager(appSupportURL: appSupportURL)
    }

    func start() async {
        await NotificationService.shared.requestAuthorization()
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
            let preset = job.preset
            let id     = job.id
            let qm     = queueManager

            try FileManager.default.createDirectory(
                at: output.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                DispatchQueue.global().async {
                    do {
                        try HandBrakeRunner().encode(input: input, output: output, preset: preset) { pct in
                            let label = String(format: "%.1f%%", pct)
                            try? qm.updateProgress(id: id, progress: label)
                        }
                        cont.resume()
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }

            log("Encode complete: \(job.label)")
            try queueManager.updateStatus(id: job.id, status: .done, completedAt: .now)

            let rawMKV = URL(fileURLWithPath: job.input)
            try? FileManager.default.removeItem(at: rawMKV)
            try? FileManager.default.removeItem(at: rawMKV.deletingLastPathComponent())

            NotificationService.shared.send(title: "Encode Complete", body: job.label)
        } catch {
            log("Encode failed for \(job.label): \(error)")
            try? queueManager.updateStatus(id: job.id, status: .error)
            NotificationService.shared.send(title: "Encode Failed", body: job.label)
        }
    }

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] \(message)")
        fflush(stdout)
    }
}
