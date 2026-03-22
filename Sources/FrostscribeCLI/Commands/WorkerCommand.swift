import ArgumentParser
import FrostscribeCore

struct WorkerCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "worker",
        abstract: "Manage the Frostscribe encode worker launchd agent.",
        subcommands: [
            WorkerStart.self,
            WorkerStop.self,
            WorkerRestart.self,
            WorkerStatus.self,
        ]
    )
}

struct WorkerStart: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Install and start the encode worker."
    )
    func run() throws {
        // TODO: write plist and launchctl load
        print("worker start — coming soon")
    }
}

struct WorkerStop: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop and uninstall the encode worker."
    )
    func run() throws {
        // TODO: launchctl unload and remove plist
        print("worker stop — coming soon")
    }
}

struct WorkerRestart: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restart",
        abstract: "Restart the encode worker."
    )
    func run() throws {
        // TODO: launchctl unload then load
        print("worker restart — coming soon")
    }
}

struct WorkerStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show whether the worker is running and its current job."
    )
    func run() throws {
        // TODO: launchctl list + read status.json
        print("worker status — coming soon")
    }
}
