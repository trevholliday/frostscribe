import SwiftUI
import FrostscribeCore

struct ConfirmationView: View {
    let vm: RipFlowViewModel
    let ripInput: RipInput
    let encodeInput: EncodeInput

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
                infoRow(label: "Title", value: encodeInput.title)
                if let ep = encodeInput.episode {
                    infoRow(label: "Episode", value: ep)
                }
                infoRow(label: "Preset", value: encodeInput.preset)
                infoRow(label: "Audio", value: audioSummary)
                if let estimate = vm.ripEstimate {
                    infoRow(label: "Est. Time", value: estimate.formattedMinutes + estimateQualifier(estimate))
                }
                Divider().padding(.vertical, FrostTheme.paddingS)
                pathRow
            }
            .padding(FrostTheme.paddingM)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius))
            .padding(.horizontal, FrostTheme.paddingL)

            Button("Start Ripping") {
                vm.confirm(ripInput, encodeInput)
            }
            .buttonStyle(.frostPrimary)

            Spacer()
        }
        .padding(FrostTheme.paddingL)
    }

    private func estimateQualifier(_ estimate: RipEstimate) -> String {
        if case .measured(let n) = estimate.confidence { return " (\(n) rips)" }
        return " (est.)"
    }

    private var audioSummary: String {
        if let tracks = encodeInput.selectedAudioTracks {
            return "Tracks " + tracks.map(String.init).joined(separator: ", ")
        }
        return "All tracks (default)"
    }

    private var pathRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Output")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(encodeInput.outputURL.path)
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
