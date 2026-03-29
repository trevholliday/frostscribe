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
            WorkerReinstall.self,
            WorkerStatus.self,
            WorkerHealth.self,
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

struct WorkerReinstall: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reinstall",
        abstract: "Tear down, reinstall, and restart the worker, then open the UI."
    )

    func run() throws {
        Colors.info("Stopping worker...")
        _ = launchctl("bootout", "gui/\(getuid())/\(label)")
        Thread.sleep(forTimeInterval: 0.5)

        let binPath = resolveWorkerBin()
        let logPath = ConfigManager.appSupportURL.appending(path: "worker.log").path

        try FileManager.default.createDirectory(
            at: ConfigManager.appSupportURL,
            withIntermediateDirectories: true
        )

        let plist = buildPlist(binPath: binPath, logPath: logPath)
        try plist.write(to: plistURL, atomically: true, encoding: .utf8)
        Colors.info("Installing plist at \(plistURL.path)...")

        let bootstrap = launchctl("bootstrap", "gui/\(getuid())", plistURL.path)
        guard bootstrap == 0 else {
            Colors.error("Failed to install worker (launchctl exited \(bootstrap)).")
            throw ExitCode.failure
        }

        Colors.info("Starting worker...")
        _ = launchctl("start", label)

        Colors.info("Opening FrostscribeUI...")
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", "FrostscribeUI"]
        try? open.run()

        Colors.success("Reinstall complete.")
    }
}

struct WorkerHealth: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "health",
        abstract: "Show worker health: running state, active job, and recent log lines."
    )

    func run() throws {
        Colors.section("Worker Health")
        print()

        // --- Running state ---
        let checkPid = Process()
        checkPid.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        checkPid.arguments = ["list", label]
        let pipe = Pipe()
        checkPid.standardOutput = pipe
        checkPid.standardError = FileHandle.nullDevice
        try? checkPid.run()
        checkPid.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let pid = out.split(separator: "\t").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? "-"
        let isRunning = pid != "-"

        if isRunning {
            print("  \(Colors.bold)State\(Colors.reset)    \(Colors.frostCyan)running\(Colors.reset) (pid \(pid))")
        } else {
            print("  \(Colors.bold)State\(Colors.reset)    \(Colors.dim)stopped\(Colors.reset)")
        }

        // --- Queue status ---
        let jobs = (try? RipQueueManager(appSupportURL: ConfigManager.appSupportURL).read()) ?? []
        let pending = jobs.filter { $0.status == .pending }.count
        let running = jobs.filter { $0.status == .ripping }.count
        let done    = jobs.filter { $0.status == .done    }.count
        print("  \(Colors.bold)Queue\(Colors.reset)    pending=\(pending)  running=\(running)  done=\(done)")

        // --- Status file ---
        if let file = try? StatusManager(appSupportURL: ConfigManager.appSupportURL).read() {
            var line = "  \(Colors.bold)Status\(Colors.reset)   \(file.status.rawValue)"
            if let job = file.currentJob { line += " — \(job.title) (\(job.progress))" }
            print(line)
        }

        // --- Recent logs ---
        print()
        print("  \(Colors.bold)Recent logs\(Colors.reset)")
        let store = LogStore(appSupportURL: ConfigManager.appSupportURL)
        let entries = store.load(limit: 8)
        if entries.isEmpty {
            print("  \(Colors.dim)(no log entries)\(Colors.reset)")
        } else {
            for e in entries {
                let ts = String(e.timestamp.prefix(19)).replacingOccurrences(of: "T", with: " ")
                let color = e.level == "error" ? Colors.alert : Colors.dim
                print("  \(Colors.dim)\(ts)\(Colors.reset)  \(color)\(e.message)\(Colors.reset)")
            }
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
