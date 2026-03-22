import Foundation

public protocol HandBrakeRunning: Sendable {
    func encode(
        input: URL,
        output: URL,
        preset: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws
}
