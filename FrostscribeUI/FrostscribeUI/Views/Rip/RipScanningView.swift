import SwiftUI

struct RipScanningView: View {
    let message: String

    var body: some View {
        VStack(spacing: FrostTheme.paddingL) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(FrostTheme.frostCyan)
            Text("Scanning disc…")
                .foregroundStyle(.secondary)
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FrostTheme.paddingL)
                    .frame(maxWidth: 360)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: message)
            }
            Spacer()
        }
    }
}
