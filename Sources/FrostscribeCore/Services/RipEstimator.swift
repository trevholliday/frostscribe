import Foundation

public struct RipEstimate: Sendable {
    public enum Confidence: Sendable {
        case measured(sampleCount: Int)
        case fallback
    }
    public let seconds: Double
    public let confidence: Confidence

    public var formattedMinutes: String {
        let mins = Int(seconds / 60)
        return mins < 1 ? "<1 min" : "~\(mins) min"
    }
}

public struct RipEstimator: Sendable {
    // Empirical fallback rip rates in bytes/second
    private static let fallbackRates: [DiscType: Double] = [
        .dvd:     9 * 1024 * 1024,   // ~9 MB/s
        .bluray:  18 * 1024 * 1024,  // ~18 MB/s
        .uhd:     30 * 1024 * 1024,  // ~30 MB/s
        .unknown: 9 * 1024 * 1024,
    ]

    private let store: RipHistoryStore

    public init(store: RipHistoryStore) {
        self.store = store
    }

    public func estimate(discType: DiscType, sizeBytes: Int) -> RipEstimate {
        let similar = store.records(for: discType, near: sizeBytes)
        guard similar.count >= 2 else {
            let rate = Self.fallbackRates[discType] ?? Self.fallbackRates[.dvd]!
            return RipEstimate(seconds: Double(sizeBytes) / rate, confidence: .fallback)
        }
        let avgRate = similar
            .map { Double($0.titleSizeBytes) / $0.ripDurationSeconds }
            .reduce(0, +) / Double(similar.count)
        return RipEstimate(
            seconds: Double(sizeBytes) / avgRate,
            confidence: .measured(sampleCount: similar.count)
        )
    }
}
