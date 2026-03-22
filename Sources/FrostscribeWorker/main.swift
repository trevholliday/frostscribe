import Foundation
import FrostscribeCore

let worker = EncodeWorker()

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
