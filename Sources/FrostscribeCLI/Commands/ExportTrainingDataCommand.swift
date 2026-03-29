import ArgumentParser
import Foundation
import FrostscribeCore

struct ExportTrainingDataCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export-training-data",
        abstract: "Export title selection history as CSV for Create ML training."
    )

    @Option(name: .shortAndLong, help: "Output path for the CSV file. Defaults to ~/Desktop.")
    var output: String?

    func run() throws {
        let store = TitleSelectionStore(appSupportURL: ConfigManager.appSupportURL)
        let records = store.load()

        guard !records.isEmpty else {
            Colors.error("No title selection data recorded yet. Rip some discs first.")
            throw ExitCode.failure
        }

        let destURL: URL
        if let output {
            destURL = URL(fileURLWithPath: (output as NSString).expandingTildeInPath)
        } else {
            let filename = "frostscribe_training_\(Int(Date().timeIntervalSince1970)).csv"
            destURL = URL(fileURLWithPath: NSHomeDirectory())
                .appending(path: "Desktop/\(filename)")
        }

        let exported = try store.exportCSV(to: destURL)

        let events = Dictionary(grouping: records, by: \.selectionId).count
        Colors.success("Exported \(records.count) rows (\(events) selection events) → \(exported.path)")
        Colors.info("Open in Create ML → New Project → Tabular Classifier → target column: \(Colors.bold)is_selected\(Colors.reset)")
    }
}
