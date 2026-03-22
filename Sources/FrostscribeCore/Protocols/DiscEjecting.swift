public protocol DiscEjecting: Sendable {
    @discardableResult
    func eject() -> Bool
}
