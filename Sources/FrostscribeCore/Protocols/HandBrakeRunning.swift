import Foundation

public protocol HandBrakeRunning: Sendable {
    func encode(
        input: URL,
        output: URL,
        preset: String,
        audioTracks: [Int]?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws
}

public extension HandBrakeRunning {
    func encode(input: URL, output: URL, preset: String, onProgress: @escaping @Sendable (Double) -> Void) async throws {
        try await encode(input: input, output: output, preset: preset, audioTracks: nil, onProgress: onProgress)
    }
}
