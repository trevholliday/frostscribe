import SwiftUI
import FrostscribeCore

@main
struct FrostscribeApp: App {
    @State private var statusVM = StatusViewModel(
        statusManager: StatusManager(appSupportURL: ConfigManager.appSupportURL)
    )
    @State private var queueVM = QueueViewModel(
        queueManager: QueueManager(appSupportURL: ConfigManager.appSupportURL)
    )
    @State private var vigilVM = VigilViewModel()
    @State private var navCoordinator = NavigationCoordinator()
    @State private var watcher = AppSupportWatcher()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(statusVM)
                .environment(queueVM)
                .environment(vigilVM)
                .environment(navCoordinator)
        } label: {
            MenuBarIcon(status: statusVM.file.status)
                .onAppear {
                    statusVM.startPolling()
                    queueVM.startPolling()
                    vigilVM.startWatchingIfEnabled()
                    watcher.onStatusChange = { statusVM.refresh() }
                    watcher.onQueueChange  = { queueVM.refresh() }
                    watcher.start()
                }
        }
        .menuBarExtraStyle(.window)

        Window("Frostscribe", id: "rip-flow") {
            RipFlowView()
                .environment(statusVM)
                .environment(queueVM)
                .environment(navCoordinator)
        }
        .windowResizability(.contentMinSize)
    }
}
