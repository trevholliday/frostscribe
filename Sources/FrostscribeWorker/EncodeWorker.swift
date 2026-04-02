import Foundation
import FrostscribeCore

// Only writes progress to queue.json when the percentage moves by ≥ 0.5 points.
// The readabilityHandler fires very frequently; throttling avoids hammering the file.
private final class ProgressThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private var last: Double = -1

    func shouldUpdate(_ pct: Double) -> Bool {
        lock.withLock {
            guard pct - last >= 0.5 else { return false }
            last = pct
            return true
        }
    }
}

actor EncodeWorker {
    private let queueManager: any QueueManaging
    private let handbrakeRunner: any HandBrakeRunning
    private let hookRunner: HookRunner
    private let logStore: LogStore
    private var running = false
    private let pollInterval: TimeInterval = 10
    private let dateFormatter: ISO8601DateFormatter = ISO8601DateFormatter()

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

            let config      = (try? ConfigManager().load()) ?? Config()
            let discType    = DiscType(rawValue: job.discType) ?? .bluray
            let quality     = EncoderPreset.quality(for: discType, config: config)
            let encoderType = config.encoderType(for: discType)
            // Throttle progress writes: only update queue.json when progress changes by ≥0.5%
            // to avoid hammering the file on every HandBrake output line.
            let throttle = ProgressThrottle()
            try await handbrakeRunner.encode(input: input, output: output, preset: job.preset, audioTracks: job.audioTracks, quality: quality, encoderType: encoderType) { [qm] pct in
                guard throttle.shouldUpdate(pct) else { return }
                try? qm.updateProgress(id: id, progress: String(format: "%.1f%%", pct))
            }

            log("Encode complete: \(job.label)")
            try queueManager.updateStatus(id: job.id, status: .done, completedAt: .now)

            let rawMKV = URL(fileURLWithPath: job.input)
            try? FileManager.default.removeItem(at: rawMKV)
            try? FileManager.default.removeItem(at: rawMKV.deletingLastPathComponent())

            hookRunner.fire(event: "encode_complete", title: "Encode Complete", body: job.label)
        } catch {
            let nsErr = error as NSError
            if nsErr.domain == NSCocoaErrorDomain && nsErr.code == 513 {
                log("NAS write permission denied for \(job.label) — stopping worker. Check NAS access and restart.", level: "error")
                hookRunner.fire(event: "nas_permission_error", title: "NAS Permission Error", body: "Worker stopped — check NAS write access.")
                stop()
                return
            }
            log("Encode failed for \(job.label): \(error)", level: "error")
            try? queueManager.updateStatus(id: job.id, status: .error)
            hookRunner.fire(event: "encode_failed", title: "Encode Failed", body: job.label)
        }
    }

    private func log(_ message: String, level: String = "info") {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] \(message)")
        fflush(stdout)
        logStore.append(timestamp: timestamp, message: message, level: level)
    }
}
