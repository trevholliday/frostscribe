import SwiftUI
import FrostscribeCore

struct RipFlowView: View {
    @State private var vm = RipFlowViewModel()
    @Environment(NavigationCoordinator.self) private var navCoordinator
    @Environment(StatusViewModel.self) private var statusVM
    @Environment(QueueViewModel.self) private var queueVM

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                LeftPanelView(vm: vm)
                    .frame(minWidth: 250, maxWidth: 600)
                rightContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            progressBar
        }
        .frame(minWidth: 640, idealWidth: 960, maxWidth: .infinity,
               minHeight: 460, idealHeight: 680, maxHeight: .infinity)
        .background(FrostTheme.background)
        .foregroundStyle(FrostTheme.textPrimary)
        .colorScheme(.dark)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.title == "Frostscribe" })?.makeKeyAndOrderFront(nil)
            vm.initialize()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let window = notification.object as? NSWindow, window.title == "Frostscribe" else { return }
            NSApp.setActivationPolicy(.accessory)
        }
        .toolbar {
            if navCoordinator.selectedSection == .settings {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { navCoordinator.selectedSection = .rip }
                }
            } else if vm.canCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .destructive) { vm.reset() }
                }
            }
        }
    }

    // MARK: - Right panel

    @ViewBuilder
    private var rightContent: some View {
        if navCoordinator.selectedSection == .settings {
            NavigationStack {
                SettingsView()
            }
        } else if navCoordinator.selectedSection == .ripJob {
            statusDetail
        } else if navCoordinator.selectedSection == .encodeQueue {
            queueDetail
        } else if navCoordinator.selectedSection == .history {
            historyDetail
        } else if navCoordinator.selectedSection == .logs {
            logsDetail
        } else { switch vm.phase {
        case .idle:
            RipIdleView(vm: vm)
        case .scanning:
            RipScanningView(message: vm.scanMessage)
        case .identify(let scanResult):
            TMDBSearchView(vm: vm, scanResult: scanResult)
        case .tvEpisode(let scanResult, let mediaTitle, let year):
            TVEpisodeView(vm: vm, scanResult: scanResult, title: mediaTitle, year: year)
        case .titleSelection(let scanResult, let mediaTitle, let year, let isTV, let season, let episode):
            TitleSelectionView(vm: vm, scanResult: scanResult,
                               mediaTitle: mediaTitle, year: year,
                               isTV: isTV, season: season, episode: episode)
        case .audioTrackSelection(let discTitle, let scanResult, let mediaTitle,
                                  let year, let isTV, let season, let episode):
            AudioTrackSelectionView(vm: vm, chosenTitle: discTitle, scanResult: scanResult,
                                    title: mediaTitle, year: year,
                                    isTV: isTV, season: season, episode: episode)
        case .confirmation(let ripInput, let encodeInput):
            ConfirmationView(vm: vm, ripInput: ripInput, encodeInput: encodeInput)
        case .ripping:
            RipRippingView(vm: vm)
        case .done(let title):
            RipCompleteView(vm: vm, title: title, isError: false,
                            message: "Added to encode queue.")
        case .error(let message):
            RipCompleteView(vm: vm, title: "Rip Failed", isError: true, message: message)
        } }
    }

    // MARK: - Status detail

    private var statusDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrostTheme.paddingL) {
                Text("Rip Status")
                    .font(.title3).bold()

                if statusVM.file.status == .ripping, let job = statusVM.file.currentJob {
                    VStack(alignment: .leading, spacing: FrostTheme.paddingM) {
                        statusRow("Title", job.title)
                        statusRow("Progress", job.progress)
                        if let item = job.currentItem {
                            statusRow("Current", item)
                        }
                        ProgressView(value: job.progress.progressFraction)
                            .tint(FrostTheme.frostCyan)
                    }
                    .padding(FrostTheme.paddingM)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius))
                } else {
                    Text("No rip in progress.")
                        .foregroundStyle(.secondary)
                }

                if !statusVM.file.history.isEmpty {
                    Text("Recent History")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: FrostTheme.paddingS) {
                        ForEach(Array(statusVM.file.history.prefix(10).enumerated()), id: \.offset) { _, entry in
                            HStack(alignment: .top) {
                                Text(entry.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(entry.startedAt, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 3)
                            Divider()
                        }
                    }
                }
            }
            .padding(FrostTheme.paddingL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    // MARK: - Queue detail

    private var queueDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrostTheme.paddingL) {
                HStack {
                    Text("Encode Queue")
                        .font(.title3).bold()
                    Spacer()
                    if queueVM.activeCount > 0 {
                        Text("\(queueVM.activeCount) active")
                            .font(.caption)
                            .foregroundStyle(FrostTheme.teal)
                    }
                }

                let activeJobs = queueVM.jobs.filter(\.isActive).reversed()
                if activeJobs.isEmpty {
                    Text("Queue is empty.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(activeJobs) { job in
                            HStack(alignment: .top, spacing: FrostTheme.paddingM) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(job.title)
                                        .font(.subheadline)
                                        .bold()
                                        .lineLimit(1)
                                    if let ep = job.episode {
                                        Text(ep)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(URL(fileURLWithPath: job.output).lastPathComponent)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Text(job.status.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(job.status == .encoding ? FrostTheme.teal : .secondary)
                            }
                            .padding(.vertical, FrostTheme.paddingS)
                            Divider()
                        }
                    }
                }
            }
            .padding(FrostTheme.paddingL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - History detail

    private var historyDetail: some View {
        let ripRecords = RipHistoryStore(appSupportURL: ConfigManager.appSupportURL).load()
        return ScrollView {
            VStack(alignment: .leading, spacing: FrostTheme.paddingL) {
                Text("History")
                    .font(.title3).bold()

                if statusVM.file.history.isEmpty {
                    Text("No history yet.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(statusVM.file.history.enumerated()), id: \.offset) { _, entry in
                            let record = ripRecords.first {
                                $0.jobLabel == entry.title &&
                                abs($0.timestamp.timeIntervalSince(entry.startedAt)) < 300
                            }
                            let encoded = queueVM.jobs.contains {
                                $0.title == entry.title && $0.status == .done
                            }
                            let entryYear = entry.title.range(of: #"\((\d{4})\)"#, options: .regularExpression)
                                .map { String(entry.title[$0].dropFirst().dropLast()) }
                            HStack(alignment: .top, spacing: FrostTheme.paddingM) {
                                // Left: title + year
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(.subheadline).bold()
                                        .lineLimit(1)
                                    if let y = entryYear {
                                        Text(y)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let r = record {
                                        HStack(spacing: 4) {
                                            Text(r.discType.displayName)
                                            Text("·")
                                            Text(formatBytes(r.titleSizeBytes))
                                            Text("·")
                                            Text(formatDuration(r.ripDurationSeconds))
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                // Right: date + pills
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(entry.startedAt, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    HStack(spacing: 4) {
                                        pill("Ripped", color: FrostTheme.teal)
                                        if encoded {
                                            pill("Encoded", color: FrostTheme.glacier)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, FrostTheme.paddingS)
                            Divider()
                        }
                    }
                }

                // Rip rate stats (requires at least one record)
                if !ripRecords.isEmpty {
                    ripRateStats(records: ripRecords)
                }
            }
            .padding(FrostTheme.paddingL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func ripRateStats(records: [RipRecord]) -> some View {
        let rows: [(type: DiscType, avgMBps: Double, count: Int)] = DiscType.allCases
            .filter { $0 != .unknown }
            .compactMap { type in
                let r = records.filter { $0.discType == type && $0.success && $0.ripDurationSeconds > 0 }
                guard !r.isEmpty else { return nil }
                let avg = r.map { Double($0.titleSizeBytes) / $0.ripDurationSeconds / (1024 * 1024) }.reduce(0, +) / Double(r.count)
                return (type, avg, r.count)
            }
        return VStack(alignment: .leading, spacing: FrostTheme.paddingS) {
            Text("Rip Rates")
                .font(.subheadline).bold()
            ForEach(rows, id: \.type) { row in
                HStack {
                    Text(row.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    Text(String(format: "%.1f MB/s", row.avgMBps))
                        .font(.caption.monospaced())
                        .foregroundStyle(FrostTheme.teal)
                    Text("(\(row.count) rip\(row.count == 1 ? "" : "s"))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(FrostTheme.paddingM)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius))
    }

    private func pill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func formatBytes(_ bytes: Int) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return gb >= 1 ? String(format: "%.1f GB", gb) : String(format: "%.0f MB", gb * 1024)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds / 60)
        return mins < 1 ? "<1 min" : "\(mins) min"
    }

    // MARK: - Logs detail

    private var logsDetail: some View {
        LogsView()
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                Rectangle()
                    .fill(FrostTheme.frostCyan)
                    .frame(width: geo.size.width * progressFraction)
                    .animation(.linear(duration: 0.4), value: progressFraction)
            }
        }
        .frame(height: 3)
    }

    private var progressFraction: Double {
        switch vm.phase {
        case .ripping(_, let p): return Double(p) / 100.0
        case .done: return 1.0
        default: return 0
        }
    }
}
