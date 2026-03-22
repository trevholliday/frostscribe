import SwiftUI
import FrostscribeCore

struct TVEpisodeView: View {
    let vm: RipFlowViewModel
    let chosenTitle: DiscTitle
    let scanResult: DiscScanResult
    let title: String
    let year: String

    @State private var season = 1
    @State private var episode = 1

    var body: some View {
        VStack(spacing: FrostTheme.paddingL) {
            Spacer()
            Image(systemName: "tv")
                .font(.system(size: 40))
                .foregroundStyle(FrostTheme.glacier)
            Text(title)
                .font(.title3)
                .bold()
                .lineLimit(1)
            Text(year)
                .foregroundStyle(.secondary)

            VStack(spacing: FrostTheme.paddingM) {
                Stepper("Season \(season)", value: $season, in: 1...99)
                    .padding(.horizontal, FrostTheme.paddingL)
                Stepper("Episode \(episode)", value: $episode, in: 1...999)
                    .padding(.horizontal, FrostTheme.paddingL)
            }
            .padding(.vertical, FrostTheme.paddingM)

            Text("Label: \(String(format: "S%02dE%02d", season, episode))")
                .font(.caption.monospaced())
                .foregroundStyle(FrostTheme.teal)

            Button("Continue") {
                vm.setEpisode(season: season, episode: episode,
                              chosenTitle: chosenTitle, scanResult: scanResult,
                              title: title, year: year)
            }
            .buttonStyle(.frostPrimary)

            Spacer()
        }
        .padding(FrostTheme.paddingL)
    }
}
