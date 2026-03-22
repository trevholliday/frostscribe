import Foundation

public protocol MakeMKVRunning: Sendable {
    func scan(onMessage: @escaping @Sendable (String) -> Void) async throws -> DiscScanResult
    func rip(
        titleNumber: Int,
        to destination: URL,
        onMessage: @escaping @Sendable (String) -> Void,
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws
}

public extension MakeMKVRunning {
    func scan() async throws -> DiscScanResult {
        try await scan(onMessage: { _ in })
    }
}
