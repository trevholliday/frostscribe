import SwiftUI

struct RipIdleView: View {
    let vm: RipFlowViewModel

    var body: some View {
        VStack(spacing: FrostTheme.paddingL) {
            Spacer()
            Image(systemName: "opticaldisc")
                .font(.system(size: 56))
                .foregroundStyle(FrostTheme.glacier)
            Text("Rip a Disc")
                .font(.title2)
                .bold()
            Text("Insert a disc and click Scan to begin.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Scan Disc") {
                vm.startRip()
            }
            .buttonStyle(.borderedProminent)
            .tint(FrostTheme.frostCyan)
            .controlSize(.large)
            Spacer()
        }
        .padding(FrostTheme.paddingL)
    }
}
