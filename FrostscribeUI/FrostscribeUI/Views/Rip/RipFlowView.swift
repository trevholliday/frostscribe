import SwiftUI
import FrostscribeCore

struct RipFlowView: View {
    @State private var vm = RipFlowViewModel()
    @Environment(NavigationCoordinator.self) private var navCoordinator
    @Environment(StatusViewModel.self) private var statusVM
    @Environment(QueueViewModel.self) private var queueVM

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                LeftPanelView(vm: vm)
                    .frame(width: 200)
                Divider()
                rightContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            progressBar
        }
        .frame(minWidth: 640, idealWidth: 960, maxWidth: .infinity,
               minHeight: 460, idealHeight: 680, maxHeight: .infinity)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.title == "Frostscribe" })?.makeKeyAndOrderFront(nil)
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
            RipScanningView()
        case .titleSelection(let scanResult):
            TitleSelectionView(vm: vm, scanResult: scanResult)
        case .mediaType(let title, let scanResult):
            MediaTypeView(vm: vm, chosenTitle: title, scanResult: scanResult)
        case .tmdbSearch(let title, let scanResult, let isTV):
            TMDBSearchView(vm: vm, chosenTitle: title, scanResult: scanResult, isTV: isTV)
        case .tvEpisode(let title, let scanResult, let mediaTitle, let year):
            TVEpisodeView(vm: vm, chosenTitle: title, scanResult: scanResult,
                          title: mediaTitle, year: year)
        case .audioTrackSelection(let title, let scanResult, let mediaTitle,
                                  let year, let isTV, let season, let episode):
            AudioTrackSelectionView(vm: vm, chosenTitle: title, scanResult: scanResult,
                                    title: mediaTitle, year: year,
                                    isTV: isTV, season: season, episode: episode)
        case .confirmation(let ripInput, let encodeInput):
            ConfirmationView(vm: vm, ripInput: ripInput, encodeInput: encodeInput)
        case .ripping(let title, let progress):
            rippingDetail(title: title, progress: progress)
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

                if queueVM.jobs.isEmpty {
                    Text("Queue is empty.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(queueVM.jobs) { job in
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
                                    .foregroundStyle(
                                        job.status == .encoding ? FrostTheme.teal :
                                        job.status == .done ? Color.secondary : Color.secondary
                                    )
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
        ScrollView {
            VStack(alignment: .leading, spacing: FrostTheme.paddingL) {
                Text("History")
                    .font(.title3).bold()

                if statusVM.file.history.isEmpty {
                    Text("No history yet.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(statusVM.file.history.enumerated()), id: \.offset) { _, entry in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(.subheadline)
                                        .bold()
                                        .lineLimit(1)
                                    Text(entry.type.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(entry.startedAt, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
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

    // MARK: - Logs detail

    private var logsDetail: some View {
        VStack(alignment: .leading, spacing: FrostTheme.paddingM) {
            Text("Logs")
                .font(.title3).bold()
                .padding(.horizontal, FrostTheme.paddingL)
                .padding(.top, FrostTheme.paddingL)
            Text("Log output coming soon.")
                .foregroundStyle(.secondary)
                .padding(.horizontal, FrostTheme.paddingL)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ripping detail

    @ViewBuilder
    private func rippingDetail(title: String, progress: Int) -> some View {
        VStack(alignment: .leading, spacing: FrostTheme.paddingL) {
            Spacer()

            Text(title)
                .font(.title3)
                .bold()
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let ei = vm.confirmedEncodeInput {
                VStack(alignment: .leading, spacing: FrostTheme.paddingM) {
                    metaRow("Output", ei.outputURL.lastPathComponent)
                    metaRow("Preset", ei.preset)
                    if let ep = ei.episode { metaRow("Episode", ep) }
                }
            }

            Spacer()

            Text("\(progress)% complete")
                .font(.headline)
                .foregroundStyle(FrostTheme.teal)
            Text("Encoding will begin automatically when complete.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(FrostTheme.paddingL)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
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
