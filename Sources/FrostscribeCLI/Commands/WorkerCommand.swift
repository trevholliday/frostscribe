import ArgumentParser
import Foundation
import FrostscribeCore

private let label    = "com.frostscribe.worker"
private let plistURL = FileManager.default
    .homeDirectoryForCurrentUser
    .appending(path: "Library/LaunchAgents/\(label).plist")

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

    @Flag(name: .shortAndLong, help: "Show detailed output.")
    var verbose = false

    func run() throws {
        let binPath = resolveWorkerBin()
        let logPath = ConfigManager.appSupportURL.appending(path: "worker.log").path

        try FileManager.default.createDirectory(
            at: ConfigManager.appSupportURL,
            withIntermediateDirectories: true
        )

        let plist = buildPlist(binPath: binPath, logPath: logPath)
        try plist.write(to: plistURL, atomically: true, encoding: .utf8)

        if verbose {
            Colors.verbose("Plist: \(plistURL.path)")
            Colors.verbose("Worker bin: \(binPath)")
            Colors.verbose("Running: launchctl bootstrap gui/\(getuid()) \(plistURL.path)")
        }

        let result = launchctl("bootstrap", "gui/\(getuid())", plistURL.path)
        if result == 0 {
            Colors.success("Worker started.")
            Colors.info("Logs: \(logPath)")
        } else {
            Colors.error("Failed to start worker (launchctl exited \(result)).")
            throw ExitCode.failure
        }
    }
}

struct WorkerStop: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop and remove the encode worker agent."
    )

    @Flag(name: .shortAndLong, help: "Show detailed output.")
    var verbose = false

    func run() throws {
        if verbose {
            Colors.verbose("Running: launchctl bootout gui/\(getuid())/\(label)")
        }

        let result = launchctl("bootout", "gui/\(getuid())/\(label)")
        try? FileManager.default.removeItem(at: plistURL)

        if result == 0 {
            Colors.success("Worker stopped.")
        } else {
            Colors.error("Failed to stop worker (launchctl exited \(result)).")
            throw ExitCode.failure
        }
    }
}

struct WorkerRestart: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restart",
        abstract: "Restart the encode worker."
    )

    @Flag(name: .shortAndLong, help: "Show detailed output.")
    var verbose = false

    func run() throws {
        if verbose { Colors.verbose("Running: launchctl bootout gui/\(getuid())/\(label)") }
        _ = launchctl("bootout", "gui/\(getuid())/\(label)")
        Thread.sleep(forTimeInterval: 1)
        if verbose { Colors.verbose("Running: launchctl bootstrap gui/\(getuid()) \(plistURL.path)") }
        let result = launchctl("bootstrap", "gui/\(getuid())", plistURL.path)

        if result == 0 {
            Colors.success("Worker restarted.")
        } else {
            Colors.error("Failed to restart worker (launchctl exited \(result)).")
            throw ExitCode.failure
        }
    }
}

struct WorkerStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show whether the worker is running."
    )

    @Flag(name: .shortAndLong, help: "Show detailed output.")
    var verbose = false

    func run() throws {
        Colors.section("Worker Status")
        print()

        if verbose { Colors.verbose("Running: launchctl print gui/\(getuid())/\(label)") }
        let running = launchctl("print", "gui/\(getuid())/\(label)") == 0
        let logPath = ConfigManager.appSupportURL.appending(path: "worker.log").path

        if running {
            print("  \(Colors.bold)State\(Colors.reset)   \(Colors.frostCyan)running\(Colors.reset)")
        } else {
            print("  \(Colors.bold)State\(Colors.reset)   \(Colors.dim)stopped\(Colors.reset)")
        }

        print("  \(Colors.bold)Label\(Colors.reset)   \(Colors.dim)\(label)\(Colors.reset)")
        print("  \(Colors.bold)Plist\(Colors.reset)   \(Colors.dim)\(plistURL.path)\(Colors.reset)")
        print("  \(Colors.bold)Logs\(Colors.reset)    \(Colors.dim)\(logPath)\(Colors.reset)")
        print()

        if running {
            Colors.info("Run \(Colors.bold)frostscribe queue\(Colors.reset) to see active encode jobs.")
        } else {
            Colors.info("Run \(Colors.bold)frostscribe worker start\(Colors.reset) to start the worker.")
        }
        print()
    }
}

// MARK: - Helpers

@discardableResult
private func launchctl(_ args: String...) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = args
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    return process.terminationStatus
}

private func resolveWorkerBin() -> String {
    let sibling = URL(fileURLWithPath: CommandLine.arguments[0])
        .deletingLastPathComponent()
        .appending(path: "frostscribe-worker")
        .path

    if FileManager.default.fileExists(atPath: sibling) { return sibling }

    for path in ["/opt/homebrew/bin/frostscribe-worker", "/usr/local/bin/frostscribe-worker"] {
        if FileManager.default.fileExists(atPath: path) { return path }
    }

    return sibling
}

private func buildPlist(binPath: String, logPath: String) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>\(label)</string>
        <key>ProgramArguments</key>
        <array>
            <string>\(binPath)</string>
        </array>
        <key>RunAtLoad</key>
        <false/>
        <key>KeepAlive</key>
        <false/>
        <key>StandardOutPath</key>
        <string>\(logPath)</string>
        <key>StandardErrorPath</key>
        <string>\(logPath)</string>
    </dict>
    </plist>
    """
}
