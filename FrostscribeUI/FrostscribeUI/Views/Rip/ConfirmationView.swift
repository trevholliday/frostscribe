import SwiftUI
import FrostscribeCore

struct ConfirmationView: View {
    let vm: RipFlowCoordinator
    let ripInput: RipInput
    let encodeInput: EncodeInput

    var body: some View {
        VStack(spacing: FrostTheme.paddingL) {
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
                Button("Abort Rip", role: .destructive) { vm.reset() }
                    .buttonStyle(.frostDestructive)
            }
            .padding(.horizontal, FrostTheme.paddingL)
            .padding(.top, FrostTheme.paddingM)
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 50))
                .foregroundStyle(FrostTheme.glacier)
            Text("Ready to Rip")
                .font(.system(size: 25, weight: .bold))

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
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Text(encodeInput.outputURL.path)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 15))
                .lineLimit(2)
            Spacer()
        }
        .padding(.vertical, 3)
    }
}
