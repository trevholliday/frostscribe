import ArgumentParser
import FrostscribeCore

struct RipCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rip",
        abstract: "Start an interactive disc ripping session."
    )

    func run() throws {
        // TODO: implement interactive rip flow
        print("rip — coming soon")
    }
}
