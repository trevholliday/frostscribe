import Foundation

public final class HandBrakeRunner: HandBrakeRunning {
    private let binPath: String

    public init(binPath: String = "HandBrakeCLI") {
        self.binPath = binPath
    }

    public func encode(
        input: URL,
        output: URL,
        preset: String,
        audioTracks: [Int]?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do { try self.encodeSync(input: input, output: output, preset: preset, audioTracks: audioTracks, onProgress: onProgress); cont.resume() }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    private func encodeSync(
        input: URL,
        output: URL,
        preset: String,
        audioTracks: [Int]?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) throws {
        let args = EncoderPreset.arguments(
            input: input.path,
            output: output.path,
            preset: preset,
            audioTracks: audioTracks
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedBinPath())
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            guard let line = String(data: handle.availableData, encoding: .utf8) else { return }
            if let match = line.firstMatch(of: /task (\d+) of (\d+), (\d+\.\d+) %/) {
                let task  = Double(match.1)!
                let total = Double(match.2)!
                let pct   = Double(match.3)!
                let overall = ((task - 1) + pct / 100) / total * 100
                onProgress(overall)
            }
        }

        try process.run()
        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil

        guard process.terminationStatus == 0 else {
            throw FrostscribeError.handbrakeFailed(exitCode: process.terminationStatus)
        }
    }

    private func resolvedBinPath() -> String {
        if binPath.isEmpty { return "HandBrakeCLI" }
        return binPath
    }
}
