import Foundation
import FrostscribeCore

// Composition root — wire concrete dependencies
let appSupportURL = ConfigManager.appSupportURL
let config = try? ConfigManager().load()
let logStore = LogStore(appSupportURL: appSupportURL)

let encodeWorker = EncodeWorker(
    queueManager: QueueManager(appSupportURL: appSupportURL),
    handbrakeRunner: HandBrakeRunner(binPath: config?.handbrakeBin ?? "HandBrakeCLI"),
    hookRunner: HookRunner(command: config?.eventHook ?? ""),
    logStore: logStore
)

let ripWorker = RipWorker(
    ripQueueManager: RipQueueManager(appSupportURL: appSupportURL),
    encodeQueueManager: QueueManager(appSupportURL: appSupportURL),
    statusManager: StatusManager(appSupportURL: appSupportURL),
    makemkvBin: config?.makemkvBin ?? "makemkvcon",
    hookRunner: HookRunner(command: config?.eventHook ?? ""),
    logStore: logStore
)

let sigSrc = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigSrc.setEventHandler {
    Task { await ripWorker.stop() }
    Task { await encodeWorker.stop() }
}
sigSrc.resume()
signal(SIGTERM, SIG_IGN)

let sigIntSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigIntSrc.setEventHandler {
    Task { await ripWorker.stop() }
    Task { await encodeWorker.stop() }
}
sigIntSrc.resume()
signal(SIGINT, SIG_IGN)

Task { await ripWorker.start() }
Task { await encodeWorker.start() }
dispatchMain()
