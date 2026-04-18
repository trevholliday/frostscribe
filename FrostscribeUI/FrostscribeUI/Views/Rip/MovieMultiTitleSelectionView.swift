import SwiftUI
import FrostscribeCore

struct MovieMultiTitleSelectionView: View {
    let vm: RipFlowViewModel
    let scanResult: DiscScanResult
    let title: String
    let year: String

    @State private var selected: Set<Int> = []

    private var displayedTitles: [DiscTitle] {
        guard vm.filterMovieTitles else { return scanResult.titles }
        let filtered = scanResult.titles.filter { $0.durationMinutes >= 60 }
        return filtered.isEmpty ? scanResult.titles : filtered
    }

    private var filteredCount: Int { scanResult.titles.count - displayedTitles.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                if vm.canGoBack {
                    Button { vm.goBack() } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(filteredCount > 0
                    ? "\(displayedTitles.count) titles (\(filteredCount) short filtered)"
                    : "\(scanResult.titles.count) titles found"
                )
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                Spacer()
                Button("Abort Rip", role: .destructive) { vm.reset() }
                    .buttonStyle(.frostDestructive)
            }
            .padding(.horizontal, FrostTheme.paddingM)
            .padding(.vertical, FrostTheme.paddingS)

            Divider()

            List(displayedTitles, id: \.number) { t in
                MovieTitleRow(
                    title: t,
                    isSelected: selected.contains(t.number),
                    isSuggested: t.number == vm.suggestedTitleNumber
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if selected.contains(t.number) { selected.remove(t.number) }
                    else                           { selected.insert(t.number) }
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

                if selected.count == 1,
                   let titleNum = selected.first,
                   let discTitle = displayedTitles.first(where: { $0.number == titleNum }) {
                    Button("Select Title") {
                        vm.selectTitle(discTitle, scanResult: scanResult,
                                       mediaTitle: title, year: year,
                                       isTV: false, season: 1, episode: 1)
                    }
                    .buttonStyle(.frostPrimary)
                } else {
                    Button(selected.isEmpty
                           ? "Select Titles"
                           : "Queue \(selected.count) Titles") {
                        let ordered = displayedTitles.filter { selected.contains($0.number) }
                        vm.confirmMultipleMovies(
                            selectedTitles: ordered,
                            scanResult: scanResult,
                            title: title, year: year
                        )
                    }
                    .buttonStyle(.frostPrimary)
                    .disabled(selected.isEmpty)
                }
            }
            .padding(FrostTheme.paddingM)
        }
        .onAppear {
            if let suggested = vm.suggestedTitleNumber,
               displayedTitles.contains(where: { $0.number == suggested }) {
                selected = [suggested]
            } else if let first = displayedTitles.first(where: { $0.isMainTitleCandidate }) {
                selected = [first.number]
            } else {
                selected = displayedTitles.first.map { [$0.number] } ?? []
            }
        }
    }

}

// MARK: - Row

private struct MovieTitleRow: View {
    let title: DiscTitle
    let isSelected: Bool
    let isSuggested: Bool

    @State private var showDetail = false

    var body: some View {
        HStack(alignment: .center, spacing: FrostTheme.paddingM) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? FrostTheme.teal : Color.secondary)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                    if isSuggested {
                        badge("SUGGESTED", color: .purple)
                    }
                    if title.isMainTitleCandidate {
                        badge("MAIN", color: FrostTheme.teal)
                    }
                    if title.is4K {
                        badge("4K", color: FrostTheme.frostCyan)
                    } else if let res = title.videoResolution {
                        badge(resLabel(res), color: .secondary)
                    }
                }

                HStack(spacing: 4) {
                    Text(title.duration)
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(title.chapters) ch")
                    Text("·").foregroundStyle(.tertiary)
                    Text(title.sizeFormatted)
                        .foregroundStyle(isSelected ? FrostTheme.teal : Color.secondary)
                }
                .font(.system(size: 14).monospacedDigit())
                .foregroundStyle(.secondary)

                if !title.audioTracks.isEmpty {
                    let first = title.audioTracks[0]
                    let rest  = title.audioTracks.count - 1
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

            // Info button
            Button {
                showDetail = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(FrostTheme.glacier.opacity(0.7))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDetail, arrowEdge: .trailing) {
                TitleDetailPopover(title: title)
            }
        }
        .padding(.vertical, 5)
        .opacity(isSelected ? 1.0 : 0.7)
    }

    private func badge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func resLabel(_ res: String) -> String {
        guard let h = res.split(separator: "x").last.flatMap({ Int($0) }) else { return res }
        switch h {
        case 2160...: return "4K"
        case 1080:    return "1080p"
        case 720:     return "720p"
        case 480:     return "480p"
        default:      return "\(h)p"
        }
    }
}
