import SwiftUI
import FrostscribeCore

struct ConfirmationView: View {
    let vm: RipFlowViewModel
    let input: RipInput
    let outputURL: URL

    var body: some View {
        VStack(spacing: FrostTheme.paddingL) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(FrostTheme.glacier)
            Text("Ready to Rip")
                .font(.title3)
                .bold()

            VStack(spacing: 0) {
                infoRow(label: "Title", value: input.title)
                if let ep = input.episode {
                    infoRow(label: "Episode", value: ep)
                }
                infoRow(label: "Preset", value: input.preset)
                infoRow(label: "Audio", value: audioSummary)
                Divider().padding(.vertical, FrostTheme.paddingS)
                pathRow
            }
            .padding(FrostTheme.paddingM)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius))
            .padding(.horizontal, FrostTheme.paddingL)

            Button("Start Ripping") {
                vm.confirm(input)
            }
            .buttonStyle(.borderedProminent)
            .tint(FrostTheme.frostCyan)
            .controlSize(.large)

            Spacer()
        }
        .padding(FrostTheme.paddingL)
    }

    private var audioSummary: String {
        if let tracks = input.selectedAudioTracks {
            return "Tracks " + tracks.map(String.init).joined(separator: ", ")
        }
        return "All tracks (default)"
    }

    private var pathRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Output")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(outputURL.path)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(3)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.caption)
                .lineLimit(2)
            Spacer()
        }
        .padding(.vertical, 3)
    }
}
