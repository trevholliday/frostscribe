import SwiftUI
import FrostscribeCore

struct TVMultiEpisodeSelectionView: View {
    let vm: RipFlowViewModel
    let scanResult: DiscScanResult
    let title: String
    let year: String

    @State private var season: Int
    @State private var startEpisode: Int
    @State private var selected: Set<Int> = []

    init(vm: RipFlowViewModel, scanResult: DiscScanResult, title: String, year: String,
         season: Int, startEpisode: Int) {
        self.vm = vm
        self.scanResult = scanResult
        self.title = title
        self.year = year
        self._season = State(initialValue: season)
        self._startEpisode = State(initialValue: startEpisode)
    }

    /// Titles long enough to be real episodes (excludes disc menus, trailers).
    private var displayedTitles: [DiscTitle] {
        scanResult.titles.filter { $0.durationMinutes >= 3 }
    }

    /// Maps each selected title.number → its assigned episode number,
    /// incrementing from startEpisode in disc order.
    private var episodeAssignments: [Int: Int] {
        var map: [Int: Int] = [:]
        var ep = startEpisode
        for t in displayedTitles where selected.contains(t.number) {
            map[t.number] = ep
            ep += 1
        }
        return map
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: FrostTheme.paddingM) {
                if vm.canGoBack {
                    Button { vm.goBack() } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Stepper("S\(String(format: "%02d", season))", value: $season, in: 1...99)
                    .fixedSize()
                    .font(.system(size: 15, design: .monospaced))

                Stepper("from E\(String(format: "%02d", startEpisode))", value: $startEpisode, in: 1...999)
                    .fixedSize()
                    .font(.system(size: 15, design: .monospaced))

                Spacer()

                Text("\(selected.count) episode\(selected.count == 1 ? "" : "s") selected")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                Button("Abort Rip", role: .destructive) { vm.reset() }
                    .buttonStyle(.frostDestructive)
            }
            .padding(.horizontal, FrostTheme.paddingM)
            .padding(.vertical, FrostTheme.paddingS)

            Divider()

            List(displayedTitles, id: \.number) { t in
                let isSelected = selected.contains(t.number)
                let ep = episodeAssignments[t.number]

                HStack(alignment: .center, spacing: FrostTheme.paddingM) {
                    // Checkbox
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? FrostTheme.teal : Color.secondary)

                    // Episode badge
                    Group {
                        if let ep {
                            Text(String(format: "E%02d", ep))
                                .foregroundStyle(FrostTheme.teal)
                        } else {
                            Text("—")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .frame(width: 36, alignment: .leading)

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Text(t.duration)
                            separator
                            Text("\(t.chapters) ch")
                            separator
                            Text(t.sizeFormatted)
                                .foregroundStyle(isSelected ? FrostTheme.teal : Color.secondary)
                        }
                        .font(.system(size: 14).monospacedDigit())
                        .foregroundStyle(.secondary)

                        if !t.audioTracks.isEmpty {
                            let first = t.audioTracks[0]
                            let rest  = t.audioTracks.count - 1
                            HStack(spacing: 4) {
                                Text(first.summary)
                                    .foregroundStyle(first.isLossless ? FrostTheme.teal : Color.secondary)
                                if rest > 0 {
                                    Text("+ \(rest) more").foregroundStyle(.tertiary)
                                }
                            }
                            .font(.system(size: 13))
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 5)
                .opacity(isSelected ? 1.0 : 0.6)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelected { selected.remove(t.number) }
                    else          { selected.insert(t.number) }
                }
            }
            .listStyle(.plain)

            Divider()

            // Footer
            HStack {
                Button(selected.count == displayedTitles.count ? "Deselect All" : "Select All") {
                    if selected.count == displayedTitles.count {
                        selected = []
                    } else {
                        selected = Set(displayedTitles.map(\.number))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 15))

                Spacer()

                Button(selected.isEmpty
                       ? "Select Episodes"
                       : "Queue \(selected.count) Episode\(selected.count == 1 ? "" : "s")") {
                    let ordered = displayedTitles.filter { selected.contains($0.number) }
                    vm.confirmMultipleEpisodes(
                        selectedTitles: ordered,
                        episodeAssignments: episodeAssignments,
                        scanResult: scanResult,
                        title: title, year: year, season: season
                    )
                }
                .buttonStyle(.frostPrimary)
                .disabled(selected.isEmpty)
            }
            .padding(FrostTheme.paddingM)
        }
        .onAppear {
            selected = Set(displayedTitles.map(\.number))
        }
    }

    private var separator: some View {
        Text("·").foregroundStyle(.tertiary)
    }
}
