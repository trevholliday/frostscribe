import Foundation

public protocol StatusManaging: Sendable {
    func read() throws -> StatusManager.StatusFile
    func write(status: StatusManager.RipperStatus, job: RipJob?) throws
}
