import Foundation

public protocol HandBrakeRunning: Sendable {
    func encode(
        input: URL,
        output: URL,
        preset: String,
        audioTracks: [Int]?,
        quality: Int,
        encoderType: EncoderType,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws
}
