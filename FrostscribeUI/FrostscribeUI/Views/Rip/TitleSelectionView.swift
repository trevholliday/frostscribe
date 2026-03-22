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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: FrostTheme.spacing) {
                Text("[\(title.number)]")
                    .font(.caption.monospaced())
                    .foregroundStyle(FrostTheme.glacier)
                    .frame(width: 28, alignment: .leading)
                Text(title.name)
                    .bold()
                    .lineLimit(1)
                Spacer()
                Text(title.sizeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: FrostTheme.spacing) {
                Text(title.duration)
                Text("·")
                Text("\(title.chapters)ch")
                Spacer()
                audioSummary(title.audioTracks)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func audioSummary(_ tracks: [AudioTrack]) -> some View {
        if tracks.isEmpty {
            Text("No audio").font(.caption).foregroundStyle(.secondary)
        } else {
            HStack(spacing: 4) {
                ForEach(Array(tracks.prefix(3).enumerated()), id: \.offset) { _, track in
                    Text("\(track.language) (\(track.codec))")
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
