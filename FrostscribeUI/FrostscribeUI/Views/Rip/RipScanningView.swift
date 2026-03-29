import SwiftUI

struct RipScanningView: View {
    let message: String
    let onAbort: () -> Void

    private struct LogEntry: Identifiable {
        let id = UUID()
        let text: String
    }

    @State private var logLines: [LogEntry] = []

    var body: some View {
        VStack(spacing: FrostTheme.paddingL) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(FrostTheme.frostCyan)
            Text("Scanning disc…")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(logLines.enumerated()), id: \.element.id) { index, entry in
                    let age = Double(index) / Double(max(logLines.count - 1, 1))
                    Text(entry.text)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(.tertiary.opacity(0.35 + age * 0.65))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: 440)
            .clipped()
            .padding(.horizontal, FrostTheme.paddingL)

            Button("Abort Rip", role: .destructive) { onAbort() }
                .buttonStyle(.frostDestructive)
            Spacer()
        }
        .onChange(of: message) { _, newValue in
            guard !newValue.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                logLines.append(LogEntry(text: newValue))
                if logLines.count > 5 {
                    logLines.removeFirst()
                }
            }
        }
    }
}
