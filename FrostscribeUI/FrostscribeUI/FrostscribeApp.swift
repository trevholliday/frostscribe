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

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(statusVM)
                .environment(queueVM)
                .environment(vigilVM)
        } label: {
            // onAppear fires at launch so the icon reflects real state before the popover opens
            MenuBarIcon(status: statusVM.file.status)
                .onAppear {
                    statusVM.startPolling()
                    queueVM.startPolling()
                    vigilVM.startWatchingIfEnabled()
                    openWindow(id: "rip-flow")
                }
        }
        .menuBarExtraStyle(.window)

        Window("Rip Disc", id: "rip-flow") {
            RipFlowView()
        }

        Settings {
            SettingsView()
        }
    }
}
