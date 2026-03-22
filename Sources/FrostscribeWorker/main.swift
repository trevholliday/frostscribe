import Foundation
import FrostscribeCore

let worker = EncodeWorker()

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
