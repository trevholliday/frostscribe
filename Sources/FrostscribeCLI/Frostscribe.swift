import ArgumentParser

@main
struct Frostscribe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "frostscribe",
        abstract: "A native macOS tool for ripping and preserving disc media.",
        version: "0.1.0",
        subcommands: [
            InitCommand.self,
            RipCommand.self,
            StatusCommand.self,
            QueueCommand.self,
            RipQueueCommand.self,
            WorkerCommand.self,
            ExportTrainingDataCommand.self,
        ]
    )
}
