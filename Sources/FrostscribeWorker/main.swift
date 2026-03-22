import Foundation
import FrostscribeCore

// Composition root — wire concrete dependencies
let appSupportURL = ConfigManager.appSupportURL
let config = try? ConfigManager().load()

let worker = EncodeWorker(
    queueManager: QueueManager(appSupportURL: appSupportURL),
    handbrakeRunner: HandBrakeRunner(binPath: config?.handbrakeBin ?? "HandBrakeCLI"),
    notificationService: NotificationService.shared
)

let sigSrc = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigSrc.setEventHandler { Task { await worker.stop() } }
sigSrc.resume()
signal(SIGTERM, SIG_IGN)

let sigIntSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigIntSrc.setEventHandler { Task { await worker.stop() } }
sigIntSrc.resume()
signal(SIGINT, SIG_IGN)

Task { await worker.start() }
dispatchMain()
