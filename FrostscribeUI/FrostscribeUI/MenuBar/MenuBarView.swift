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
            Divider()
            StatusSectionView()
                .padding(FrostTheme.paddingM)
                .contentShape(Rectangle())
                .onTapGesture { openSection(.ripJob) }
            Divider()
            QueueSectionView()
                .padding(FrostTheme.paddingM)
                .contentShape(Rectangle())
                .onTapGesture { openSection(.encodeQueue) }
            Divider()
            footerRow
            Divider()
            quitRow
        }
        .frame(width: FrostTheme.popoverWidth)
    }

    // MARK: - Navigation

    private func openSection(_ section: AppSection) {
        navCoordinator.selectedSection = .some(section)
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "rip-flow")
        NSApp.activate(ignoringOtherApps: true)
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
            Text(statusVM.file.status.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var badgeColor: Color { statusVM.file.status.color }

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
            Button { openSection(AppSection.rip) } label: {
                Label("Settings", systemImage: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Spacer()
            Text("v1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, FrostTheme.paddingM)
        .padding(.vertical, FrostTheme.paddingS)
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
        .foregroundStyle(.secondary)
        .padding(.horizontal, FrostTheme.paddingM)
        .padding(.vertical, FrostTheme.paddingS)
    }
}
