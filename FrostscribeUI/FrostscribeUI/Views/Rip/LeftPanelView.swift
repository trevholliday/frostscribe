import SwiftUI
import FrostscribeCore

struct LeftPanelView: View {
    let vm: RipFlowViewModel
    @Environment(NavigationCoordinator.self) private var navCoordinator

    private static let sections: [(label: String, icon: String, section: AppSection)] = [
        ("Rip",          "opticaldisc",            .rip),
        ("Rip Job",      "waveform",               .ripJob),
        ("Encode Queue", "list.bullet",             .encodeQueue),
        ("History",      "clock.arrow.trianglehead.counterclockwise.rotate.90", .history),
        ("Logs",         "doc.text",               .logs),
    ]

    private var showPoster: Bool {
        guard navCoordinator.selectedSection == .rip else { return false }
        switch vm.phase {
        case .ripping, .done: return true
        default: return false
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if showPoster {
                posterPanel
            } else {
                navPanel
            }

            if showPoster {
                settingsButton
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius))
                    .padding(FrostTheme.paddingS)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Nav panel

    private var navPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Self.sections, id: \.section) { item in
                    sectionTab(label: item.label, icon: item.icon, section: item.section)
                }
            }
            .padding(FrostTheme.paddingS)
            .padding(.top, FrostTheme.paddingM)

            Spacer()

            settingsButton
        }
    }

    private func sectionTab(label: String, icon: String, section: AppSection) -> some View {
        let isActive = navCoordinator.selectedSection == section
        return Button {
            navCoordinator.selectedSection = section
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 18)
                Text(label)
                    .font(.subheadline)
            }
            .foregroundStyle(isActive ? FrostTheme.teal : Color.primary.opacity(0.45))
            .padding(.vertical, 6)
            .padding(.horizontal, FrostTheme.paddingS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isActive ? FrostTheme.deepBlue : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings button

    private var settingsButton: some View {
        let isActive = navCoordinator.selectedSection == .settings
        return Button {
            navCoordinator.selectedSection = isActive ? .rip : .settings
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "gear")
                    .font(.system(size: 12))
                Text("Settings")
                    .font(.caption)
            }
            .foregroundStyle(isActive ? FrostTheme.teal : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(vm.isRipping)
        .padding(FrostTheme.paddingM)
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
