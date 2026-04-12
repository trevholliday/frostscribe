import Foundation

// MARK: - Protocol

/// Selects the most likely main-feature title from a set.
/// The heuristic implementation works out of the box; a trained CoreML
/// model can be dropped in by conforming to this protocol.
public protocol TitleSuggesting: Sendable {
    func suggest(from titles: [DiscTitle]) -> DiscTitle?
}

// MARK: - Heuristic implementation

/// Weighted scoring across signals MakeMKV exposes.
/// Designed to mirror human selection behaviour until enough training data
/// exists to replace it with a CoreML tabular classifier.
public struct HeuristicTitleSuggester: TitleSuggesting {

    public init() {}

    public func suggest(from titles: [DiscTitle]) -> DiscTitle? {
        guard !titles.isEmpty else { return nil }
        // When scores are tied, prefer the lower title number — MakeMKV lists
        // the primary playlist first; honeypot duplicates tend to appear later.
        return titles.max {
            let sa = score($0, in: titles), sb = score($1, in: titles)
            if sa != sb { return sa < sb }
            return $0.number > $1.number  // higher number loses the tie
        }
    }

    // MARK: - Scoring

    func score(_ title: DiscTitle, in all: [DiscTitle]) -> Double {
        var s = 0.0

        let maxDuration = all.map(\.durationMinutes).max().map(Double.init) ?? 1
        let maxSize     = all.map(\.sizeBytes).max().map(Double.init) ?? 1

        // MakeMKV's own primary-title flag — strongest individual signal
        if title.orderWeight == 0 { s += 40 }
        // Secondary order weighting (lower = closer to main)
        s += max(0, 10 - Double(title.orderWeight)) * 0.5

        // Duration ratio — feature-length titles are clearly longer
        let durRatio = maxDuration > 0 ? Double(title.durationMinutes) / maxDuration : 0
        s += durRatio * 30

        // Size ratio — more data usually means better encode of main feature
        let sizeRatio = maxSize > 0 ? Double(title.sizeBytes) / maxSize : 0
        s += sizeRatio * 15

        // Lossless audio (TrueHD / DTS-HD MA) → premium disc track
        if title.audioTracks.contains(where: \.isLossless) { s += 5 }

        // Resolution bonus
        if title.is4K       { s += 4 }
        else if (title.videoResolution ?? "").contains("1080") { s += 2 }

        // Penalise angle variants (extras/special features often have angle > 0)
        if let angle = title.angle, angle > 1 { s -= 8 }

        // Audio track count — multilingual main features ship with many tracks;
        // commentary/special-edition variants typically have 2 or fewer.
        s += min(Double(title.audioTracks.count), 8) * 1.5

        // Penalise very short titles regardless of other signals
        if title.durationMinutes < 30 { s -= 20 }

        return s
    }
}
