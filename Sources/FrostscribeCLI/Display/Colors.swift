import Foundation

public enum Colors {
    public static let reset     = "\u{001B}[0m"
    public static let bold      = "\u{001B}[1m"
    public static let dim       = "\u{001B}[2m"

    // Frost palette — derived from the Frostscribe snowflake icon
    public static let iceWhite  = "\u{001B}[97m"  // brightest tip highlights
    public static let frostCyan = "\u{001B}[96m"  // primary snowflake color
    public static let teal      = "\u{001B}[36m"  // mid-tone teal, success states
    public static let glacier   = "\u{001B}[94m"  // bright blue, deeper tones
    public static let midnight  = "\u{001B}[34m"  // darkest blue

    // Extended palette
    public static let orange    = "\u{001B}[33m"  // warnings / caution
    public static let grey      = "\u{001B}[37m"  // subtle / muted
    public static let red       = "\u{001B}[31m"  // negatives
    public static let alert     = "\u{001B}[91m"  // bright red, errors

    public static func info(_ msg: String)    { print("\(frostCyan)  ›\(reset) \(msg)") }
    public static func success(_ msg: String) { print("\(teal)  ✔\(reset) \(bold)\(msg)\(reset)") }
    public static func error(_ msg: String)   { print("\(alert)  ✘\(reset) \(alert)\(msg)\(reset)") }
    public static func section(_ msg: String) { print("\n\(bold)\(glacier)  ══ \(msg) ══\(reset)") }
    public static func verbose(_ msg: String) { print("\(dim)  · \(msg)\(reset)") }

    public static func banner() {
        print("""
        \(frostCyan)\(bold)
          ███████╗██████╗  ██████╗ ███████╗████████╗███████╗ ██████╗██████╗ ██╗██████╗ ███████╗
          ██╔════╝██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝██╔════╝██╔════╝██╔══██╗██║██╔══██╗██╔════╝
          █████╗  ██████╔╝██║   ██║███████╗   ██║   ███████╗██║     ██████╔╝██║██████╔╝█████╗
          ██╔══╝  ██╔══██╗██║   ██║╚════██║   ██║   ╚════██║██║     ██╔══██╗██║██╔══██╗██╔══╝
          ██║     ██║  ██║╚██████╔╝███████║   ██║   ███████║╚██████╗██║  ██║██║██████╔╝███████╗
          ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═════╝ ╚══════╝\(reset)\(dim)
          native macOS disc ripper & encoder\(reset)
        """)
    }
}
