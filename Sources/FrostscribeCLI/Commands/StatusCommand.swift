import ArgumentParser
import FrostscribeCore

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show current rip and encode status."
    )

    func run() throws {
        // TODO: implement status display
        print("status — coming soon")
    }
}
