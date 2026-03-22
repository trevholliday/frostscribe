import SwiftUI

struct RipScanningView: View {
    var body: some View {
        VStack(spacing: FrostTheme.paddingL) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(FrostTheme.frostCyan)
            Text("Scanning disc…")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
