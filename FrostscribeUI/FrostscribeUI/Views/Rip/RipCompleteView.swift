import SwiftUI
import FrostscribeCore

struct RipCompleteView: View {
    let vm: RipFlowViewModel
    let title: String
    let isError: Bool
    let message: String

    @State private var isEjecting = false
    @State private var ejected = false

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
            if isError {
                Button("Try Again") { vm.reset() }
                    .buttonStyle(.frostDestructive)
            } else {
                Button("Rip Another Disc") { vm.reset() }
                    .buttonStyle(.frostPrimary)
            }
            if ejected {
                Label("Disc ejected", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(FrostTheme.teal)
            } else {
                Button {
                    isEjecting = true
                    Task {
                        await Task.detached { DiscEjector().eject() }.value
                        isEjecting = false
                        ejected = true
                    }
                } label: {
                    if isEjecting {
                        Label("Ejecting…", systemImage: "eject")
                    } else {
                        Label("Eject Disc", systemImage: "eject")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
                .disabled(isEjecting)
            }
            Spacer()
        }
        .padding(FrostTheme.paddingL)
    }
}
