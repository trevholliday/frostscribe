import SwiftUI
import FrostscribeCore

struct TVEpisodeView: View {
    let vm: RipFlowCoordinator
    let scanResult: DiscScanResult
    let title: String
    let year: String

    @State private var season = 1
    @State private var episode = 1

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
            Image(systemName: "tv")
                .font(.system(size: 50))
                .foregroundStyle(FrostTheme.glacier)
            Text(title)
                .font(.system(size: 25, weight: .bold))
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
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(FrostTheme.teal)

            Button("Continue") {
                vm.setEpisode(season: season, episode: episode,
                              scanResult: scanResult, title: title, year: year)
            }
            .buttonStyle(.frostPrimary)

            Spacer()
        }
        .padding(FrostTheme.paddingL)
    }
}
