import SwiftUI
import FrostscribeCore

struct TitleSelectionView: View {
    let vm: RipFlowViewModel
    let scanResult: DiscScanResult
    let mediaTitle: String
    let year: String
    let isTV: Bool
    let season: Int
    let episode: Int

    private var displayedTitles: [DiscTitle] {
        guard vm.filterShortTitles else { return scanResult.titles }
        return scanResult.titles.filter { $0.durationMinutes >= 60 }
    }

    private var filteredCount: Int { scanResult.titles.count - displayedTitles.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if vm.canGoBack {
                    Button { vm.goBack() } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                sectionHeader(
                    "SELECT TITLE",
                    subtitle: filteredCount > 0
                        ? "\(displayedTitles.count) titles (\(filteredCount) short filtered)"
                        : "\(scanResult.titles.count) titles found"
                )
            }
            .padding(.horizontal, FrostTheme.paddingM)
            .padding(.vertical, FrostTheme.paddingS)
            Divider()
            List(displayedTitles, id: \.number) { title in
                TitleRow(title: title, isMain: title.isMainTitleCandidate)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.selectTitle(title, scanResult: scanResult,
                                       mediaTitle: mediaTitle, year: year,
                                       isTV: isTV, season: season, episode: episode)
                    }
            }
            .listStyle(.plain)
        }
    }
}

private struct TitleRow: View {
    let title: DiscTitle
    let isMain: Bool

    var body: some View {
        HStack(alignment: .top, spacing: FrostTheme.paddingM) {
            // Left: number + metadata
            VStack(alignment: .leading, spacing: 4) {
                // Number + name
                HStack(spacing: 6) {
                    Text("[\(title.number)]")
                        .font(.caption.monospaced())
                        .foregroundStyle(FrostTheme.glacier)
                    Text(title.name)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(isMain ? .primary : .secondary)
                        .lineLimit(1)
                }

                // Duration + chapters + angle + subtitles
                HStack(spacing: 4) {
                    Text(title.duration)
                    Text("·")
                    Text("\(title.chapters) ch")
                    if let angle = title.angle {
                        Text("·")
                        Text("Angle \(angle)")
                    }
                    if title.subtitleCount > 0 {
                        Text("·")
                        Text("\(title.subtitleCount) sub")
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

                // Audio tracks
                if title.audioTracks.isEmpty {
                    Text("No audio info from scan")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(title.audioTracks.enumerated()), id: \.offset) { _, track in
                            Text(track.summary)
                                .font(.caption2)
                                .foregroundStyle(track.isLossless ? FrostTheme.teal : .secondary)
                        }
                    }
                }
            }

            Spacer()

            // Right: badges + size
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    if isMain {
                        Text("MAIN")
                            .font(.caption2.bold())
                            .foregroundStyle(FrostTheme.teal)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(FrostTheme.teal.opacity(0.15), in: Capsule())
                    }
                    if title.is4K {
                        Text("4K")
                            .font(.caption2.bold())
                            .foregroundStyle(FrostTheme.frostCyan)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(FrostTheme.frostCyan.opacity(0.15), in: Capsule())
                    } else if let res = title.videoResolution {
                        Text(resolutionLabel(res))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                }
                Text(title.sizeFormatted)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isMain ? FrostTheme.teal : .secondary)
            }
        }
        .padding(.vertical, 6)
        .opacity(isMain ? 1.0 : 0.7)
    }

    private func resolutionLabel(_ res: String) -> String {
        guard let heightStr = res.split(separator: "x").last,
              let height = Int(heightStr) else { return res }
        switch height {
        case 2160...: return "4K"
        case 1080:    return "1080p"
        case 720:     return "720p"
        case 480:     return "480p"
        default:      return "\(height)p"
        }
    }
}

private func sectionHeader(_ title: String, subtitle: String) -> some View {
    HStack {
        Spacer()
        Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
