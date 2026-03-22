import SwiftUI
import FrostscribeCore

struct QueueRowView: View {
    let job: EncodeJob

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                statusIcon
                Text(job.label)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text(job.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            if job.status == .encoding {
                ProgressView(value: job.progress.progressFraction)
                    .tint(FrostTheme.glacier)
            }
        }
    }

    private var statusIcon: some View {
        Group {
            switch job.status {
            case .pending:
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
            case .encoding:
                Image(systemName: "gear")
                    .foregroundStyle(FrostTheme.glacier)
                    .symbolEffect(.rotate, isActive: true)
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(FrostTheme.teal)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(FrostTheme.alert)
            }
        }
        .font(.caption)
        .frame(width: 14)
    }

    private var statusColor: Color {
        switch job.status {
        case .pending:  return Color.secondary
        case .encoding: return FrostTheme.glacier
        case .done:     return FrostTheme.teal
        case .error:    return FrostTheme.alert
        }
    }


}
