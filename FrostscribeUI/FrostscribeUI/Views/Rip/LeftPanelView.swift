import SwiftUI
import FrostscribeCore

struct LeftPanelView: View {
    let vm: RipFlowViewModel

    private static let flowSteps: [(label: String, icon: String)] = [
        ("Scan Disc",    "opticaldisc"),
        ("Select Title", "list.bullet"),
        ("Media Type",   "film"),
        ("Identify",     "sparkle.magnifyingglass"),
        ("Confirm",      "checkmark.circle"),
    ]

    private var stepIndex: Int {
        switch vm.phase {
        case .idle, .scanning:                               return 0
        case .titleSelection:                                return 1
        case .mediaType:                                     return 2
        case .tmdbSearch, .tvEpisode, .audioTrackSelection:  return 3
        case .confirmation, .ripping, .done, .error:         return 4
        }
    }

    private var showPoster: Bool {
        switch vm.phase {
        case .ripping, .done: return true
        default: return false
        }
    }

    var body: some View {
        ZStack {
            if showPoster {
                posterPanel
            } else {
                stepPanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Step panel

    private var stepPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "snowflake")
                    .foregroundStyle(FrostTheme.teal)
                Text("Frostscribe")
                    .font(.headline)
            }
            .padding(FrostTheme.paddingM)

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(Self.flowSteps.enumerated()), id: \.offset) { index, step in
                    stepRow(index: index, label: step.label, icon: step.icon)
                }
            }
            .padding(.horizontal, FrostTheme.paddingM)
            .padding(.top, FrostTheme.paddingL)

            Spacer()
        }
    }

    private func stepRow(index: Int, label: String, icon: String) -> some View {
        let isActive = index == stepIndex
        let isDone   = index < stepIndex

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isActive ? FrostTheme.teal : (isDone ? FrostTheme.teal.opacity(0.25) : Color.clear))
                    .frame(width: 26, height: 26)
                Circle()
                    .strokeBorder(isDone || isActive ? Color.clear : Color.primary.opacity(0.15), lineWidth: 1)
                    .frame(width: 26, height: 26)
                Image(systemName: isDone ? "checkmark" : icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? .white : (isDone ? FrostTheme.teal : Color.primary.opacity(0.3)))
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(isActive ? Color.primary : (isDone ? Color.secondary : Color.primary.opacity(0.35)))
        }
        .padding(.vertical, 5)
    }

    // MARK: - Poster panel

    private var posterPanel: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let url = vm.posterURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholderBg
                    }
                } else {
                    placeholderBg
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )

            if let title = vm.confirmedTitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let year = vm.confirmedYear {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .padding(FrostTheme.paddingM)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var placeholderBg: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            Image(systemName: "snowflake")
                .font(.system(size: 36))
                .foregroundStyle(FrostTheme.teal.opacity(0.3))
        }
    }
}
