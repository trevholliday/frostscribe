import Foundation
import FrostscribeCore

// MARK: - Worker Entry Point

/// Frostscribe encode worker daemon.
///
/// This process is managed by launchd and runs in the background, polling the
/// encode queue and invoking HandBrakeCLI for each pending job.

let worker = EncodeWorker()

// Handle SIGTERM/SIGINT gracefully
let sigSrc = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigSrc.setEventHandler { worker.stop() }
sigSrc.resume()
signal(SIGTERM, SIG_IGN)

let sigIntSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigIntSrc.setEventHandler { worker.stop() }
sigIntSrc.resume()
signal(SIGINT, SIG_IGN)

worker.start()
dispatchMain()
