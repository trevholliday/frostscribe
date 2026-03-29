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
            List(displayedTitles, id: \.number) { title in
                TitleRow(
                    title: title,
                    isMain: title.isMainTitleCandidate,
                    isSuggested: title.number == vm.suggestedTitleNumber
                )
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

// MARK: - Row

private struct TitleRow: View {
    let title: DiscTitle
    let isMain: Bool
    let isSuggested: Bool

    @State private var showDetail = false

    var body: some View {
        HStack(alignment: .center, spacing: FrostTheme.paddingM) {
            // Index
            Text("[\(title.number)]")
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(FrostTheme.glacier)
                .frame(width: 35, alignment: .leading)

            // Main content
            VStack(alignment: .leading, spacing: 5) {
                // Title name + badges
                HStack(spacing: 6) {
                    Text(title.name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(isMain ? .primary : .secondary)
                        .lineLimit(1)
                    badgeRow
                }

                // Duration · chapters · size
                HStack(spacing: 4) {
                    Text(title.duration)
                    separator
                    Text("\(title.chapters) ch")
                    if let angle = title.angle {
                        separator
                        Label("Angle \(angle)", systemImage: "angle")
                            .labelStyle(.titleOnly)
                    }
                    if title.subtitleCount > 0 {
                        separator
                        Text("\(title.subtitleCount) sub\(title.subtitleCount == 1 ? "" : "s")")
                    }
                    separator
                    Text(title.sizeFormatted)
                        .foregroundStyle(isMain ? FrostTheme.teal : .secondary)
                }
                .font(.system(size: 15).monospacedDigit())
                .foregroundStyle(.secondary)

                // Audio summary
                audioSummary
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
        .padding(.vertical, 6)
        .opacity(isMain ? 1.0 : 0.75)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var badgeRow: some View {
        if isSuggested {
            badge("SUGGESTED", color: .purple)
        }
        if isMain {
            badge("MAIN", color: FrostTheme.teal)
        }
        if title.is4K {
            badge("4K", color: FrostTheme.frostCyan)
        } else if let res = title.videoResolution {
            badge(resLabel(res), color: .secondary)
        }
    }

    @ViewBuilder
    private var audioSummary: some View {
        if title.audioTracks.isEmpty {
            Text("No audio info")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
        } else {
            let first = title.audioTracks[0]
            let rest  = title.audioTracks.count - 1
            HStack(spacing: 4) {
                Text(first.summary)
                    .foregroundStyle(first.isLossless ? FrostTheme.teal : .secondary)
                if rest > 0 {
                    Text("+ \(rest) more")
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.system(size: 14))
        }
    }

    private var separator: some View {
        Text("·").foregroundStyle(.tertiary)
    }

    private func badge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .bold))
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

// MARK: - Detail popover

private struct TitleDetailPopover: View {
    let title: DiscTitle

    var body: some View {
        VStack(alignment: .leading, spacing: FrostTheme.paddingM) {
            // Header
            HStack(spacing: 6) {
                Text("[\(title.number)]")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(FrostTheme.glacier)
                Text(title.name)
                    .font(.system(size: 21, weight: .semibold))
                    .lineLimit(2)
            }

            Divider()

            // Specs grid
            Grid(alignment: .leading, horizontalSpacing: FrostTheme.paddingL, verticalSpacing: 6) {
                specRow("Duration",   title.duration)
                specRow("Chapters",   title.chapters)
                specRow("Size",       title.sizeFormatted)
                if let res = title.videoResolution {
                    specRow("Resolution", res)
                }
                if let angle = title.angle {
                    specRow("Angle", "\(angle)")
                }
                specRow("Subtitles",  "\(title.subtitleCount)")
            }

            // Audio tracks
            if !title.audioTracks.isEmpty {
                Divider()
                Text("AUDIO TRACKS")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(title.audioTracks.enumerated()), id: \.offset) { i, track in
                        HStack(spacing: 8) {
                            Text("\(i + 1)")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(width: 18, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(track.language.isEmpty ? "Unknown" : track.language)
                                    .font(.system(size: 19))
                                HStack(spacing: 4) {
                                    Text(track.codec)
                                        .font(.system(size: 15, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    if let ch = track.channels {
                                        Text("·")
                                            .foregroundStyle(.tertiary)
                                        Text(ch)
                                            .font(.system(size: 15, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    if track.isLossless {
                                        Text("LOSSLESS")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(FrostTheme.teal)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(FrostTheme.teal.opacity(0.15), in: Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(FrostTheme.paddingM)
        .frame(width: 360)
        .background(FrostTheme.background)
        .foregroundStyle(FrostTheme.textPrimary)
        .colorScheme(.dark)
    }

    private func specRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, design: .monospaced))
        }
    }
}

// MARK: - Helpers

private func sectionHeader(_ title: String, subtitle: String) -> some View {
    HStack {
        Spacer()
        Text(subtitle)
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
    }
}
