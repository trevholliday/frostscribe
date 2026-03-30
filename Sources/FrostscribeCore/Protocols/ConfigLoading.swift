import Foundation

public protocol ConfigLoading: Sendable {
    func load() throws -> Config
}
