import ArgumentParser
import FrostscribeCore

struct QueueCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "queue",
        abstract: "Show the encode queue with progress."
    )

    func run() throws {
        // TODO: implement queue display
        print("queue — coming soon")
    }
}
