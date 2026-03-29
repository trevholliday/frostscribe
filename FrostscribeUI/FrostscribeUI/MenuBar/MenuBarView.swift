import SwiftUI
import FrostscribeCore

struct MenuBarView: View {
    @Environment(StatusViewModel.self) private var statusVM
    @Environment(QueueViewModel.self) private var queueVM
    @Environment(VigilViewModel.self) private var vigilVM
    @Environment(NavigationCoordinator.self) private var navCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            FrostTheme.divider.frame(height: 1)
            StatusSectionView()
                .padding(FrostTheme.paddingM)
                .contentShape(Rectangle())
                .onTapGesture { openSection(.rip) }
            FrostTheme.divider.frame(height: 1)
            QueueSectionView()
                .padding(FrostTheme.paddingM)
                .contentShape(Rectangle())
                .onTapGesture { openSection(.encodeQueue) }
            FrostTheme.divider.frame(height: 1)
            footerRow
            FrostTheme.divider.frame(height: 1)
            quitRow
        }
        .frame(width: FrostTheme.popoverWidth)
        .background(FrostTheme.background)
        .foregroundStyle(FrostTheme.textPrimary)
    }

    // MARK: - Navigation

    private func openSection(_ section: AppSection) {
        navCoordinator.selectedSection = .some(section)
        openWindow(id: "rip-flow")
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "snowflake")
                .foregroundStyle(FrostTheme.teal)
            Text("Frostscribe")
                .bold()
            if vigilVM.isWatching {
                Image(systemName: "eye")
                    .font(.caption2)
                    .foregroundStyle(FrostTheme.glacier)
                    .help("Vigil Mode active — watching for disc insertion")
            }
            Spacer()
            statusBadge
        }
        .padding(FrostTheme.paddingM)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(badgeColor)
                .frame(width: 7, height: 7)
            Text(badgeLabel)
                .font(.caption)
                .foregroundStyle(FrostTheme.textPrimary.opacity(0.6))
        }
    }

    /// When the ripper is idle but the encode worker has active jobs, show "encoding".
    private var badgeLabel: String {
        if statusVM.file.status == .idle && queueVM.activeCount > 0 {
            return "encoding"
        }
        return statusVM.file.status.rawValue
    }

    private var badgeColor: Color {
        if statusVM.file.status == .idle && queueVM.activeCount > 0 {
            return FrostTheme.glacier
        }
        return statusVM.file.status.color
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            Button { openSection(AppSection.rip) } label: {
                Label("Rip Disc", systemImage: "opticaldisc")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(FrostTheme.teal)
            Spacer()
            Button { openSection(AppSection.settings) } label: {
                Label("Settings", systemImage: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(FrostTheme.textPrimary.opacity(0.6))
            Spacer()
            Text(appVersion)
                .font(.caption)
                .foregroundStyle(FrostTheme.textPrimary.opacity(0.35))
        }
        .padding(.horizontal, FrostTheme.paddingM)
        .padding(.vertical, FrostTheme.paddingS)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(v) (\(b))"
    }

    private var quitRow: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit Frostscribe", systemImage: "power")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(FrostTheme.textPrimary.opacity(0.6))
        .padding(.horizontal, FrostTheme.paddingM)
        .padding(.vertical, FrostTheme.paddingS)
    }
}
