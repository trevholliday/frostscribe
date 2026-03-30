import Foundation

public protocol RipQueueManaging: Sendable {
    func read() throws -> [RipQueueJob]
    func add(_ job: RipQueueJob) throws
    func markCancelled(id: String) throws
}
