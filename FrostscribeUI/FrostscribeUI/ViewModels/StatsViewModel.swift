import Foundation
import FrostscribeCore

@MainActor
@Observable
final class StatsViewModel {

    struct DiscBreakdown {
        let bluray: Int
        let dvd: Int
        let uhd: Int
    }

    private(set) var totalRips: Int = 0
    private(set) var dataRippedGB: Double = 0
    private(set) var avgRipMinutes: Double = 0
    private(set) var fastestLabel: String = "—"
    private(set) var fastestMinutes: Double = 0
    private(set) var breakdown: DiscBreakdown = DiscBreakdown(bluray: 0, dvd: 0, uhd: 0)
    private(set) var successRate: Double = 0
    private(set) var totalAttempts: Int = 0

    // Encode stats
    private(set) var totalEncodes: Int = 0
    private(set) var encodeErrors: Int = 0
    private(set) var encodeSuccessRate: Double = 0

    // ML / selection stats
    private(set) var selectionEvents: Int = 0
    private(set) var titlesRecorded: Int = 0
    private(set) var suggestionAccuracy: Double = 0
    private(set) var suggestionMatchCount: Int = 0

    func load() {
        let store = RipHistoryStore(appSupportURL: ConfigManager.appSupportURL)
        let all = store.load()
        guard !all.isEmpty else { return }

        let successful = all.filter(\.success)
        totalAttempts = all.count
        totalRips = successful.count
        successRate = Double(totalRips) / Double(totalAttempts) * 100

        let totalBytes = successful.reduce(0) { $0 + $1.titleSizeBytes }
        dataRippedGB = Double(totalBytes) / 1_073_741_824

        if !successful.isEmpty {
            let totalSec = successful.reduce(0.0) { $0 + $1.ripDurationSeconds }
            avgRipMinutes = totalSec / Double(successful.count) / 60.0
        }

        if let fastest = successful.min(by: { $0.ripDurationSeconds < $1.ripDurationSeconds }) {
            fastestLabel = fastest.jobLabel
            fastestMinutes = fastest.ripDurationSeconds / 60.0
        }

        breakdown = DiscBreakdown(
            bluray: successful.filter { $0.discType == .bluray }.count,
            dvd:    successful.filter { $0.discType == .dvd }.count,
            uhd:    successful.filter { $0.discType == .uhd }.count
        )

        // Encode stats from queue
        let allEncodes = (try? QueueManager(appSupportURL: ConfigManager.appSupportURL).read()) ?? []
        let terminal = allEncodes.filter { $0.status == .done || $0.status == .error }
        totalEncodes = terminal.count
        encodeErrors = terminal.filter { $0.status == .error }.count
        encodeSuccessRate = totalEncodes > 0
            ? Double(totalEncodes - encodeErrors) / Double(totalEncodes) * 100 : 0

        loadSelectionStats()
    }

    private func loadSelectionStats() {
        let selStore = TitleSelectionStore(appSupportURL: ConfigManager.appSupportURL)
        let records = selStore.load()
        guard !records.isEmpty else { return }

        titlesRecorded = records.count

        // Group by selectionId
        let groups = Dictionary(grouping: records, by: \.selectionId)
        selectionEvents = groups.count

        // Accuracy: for each group, does the heuristic top-scorer match the user's pick?
        var matches = 0
        for (_, rows) in groups {
            guard let selected = rows.first(where: \.isSelected) else { continue }
            let best = rows.max { heuristicScore($0) < heuristicScore($1) }
            if best?.titleNumber == selected.titleNumber { matches += 1 }
        }
        suggestionMatchCount = matches
        suggestionAccuracy = selectionEvents > 0
            ? Double(matches) / Double(selectionEvents) * 100 : 0
    }

    /// Mirrors HeuristicTitleSuggester using stored scalar fields.
    private func heuristicScore(_ r: TitleSelectionRecord) -> Double {
        var s = 0.0
        let group = r.selectionId  // unused but kept for clarity

        // Use rank-based proxies since we don't have the full sibling set here
        if r.orderWeight == 0   { s += 40 }
        s += max(0, 10 - Double(r.orderWeight)) * 0.5
        if r.durationRank == 1  { s += 30 }
        else if r.durationRank == 2 { s += 18 }
        if r.sizeRank == 1      { s += 15 }
        else if r.sizeRank == 2 { s += 9 }
        if r.hasLosslessAudio   { s += 5 }
        if r.videoHeight >= 2160 { s += 4 }
        else if r.videoHeight >= 1080 { s += 2 }
        if r.angle > 1          { s -= 8 }
        if r.durationMinutes < 30 { s -= 20 }
        return s
    }
}
