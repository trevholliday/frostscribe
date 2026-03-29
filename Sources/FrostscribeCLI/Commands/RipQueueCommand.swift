import ArgumentParser
import Foundation
import FrostscribeCore

struct RipQueueCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rip-queue",
        abstract: "Inspect and manage the rip queue.",
        subcommands: [
            RipQueueList.self,
            RipQueueClear.self,
            RipQueueResetStuck.self,
        ],
        defaultSubcommand: RipQueueList.self
    )
}

// MARK: - list

struct RipQueueList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Show all jobs in the rip queue."
    )

    func run() throws {
        let queue = RipQueueManager(appSupportURL: ConfigManager.appSupportURL)
        let jobs = (try? queue.read()) ?? []

        Colors.section("Rip Queue")
        print()

        if jobs.isEmpty {
            Colors.info("Rip queue is empty.")
            print()
            return
        }

        for job in jobs {
            let icon: String
            let statusColor: String
            switch job.status {
            case .pending:   icon = "⏳"; statusColor = Colors.dim
            case .ripping:   icon = "⚙ "; statusColor = Colors.frostCyan
            case .done:      icon = "✔ "; statusColor = Colors.glacier
            case .error:     icon = "✘ "; statusColor = Colors.alert
            case .cancelled: icon = "⊘ "; statusColor = Colors.orange
            }
            let label = job.encodeTitle.isEmpty ? job.jobLabel : job.encodeTitle
            print("  \(statusColor)\(icon)\(Colors.reset) \(statusColor)\(job.status.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0))\(Colors.reset) \(label)")
            if job.status == .error, let msg = job.errorMessage {
                Colors.verbose("  \(msg)")
            }
        }

        print()
        let pending   = jobs.filter { $0.status == .pending   }.count
        let ripping   = jobs.filter { $0.status == .ripping   }.count
        let done      = jobs.filter { $0.status == .done      }.count
        let errors    = jobs.filter { $0.status == .error     }.count
        let cancelled = jobs.filter { $0.status == .cancelled }.count
        var parts: [String] = []
        if ripping   > 0 { parts.append("\(Colors.frostCyan)\(ripping) ripping\(Colors.reset)") }
        if pending   > 0 { parts.append("\(pending) pending") }
        if done      > 0 { parts.append("\(Colors.glacier)\(done) done\(Colors.reset)") }
        if errors    > 0 { parts.append("\(Colors.alert)\(errors) error\(Colors.reset)") }
        if cancelled > 0 { parts.append("\(Colors.orange)\(cancelled) cancelled\(Colors.reset)") }
        print("  \(Colors.dim)\(parts.joined(separator: " · "))\(Colors.reset)")
        print()
    }
}

// MARK: - clear

struct RipQueueClear: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Remove all done and error jobs, keeping pending and active rips."
    )

    func run() throws {
        let queue = RipQueueManager(appSupportURL: ConfigManager.appSupportURL)
        let before = (try? queue.read())?.count ?? 0
        try queue.removeTerminal()
        let after  = (try? queue.read())?.count ?? 0
        let removed = before - after
        Colors.success("Cleared \(removed) terminal job(s). \(after) job(s) remain.")
    }
}

// MARK: - reset-stuck

struct RipQueueResetStuck: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reset-stuck",
        abstract: "Reset any jobs stuck in 'ripping' state back to 'pending' so the worker retries them."
    )

    func run() throws {
        let queue = RipQueueManager(appSupportURL: ConfigManager.appSupportURL)
        let count = try queue.resetStuck()
        if count > 0 {
            Colors.success("Reset \(count) stuck job(s) to pending.")
        } else {
            Colors.info("No stuck jobs found.")
        }
    }
}
