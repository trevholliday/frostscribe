import Foundation

/// Runs a user-configured shell command when a lifecycle event occurs.
/// The command receives event details via environment variables:
///   FROSTSCRIBE_EVENT — rip_complete | encode_complete | encode_failed
///   FROSTSCRIBE_TITLE — short notification title
///   FROSTSCRIBE_BODY  — full job label / detail
public struct HookRunner: Sendable {
    private let command: String

    public init(command: String) {
        self.command = command
    }

    public var isConfigured: Bool { !command.trimmingCharacters(in: .whitespaces).isEmpty }

    public func fire(event: String, title: String, body: String) {
        guard isConfigured else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        var env = ProcessInfo.processInfo.environment
        env["FROSTSCRIBE_EVENT"] = event
        env["FROSTSCRIBE_TITLE"] = title
        env["FROSTSCRIBE_BODY"]  = body
        process.environment = env
        try? process.run()
        // Fire and forget — don't block on hook completion
    }
}
