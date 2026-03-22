import Foundation

/// Renders ASCII progress bars and spinners in the terminal.
public enum ProgressBar {
    private static let spinner = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]

    /// Renders a progress bar string at the given percentage (0–100).
    public static func bar(percent: Int, width: Int = 20) -> String {
        let filled = min(percent * width / 100, width)
        let empty  = width - filled
        return "\(Colors.cyan)\(String(repeating: "█", count: filled))\(Colors.dim)\(String(repeating: "░", count: empty))\(Colors.reset)"
    }

    /// Returns the next spinner frame for a given tick index.
    public static func spin(_ tick: Int) -> String {
        spinner[tick % spinner.count]
    }

    /// Prints an in-place rip progress line.
    public static func printRip(percent: Int, message: String, tick: Int) {
        let spin = spin(tick)
        let bar  = bar(percent: percent)
        print("\r  \(Colors.brightCyan)\(spin) Ripping  \(Colors.reset)\(Colors.cyan)[\(bar)]\(Colors.reset) \(Colors.bold)\(percent)%\(Colors.reset)  \(Colors.dim)\(message.prefix(45))\(Colors.reset)        ", terminator: "")
        fflush(stdout)
    }
}
