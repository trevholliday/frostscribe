import SwiftUI
import FrostscribeCore

struct StatusSectionView: View {
    @Environment(StatusViewModel.self) private var statusVM

    var body: some View {
        VStack(alignment: .leading, spacing: FrostTheme.spacing) {
            Text("RIP")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
                .kerning(0.5)

            if statusVM.file.status == .ripping, let job = statusVM.file.currentJob {
                activeRipView(job: job)
            } else {
                Text("No disc active")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, FrostTheme.paddingS)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func activeRipView(job: RipJob) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(job.title)
                .font(.subheadline)
                .bold()
                .lineLimit(1)

            ProgressView(value: job.progress.progressFraction)
                .tint(FrostTheme.frostCyan)

            HStack {
                Text(job.progress)
                    .font(.caption)
                    .foregroundStyle(FrostTheme.teal)
                Spacer()
                if let item = job.currentItem {
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
