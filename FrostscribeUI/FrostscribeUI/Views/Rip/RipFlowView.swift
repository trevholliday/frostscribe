import SwiftUI
import FrostscribeCore

struct RipFlowView: View {
    @State private var vm = RipFlowViewModel()
    @State private var showStats = false
    @State private var historyTab: HistoryTab = .rips

    private enum HistoryTab: String, CaseIterable {
        case rips = "Rips"
        case encodeFailed = "Failed Encodes"
    }
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
            } else if vm.canAbort {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abort Rip", role: .destructive) { vm.reset() }
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
            RipScanningView(message: vm.scanMessage, onAbort: { vm.reset() })
        case .identify(let scanResult):
            TMDBSearchView(vm: vm, scanResult: scanResult)
        case .tvEpisode(let scanResult, let mediaTitle, let year):
            TVEpisodeView(vm: vm, scanResult: scanResult, title: mediaTitle, year: year)
        case .tvMultiEpisode(let scanResult, let mediaTitle, let year, let season, let startEpisode):
            TVMultiEpisodeSelectionView(vm: vm, scanResult: scanResult, title: mediaTitle, year: year,
                                        season: season, startEpisode: startEpisode)
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

    // MARK: - Queue detail

    private var queueDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrostTheme.paddingL) {
                HStack {
                    Text("Encode Queue")
                        .font(.system(size: 25, weight: .bold))
                    Spacer()
                    if queueVM.activeCount > 0 {
                        Text("\(queueVM.activeCount) active")
                            .font(.system(size: 15))
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
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: FrostTheme.paddingM) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(job.title)
                                            .font(.system(size: 19, weight: .bold))
                                            .lineLimit(1)
                                        if let ep = job.episode {
                                            Text(ep)
                                                .font(.system(size: 15))
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(URL(fileURLWithPath: job.output).lastPathComponent)
                                            .font(.system(size: 15, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(job.status == .encoding ? job.progress : job.status.rawValue.capitalized)
                                        .font(.system(size: 15).monospacedDigit())
                                        .foregroundStyle(job.status == .encoding ? FrostTheme.teal : .secondary)
                                }
                                if job.status == .encoding {
                                    ProgressView(value: job.progress.progressFraction)
                                        .tint(FrostTheme.teal)
                                }
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
                HStack {
                    Text("History")
                        .font(.system(size: 25, weight: .bold))
                    Spacer()
                    Button {
                        showStats = true
                    } label: {
                        Label("Stats", systemImage: "chart.bar.fill")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(FrostTheme.glacier)
                }
                .sheet(isPresented: $showStats) {
                    StatsView()
                        .frame(minWidth: 640, minHeight: 480)
                }

                Picker("", selection: $historyTab) {
                    ForEach(HistoryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if historyTab == .rips {
                    ripsTab(ripRecords: ripRecords)
                } else {
                    encodeFailed
                }
            }
            .padding(FrostTheme.paddingL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func ripsTab(ripRecords: [RipRecord]) -> some View {
        let sorted = ripRecords.sorted { $0.timestamp > $1.timestamp }
        return VStack(alignment: .leading, spacing: FrostTheme.paddingL) {
            if sorted.isEmpty {
                Text("No history yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sorted) { record in
                        let encodeJob = queueVM.jobs.first { $0.title == record.jobLabel }
                        let encoded = encodeJob?.status == .done
                        let encodeFailed = encodeJob?.status == .error
                        HStack(alignment: .top, spacing: FrostTheme.paddingM) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.jobLabel)
                                    .font(.system(size: 19, weight: .bold))
                                    .lineLimit(1)
                                    .foregroundStyle(!record.success || encodeFailed ? FrostTheme.alert : .primary)
                                HStack(spacing: 4) {
                                    Text(record.discType.displayName)
                                    Text("·")
                                    Text(formatBytes(record.titleSizeBytes))
                                    Text("·")
                                    Text(formatDuration(record.ripDurationSeconds))
                                }
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(record.timestamp, style: .date)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                                HStack(spacing: 4) {
                                    if !record.success {
                                        pill("Rip Failed", color: FrostTheme.alert)
                                    } else {
                                        pill("Ripped", color: FrostTheme.teal)
                                    }
                                    if encodeFailed {
                                        Button {
                                            if let job = encodeJob { queueVM.requeue(job) }
                                        } label: {
                                            pill("Encode Failed — Re-encode", color: FrostTheme.alert)
                                        }
                                        .buttonStyle(.plain)
                                    } else if encoded {
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

            if !sorted.isEmpty {
                ripRateStats(records: ripRecords)
            }
        }
    }

    private var encodeFailed: some View {
        let superseded = Set(queueVM.jobs
            .filter { $0.status == .pending || $0.status == .encoding || $0.status == .done }
            .map { $0.output })
        let failed = queueVM.jobs.filter { $0.status == .error && !superseded.contains($0.output) }
        return VStack(alignment: .leading, spacing: 0) {
            if failed.isEmpty {
                Text("No failed encodes.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(failed) { job in
                    HStack(alignment: .top, spacing: FrostTheme.paddingM) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(job.label)
                                .font(.system(size: 19, weight: .bold))
                                .lineLimit(1)
                                .foregroundStyle(FrostTheme.alert)
                            Text(URL(fileURLWithPath: job.output).lastPathComponent)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        HStack(spacing: FrostTheme.paddingS) {
                            Button {
                                queueVM.requeue(job)
                            } label: {
                                pill("Re-encode", color: FrostTheme.teal)
                            }
                            .buttonStyle(.plain)
                            Button {
                                queueVM.remove(job)
                            } label: {
                                pill("Remove", color: .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, FrostTheme.paddingS)
                    Divider()
                }
            }
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
                .font(.system(size: 19, weight: .bold))
            ForEach(rows, id: \.type) { row in
                HStack {
                    Text(row.type.displayName)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    Text(String(format: "%.1f MB/s", row.avgMBps))
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(FrostTheme.teal)
                    Text("(\(row.count) rip\(row.count == 1 ? "" : "s"))")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(FrostTheme.paddingM)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius))
    }

    private func pill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .bold))
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
