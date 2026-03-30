import SwiftUI
import FrostscribeCore

struct AudioTrackSelectionView: View {
    let vm: RipFlowCoordinator
    let chosenTitle: DiscTitle
    let scanResult: DiscScanResult
    let title: String
    let year: String
    let isTV: Bool
    let season: Int
    let episode: Int

    // selectedIndices uses 1-based track numbers
    @State private var selectedIndices: Set<Int>

    init(vm: RipFlowCoordinator, chosenTitle: DiscTitle, scanResult: DiscScanResult,
         title: String, year: String, isTV: Bool, season: Int, episode: Int) {
        self.vm = vm
        self.chosenTitle = chosenTitle
        self.scanResult = scanResult
        self.title = title
        self.year = year
        self.isTV = isTV
        self.season = season
        self.episode = episode
        _selectedIndices = State(initialValue: Set(1...chosenTitle.audioTracks.count))
    }

    private var allSelected: Bool { selectedIndices.count == chosenTitle.audioTracks.count }

    private var allSelectedBinding: Binding<Bool> {
        Binding(
            get: { allSelected },
            set: { on in selectedIndices = on ? Set(1...chosenTitle.audioTracks.count) : [] }
        )
    }

    private func trackBinding(for num: Int) -> Binding<Bool> {
        Binding(
            get: { selectedIndices.contains(num) },
            set: { on in if on { selectedIndices.insert(num) } else { selectedIndices.remove(num) } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Divider()
            List {
                // Select all toggle
                HStack {
                    Toggle(isOn: allSelectedBinding) {
                        Text("All tracks")
                            .bold()
                    }
                }
                Divider()
                ForEach(Array(chosenTitle.audioTracks.enumerated()), id: \.offset) { i, track in
                    let num = i + 1
                    HStack {
                        Toggle(isOn: trackBinding(for: num)) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Track \(num)")
                                        .bold()
                                    if track.isLossless {
                                        Text("lossless")
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(FrostTheme.teal.opacity(0.2),
                                                        in: Capsule())
                                            .foregroundStyle(FrostTheme.teal)
                                    }
                                }
                                Text(track.summary)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            Divider()
            HStack {
                Text("\(selectedIndices.count) of \(chosenTitle.audioTracks.count) selected")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Continue") {
                    let tracks = selectedIndices.isEmpty ? nil : selectedIndices.sorted()
                    vm.selectAudioTracks(tracks, chosenTitle: chosenTitle, scanResult: scanResult,
                                         title: title, year: year, isTV: isTV,
                                         season: season, episode: episode)
                }
                .buttonStyle(.frostPrimary)
                .disabled(selectedIndices.isEmpty)
            }
            .padding(FrostTheme.paddingM)
        }
    }

    private var headerRow: some View {
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
            Text("SELECT AUDIO TRACKS")
                .font(.system(size: 15, weight: .bold)).foregroundStyle(.secondary)
            Spacer()
            Button("Abort Rip", role: .destructive) { vm.reset() }
                .buttonStyle(.frostDestructive)
        }
        .padding(.horizontal, FrostTheme.paddingM)
        .padding(.vertical, FrostTheme.paddingS)
    }
}
