import SwiftUI

struct RipIdleView: View {
    let vm: RipFlowViewModel

    var body: some View {
        VStack(spacing: FrostTheme.paddingL) {
            Spacer()
            Image(systemName: "opticaldisc")
                .font(.system(size: 70))
                .foregroundStyle(FrostTheme.glacier)
            Text("Rip a Disc")
                .font(.system(size: 28, weight: .bold))
            Text("Insert a disc and click Scan to begin.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Scan Disc") {
                vm.startRip()
            }
            .buttonStyle(.frostPrimary)
            Spacer()
        }
        .padding(FrostTheme.paddingL)
    }
}
