import ArgumentParser
import FrostscribeCore

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show the current ripper status."
    )

    func run() throws {
        let manager = StatusManager(appSupportURL: ConfigManager.appSupportURL)

        let file: StatusManager.StatusFile
        do {
            file = try manager.read()
        } catch {
            Colors.error("Could not read status: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        Colors.section("Frostscribe Status")
        print()

        let statusLabel: String
        switch file.status {
        case .idle:     statusLabel = "\(Colors.dim)idle\(Colors.reset)"
        case .ripping:  statusLabel = "\(Colors.brightCyan)ripping\(Colors.reset)"
        case .encoding: statusLabel = "\(Colors.brightYellow)encoding\(Colors.reset)"
        case .error:    statusLabel = "\(Colors.brightRed)error\(Colors.reset)"
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
            for job in file.history.prefix(5) {
                print("  \(Colors.dim)  · \(job.title)\(Colors.reset)")
            }
        }

        print()
    }
}
