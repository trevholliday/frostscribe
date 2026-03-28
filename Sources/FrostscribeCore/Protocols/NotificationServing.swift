// Retained for source compatibility. Use HookRunner for lifecycle events.
public protocol NotificationServing: Sendable {
    func fire(event: String, title: String, body: String)
}
