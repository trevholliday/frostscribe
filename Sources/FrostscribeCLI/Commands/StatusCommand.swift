import ArgumentParser
import FrostscribeCore

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show or reset the current ripper status.",
        subcommands: [StatusShow.self, StatusReset.self],
        defaultSubcommand: StatusShow.self
    )
}

struct StatusReset: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reset",
        abstract: "Force status back to idle (use when the UI is stuck after a crash)."
    )

    func run() throws {
        let manager = StatusManager(appSupportURL: ConfigManager.appSupportURL)
        try manager.write(status: .idle, job: nil)
        Colors.success("Status reset to idle.")
    }
}

struct StatusShow: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show the current ripper status."
    )

    @Flag(name: .shortAndLong, help: "Show detailed output.")
    var verbose = false

    func run() throws {
        let manager = StatusManager(appSupportURL: ConfigManager.appSupportURL)

        let file: StatusManager.StatusFile
        do {
            file = try manager.read()
        } catch {
            Colors.error("Could not read status: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        Colors.banner()
        Colors.section("Status")
        print()

        if verbose {
            Colors.verbose("App Support: \(ConfigManager.appSupportURL.path)")
        }

        let statusLabel: String
        switch file.status {
        case .idle:     statusLabel = "\(Colors.dim)idle\(Colors.reset)"
        case .ripping:  statusLabel = "\(Colors.frostCyan)ripping\(Colors.reset)"
        case .encoding: statusLabel = "\(Colors.frostCyan)encoding\(Colors.reset)"
        case .error:    statusLabel = "\(Colors.alert)error\(Colors.reset)"
        }

        print("  \(Colors.bold)Status\(Colors.reset)      \(statusLabel)")

        if let job = file.currentJob {
            print("  \(Colors.bold)Title\(Colors.reset)       \(job.title)")
            print("  \(Colors.bold)Phase\(Colors.reset)       \(job.phase.rawValue)")
            print("  \(Colors.bold)Progress\(Colors.reset)    \(job.progress)")
            if let item = job.currentItem {
                print("  \(Colors.bold)Current\(Colors.reset)     \(Colors.dim)\(item)\(Colors.reset)")
            }
        }

        if !file.history.isEmpty {
            print()
            print("  \(Colors.dim)Recent\(Colors.reset)")
            let historyItems = verbose ? file.history : Array(file.history.prefix(5))
            for job in historyItems {
                if verbose {
                    print("  \(Colors.dim)  · \(job.title) [\(job.type.rawValue)] — \(job.phase.rawValue)\(Colors.reset)")
                } else {
                    print("  \(Colors.dim)  · \(job.title)\(Colors.reset)")
                }
            }
        }

        print()
    }
}
