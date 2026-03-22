import SwiftUI
import FrostscribeCore

struct QueueSectionView: View {
    @Environment(QueueViewModel.self) private var queueVM

    private static let maxVisible = 5

    var body: some View {
        VStack(alignment: .leading, spacing: FrostTheme.spacing) {
            HStack {
                Text("QUEUE")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)
                    .kerning(0.5)
                Spacer()
                if queueVM.activeCount > 0 {
                    Text("\(queueVM.activeCount) active")
                        .font(.caption)
                        .foregroundStyle(FrostTheme.frostCyan)
                }
            }

            if queueVM.jobs.isEmpty {
                Text("Queue is empty")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, FrostTheme.paddingS)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(queueVM.jobs.prefix(Self.maxVisible))) { job in
                        QueueRowView(job: job)
                    }
                    if queueVM.jobs.count > Self.maxVisible {
                        Text("+ \(queueVM.jobs.count - Self.maxVisible) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
