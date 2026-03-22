import SwiftUI

struct RippingProgressView: View {
    let title: String
    let progress: Int

    var body: some View {
        VStack(spacing: FrostTheme.paddingL) {
            Spacer()
            Image(systemName: "opticaldisc")
                .font(.system(size: 44))
                .foregroundStyle(FrostTheme.teal)
                .symbolEffect(.pulse, isActive: true)
            Text(title)
                .font(.title3)
                .bold()
                .lineLimit(1)
            VStack(spacing: FrostTheme.paddingS) {
                ProgressView(value: Double(progress), total: 100)
                    .tint(FrostTheme.frostCyan)
                    .frame(width: 320)
                Text("\(progress)%")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text("Ripping…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(FrostTheme.paddingL)
    }
}
