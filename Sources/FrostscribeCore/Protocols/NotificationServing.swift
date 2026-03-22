public protocol NotificationServing: Sendable {
    func requestAuthorizationIfNeeded() async
    func send(title: String, body: String)
}
