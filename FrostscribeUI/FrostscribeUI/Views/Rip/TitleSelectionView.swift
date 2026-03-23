import SwiftUI
import FrostscribeCore

struct TitleSelectionView: View {
    let vm: RipFlowViewModel
    let scanResult: DiscScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("SELECT TITLE", subtitle: "\(scanResult.titles.count) titles found")
            Divider()
            List(scanResult.titles, id: \.number) { title in
                TitleRow(title: title)
                    .contentShape(Rectangle())
                    .onTapGesture { vm.selectTitle(title, from: scanResult) }
            }
            .listStyle(.plain)
        }
    }
}

private struct TitleRow: View {
    let title: DiscTitle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: number, name, badges, size
            HStack(spacing: FrostTheme.spacing) {
                Text("[\(title.number)]")
                    .font(.caption.monospaced())
                    .foregroundStyle(FrostTheme.glacier)
                    .frame(width: 28, alignment: .leading)
                Text(title.name)
                    .bold()
                    .lineLimit(1)
                Spacer()
                badges
                Text(title.sizeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Row 2: duration, chapters, subtitles, audio summary
            HStack(spacing: FrostTheme.spacing) {
                Text(title.duration)
                Text("·")
                Text("\(title.chapters) ch")
                if title.subtitleCount > 0 {
                    Text("·")
                    Text("\(title.subtitleCount) sub")
                }
                Spacer()
                audioSummary(title.audioTracks)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var badges: some View {
        if title.isMainTitleCandidate {
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

    private func resolutionLabel(_ res: String) -> String {
        // "1920x1080" → "1080p", "1280x720" → "720p"
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

    @ViewBuilder
    private func audioSummary(_ tracks: [AudioTrack]) -> some View {
        if tracks.isEmpty {
            Text("No audio").font(.caption).foregroundStyle(.secondary)
        } else {
            HStack(spacing: 4) {
                ForEach(Array(tracks.prefix(3).enumerated()), id: \.offset) { _, track in
                    Text(trackLabel(track))
                        .font(.caption2)
                        .foregroundStyle(track.isLossless ? FrostTheme.teal : .secondary)
                }
                if tracks.count > 3 {
                    Text("+\(tracks.count - 3)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func trackLabel(_ track: AudioTrack) -> String {
        var parts = [track.codec]
        if let ch = track.channels { parts.append(ch) }
        return parts.joined(separator: " ")
    }
}

private func sectionHeader(_ title: String, subtitle: String) -> some View {
    HStack {
        Text(title)
            .font(.caption)
            .bold()
            .foregroundStyle(.secondary)
        Spacer()
        Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal, FrostTheme.paddingM)
    .padding(.vertical, FrostTheme.paddingS)
}
