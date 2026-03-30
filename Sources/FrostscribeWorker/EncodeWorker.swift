import Foundation
import FrostscribeCore

actor EncodeWorker {
    private let queueManager: any QueueManaging
    private let handbrakeRunner: any HandBrakeRunning
    private let hookRunner: HookRunner
    private let logStore: LogStore
    private var running = false
    private let pollInterval: TimeInterval = 10

    init(
        queueManager: any QueueManaging,
        handbrakeRunner: any HandBrakeRunning,
        hookRunner: HookRunner,
        logStore: LogStore
    ) {
        self.queueManager = queueManager
        self.handbrakeRunner = handbrakeRunner
        self.hookRunner = hookRunner
        self.logStore = logStore
    }

    func start() async {
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
        // Reset any in-flight job back to pending so the next worker start picks it up.
        if let jobs = try? queueManager.read() {
            for job in jobs where job.status == .encoding {
                log("Resetting interrupted job to pending: \(job.label)")
                try? queueManager.updateStatus(id: job.id, status: .pending)
            }
        }
        exit(0)
    }

    private func poll() async {
        let jobs: [EncodeJob]
        do {
            jobs = try queueManager.read()
        } catch {
            log("Failed to read queue: \(error)", level: "error")
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

            let config   = (try? ConfigManager().load()) ?? Config()
            let discType = DiscType(rawValue: job.discType) ?? .bluray
            let quality  = EncoderPreset.quality(for: discType, config: config)
            try await handbrakeRunner.encode(input: input, output: output, preset: job.preset, audioTracks: job.audioTracks, quality: quality, encoderType: config.encoderType) { pct in
                let label = String(format: "%.1f%%", pct)
                try? qm.updateProgress(id: id, progress: label)
            }

            log("Encode complete: \(job.label)")
            try queueManager.updateStatus(id: job.id, status: .done, completedAt: .now)

            let rawMKV = URL(fileURLWithPath: job.input)
            try? FileManager.default.removeItem(at: rawMKV)
            try? FileManager.default.removeItem(at: rawMKV.deletingLastPathComponent())

            hookRunner.fire(event: "encode_complete", title: "Encode Complete", body: job.label)
        } catch {
            log("Encode failed for \(job.label): \(error)", level: "error")
            try? queueManager.updateStatus(id: job.id, status: .error)
            hookRunner.fire(event: "encode_failed", title: "Encode Failed", body: job.label)
        }
    }

    private func log(_ message: String, level: String = "info") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] \(message)")
        fflush(stdout)
        logStore.append(timestamp: timestamp, message: message, level: level)
    }
}
