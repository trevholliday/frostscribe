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

    private var showRippingStatus: Bool {
        guard navCoordinator.selectedSection == .rip else { return false }
        if case .ripping = vm.phase { return true }
        if case .done = vm.phase { return true }
        return false
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if showRippingStatus {
                rippingStatusPanel
            } else {
                navPanel
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
                isActive ? FrostTheme.deepBlue.opacity(0.5) : Color.clear,
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

    // MARK: - Ripping status panel

    private var rippingStatusPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: FrostTheme.paddingM) {
                    // Title + year
                    if let title = vm.confirmedTitle {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.headline).bold()
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                            if let year = vm.confirmedYear, !year.isEmpty {
                                Text(year)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Rating + runtime row
                    if let details = vm.mediaDetails {
                        HStack(spacing: 6) {
                            if let cert = details.certification {
                                Text(cert)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            if let runtime = details.runtimeFormatted {
                                Text(runtime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Release date
                        if let release = details.releaseDate {
                            Text(release)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        // Genres
                        if !details.genres.isEmpty {
                            Text(details.genres.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(FrostTheme.paddingM)
            }

            Divider().opacity(0.3)

            // Progress
            VStack(alignment: .leading, spacing: 6) {
                if case .ripping(_, let progress) = vm.phase {
                    ProgressView(value: Double(progress), total: 100)
                        .tint(FrostTheme.frostCyan)
                    Text("\(progress)% complete")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(FrostTheme.teal)
                    if let remaining = vm.estimatedSecondsRemaining {
                        Text("~\(Int(remaining / 60) + 1) min remaining")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if case .done = vm.phase {
                    Label("Added to queue", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(FrostTheme.teal)
                }
                Text("Encoding will begin automatically.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(FrostTheme.paddingM)

            settingsButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
