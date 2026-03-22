import SwiftUI

struct RipCompleteView: View {
    let vm: RipFlowViewModel
    let title: String
    let isError: Bool
    let message: String

    var body: some View {
        VStack(spacing: FrostTheme.paddingL) {
            Spacer()
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(isError ? FrostTheme.alert : FrostTheme.teal)
            Text(title)
                .font(.title3)
                .bold()
                .lineLimit(1)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FrostTheme.paddingL)
            Button(isError ? "Try Again" : "Rip Another Disc") {
                vm.reset()
            }
            .buttonStyle(.borderedProminent)
            .tint(isError ? FrostTheme.alert : FrostTheme.frostCyan)
            .controlSize(.large)
            Spacer()
        }
        .padding(FrostTheme.paddingL)
    }
}
