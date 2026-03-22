import SwiftUI
import FrostscribeCore

struct RipFlowView: View {
    @State private var vm = RipFlowViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                LeftPanelView(vm: vm)
                    .frame(width: 200)
                Divider()
                rightContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            progressBar
        }
        .frame(width: 640, height: 460)
        .toolbar {
            if vm.canCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { vm.reset() }
                }
            }
        }
    }

    // MARK: - Right panel

    @ViewBuilder
    private var rightContent: some View {
        switch vm.phase {
        case .idle:
            RipIdleView(vm: vm)
        case .scanning:
            RipScanningView()
        case .titleSelection(let scanResult):
            TitleSelectionView(vm: vm, scanResult: scanResult)
        case .mediaType(let title, let scanResult):
            MediaTypeView(vm: vm, chosenTitle: title, scanResult: scanResult)
        case .tmdbSearch(let title, let scanResult, let isTV):
            TMDBSearchView(vm: vm, chosenTitle: title, scanResult: scanResult, isTV: isTV)
        case .tvEpisode(let title, let scanResult, let mediaTitle, let year):
            TVEpisodeView(vm: vm, chosenTitle: title, scanResult: scanResult,
                          title: mediaTitle, year: year)
        case .audioTrackSelection(let title, let scanResult, let mediaTitle,
                                  let year, let isTV, let season, let episode):
            AudioTrackSelectionView(vm: vm, chosenTitle: title, scanResult: scanResult,
                                    title: mediaTitle, year: year,
                                    isTV: isTV, season: season, episode: episode)
        case .confirmation(let ripInput, let encodeInput):
            ConfirmationView(vm: vm, ripInput: ripInput, encodeInput: encodeInput)
        case .ripping(let title, let progress):
            rippingDetail(title: title, progress: progress)
        case .done(let title):
            RipCompleteView(vm: vm, title: title, isError: false,
                            message: "Added to encode queue.")
        case .error(let message):
            RipCompleteView(vm: vm, title: "Rip Failed", isError: true, message: message)
        }
    }

    // MARK: - Ripping detail

    @ViewBuilder
    private func rippingDetail(title: String, progress: Int) -> some View {
        VStack(alignment: .leading, spacing: FrostTheme.paddingL) {
            Spacer()

            Text(title)
                .font(.title3)
                .bold()
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let ei = vm.confirmedEncodeInput {
                VStack(alignment: .leading, spacing: FrostTheme.paddingM) {
                    metaRow("Output", ei.outputURL.lastPathComponent)
                    metaRow("Preset", ei.preset)
                    if let ep = ei.episode { metaRow("Episode", ep) }
                }
            }

            Spacer()

            Text("\(progress)% complete")
                .font(.headline)
                .foregroundStyle(FrostTheme.teal)
            Text("Encoding will begin automatically when complete.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(FrostTheme.paddingL)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                Rectangle()
                    .fill(FrostTheme.frostCyan)
                    .frame(width: geo.size.width * progressFraction)
                    .animation(.linear(duration: 0.4), value: progressFraction)
            }
        }
        .frame(height: 3)
    }

    private var progressFraction: Double {
        switch vm.phase {
        case .ripping(_, let p): return Double(p) / 100.0
        case .done: return 1.0
        default: return 0
        }
    }
}
