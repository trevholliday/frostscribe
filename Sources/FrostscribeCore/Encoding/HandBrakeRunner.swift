import Foundation

public final class HandBrakeRunner: HandBrakeRunning, @unchecked Sendable {
    private let binPath: String
    private let processLock = NSLock()
    private var _activeProcess: Process?
    private var activeProcess: Process? {
        get { processLock.withLock { _activeProcess } }
        set { processLock.withLock { _activeProcess = newValue } }
    }

    public init(binPath: String = "HandBrakeCLI") {
        self.binPath = binPath
    }

    public func encode(
        input: URL,
        output: URL,
        preset: String,
        audioTracks: [Int]?,
        quality: Int,
        encoderType: EncoderType,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                DispatchQueue.global(qos: .userInitiated).async {
                    do { try self.encodeSync(input: input, output: output, preset: preset, audioTracks: audioTracks, quality: quality, encoderType: encoderType, onProgress: onProgress); cont.resume() }
                    catch { cont.resume(throwing: error) }
                }
            }
        } onCancel: {
            self.activeProcess?.terminate()
        }
    }

    private func encodeSync(
        input: URL,
        output: URL,
        preset: String,
        audioTracks: [Int]?,
        quality: Int,
        encoderType: EncoderType,
        onProgress: @escaping @Sendable (Double) -> Void
    ) throws {
        let args = EncoderPreset.arguments(
            input: input.path,
            output: output.path,
            preset: preset,
            audioTracks: audioTracks,
            quality: quality,
            encoderType: encoderType
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedBinPath())
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                // EOF — stop the handler to avoid a spin on pipe close
                handle.readabilityHandler = nil
                return
            }
            guard let line = String(data: data, encoding: .utf8) else { return }
            if let match = line.firstMatch(of: /task (\d+) of (\d+), (\d+\.\d+) %/) {
                let task  = Double(match.1)!
                let total = Double(match.2)!
                let pct   = Double(match.3)!
                let overall = ((task - 1) + pct / 100) / total * 100
                onProgress(overall)
            }
        }

        activeProcess = process
        try process.run()
        process.waitUntilExit()
        activeProcess = nil
        pipe.fileHandleForReading.readabilityHandler = nil

        guard process.terminationStatus == 0 else {
            if process.terminationReason == .uncaughtSignal { throw CancellationError() }
            throw FrostscribeError.handbrakeFailed(exitCode: process.terminationStatus)
        }
    }

    private func resolvedBinPath() -> String {
        if binPath.isEmpty { return "HandBrakeCLI" }
        return binPath
    }
}
