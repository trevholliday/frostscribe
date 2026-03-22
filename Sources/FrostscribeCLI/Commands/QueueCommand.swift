import ArgumentParser
import FrostscribeCore

struct QueueCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "queue",
        abstract: "Show the encode queue."
    )

    func run() throws {
        let manager = QueueManager(appSupportURL: ConfigManager.appSupportURL)

        let jobs: [EncodeJob]
        do {
            jobs = try manager.read()
        } catch {
            Colors.error("Could not read queue: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        Colors.section("Encode Queue")
        print()

        if jobs.isEmpty {
            Colors.info("Queue is empty.")
            print()
            return
        }

        for (i, job) in jobs.enumerated() {
            let index  = "\(Colors.dim)[\(i + 1)]\(Colors.reset)"
            let icon   = statusIcon(job.status)
            let title  = job.label.padding(toLength: 40, withPad: " ", startingAt: 0)
            let status = statusLabel(job.status)
            let progress = job.status == .encoding ? "  \(Colors.brightCyan)\(job.progress)\(Colors.reset)" : ""
            print("  \(index) \(icon) \(title) \(status)\(progress)")
        }

        print()

        let pending  = jobs.filter { $0.status == .pending }.count
        let encoding = jobs.filter { $0.status == .encoding }.count
        let done     = jobs.filter { $0.status == .done }.count
        let failed   = jobs.filter { $0.status == .error }.count

        var summary: [String] = []
        if encoding > 0 { summary.append("\(Colors.brightYellow)\(encoding) encoding\(Colors.reset)") }
        if pending > 0  { summary.append("\(pending) pending") }
        if done > 0     { summary.append("\(Colors.dim)\(done) done\(Colors.reset)") }
        if failed > 0   { summary.append("\(Colors.brightRed)\(failed) failed\(Colors.reset)") }

        print("  \(Colors.dim)\(summary.joined(separator: " · "))\(Colors.reset)")
        print()
    }

    private func statusIcon(_ status: EncodeJob.Status) -> String {
        switch status {
        case .pending:  return "\(Colors.dim)⏳\(Colors.reset)"
        case .encoding: return "\(Colors.brightYellow)⚙\(Colors.reset) "
        case .done:     return "\(Colors.brightGreen)✔\(Colors.reset) "
        case .error:    return "\(Colors.brightRed)✘\(Colors.reset) "
        }
    }

    private func statusLabel(_ status: EncodeJob.Status) -> String {
        switch status {
        case .pending:  return "\(Colors.dim)pending\(Colors.reset) "
        case .encoding: return "\(Colors.brightYellow)encoding\(Colors.reset)"
        case .done:     return "\(Colors.brightGreen)done\(Colors.reset)    "
        case .error:    return "\(Colors.brightRed)error\(Colors.reset)   "
        }
    }
}
