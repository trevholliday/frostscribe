import Foundation

public enum ProgressBar {
    private static let spinner = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]

    public static func bar(percent: Int, width: Int = 20) -> String {
        let filled = min(percent * width / 100, width)
        let empty  = width - filled
        return "\(Colors.cyan)\(String(repeating: "█", count: filled))\(Colors.dim)\(String(repeating: "░", count: empty))\(Colors.reset)"
    }

    public static func spin(_ tick: Int) -> String {
        spinner[tick % spinner.count]
    }

    public static func printRip(percent: Int, message: String, tick: Int) {
        let spin = spin(tick)
        let bar  = bar(percent: percent)
        print("\r  \(Colors.brightCyan)\(spin) Ripping  \(Colors.reset)\(Colors.cyan)[\(bar)]\(Colors.reset) \(Colors.bold)\(percent)%\(Colors.reset)  \(Colors.dim)\(message.prefix(45))\(Colors.reset)        ", terminator: "")
        fflush(stdout)
    }
}
