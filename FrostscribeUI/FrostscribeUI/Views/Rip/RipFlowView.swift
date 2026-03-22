import SwiftUI
import FrostscribeCore

struct RipFlowView: View {
    @State private var vm = RipFlowViewModel()

    var body: some View {
        Group {
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
                RippingProgressView(title: title, progress: progress)
            case .done(let title):
                RipCompleteView(vm: vm, title: title, isError: false,
                                message: "Added to encode queue.")
            case .error(let message):
                RipCompleteView(vm: vm, title: "Rip Failed", isError: true, message: message)
            }
        }
        .frame(width: 520, height: 520)
        .toolbar {
            if vm.canCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { vm.reset() }
                }
            }
        }
    }
}
