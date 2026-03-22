import Foundation

public enum Colors {
    public static let reset         = "\u{001B}[0m"
    public static let bold          = "\u{001B}[1m"
    public static let dim           = "\u{001B}[2m"
    public static let cyan          = "\u{001B}[36m"
    public static let brightCyan    = "\u{001B}[96m"
    public static let green         = "\u{001B}[32m"
    public static let brightGreen   = "\u{001B}[92m"
    public static let red           = "\u{001B}[31m"
    public static let brightRed     = "\u{001B}[91m"
    public static let yellow        = "\u{001B}[33m"
    public static let brightYellow  = "\u{001B}[93m"
    public static let blue          = "\u{001B}[34m"
    public static let brightBlue    = "\u{001B}[94m"
    public static let white         = "\u{001B}[97m"
    public static let magenta       = "\u{001B}[35m"
    public static let brightMagenta = "\u{001B}[95m"

    public static func info(_ msg: String)    { print("\(brightCyan)  ›\(reset) \(msg)") }
    public static func success(_ msg: String) { print("\(brightGreen)  ✔\(reset) \(bold)\(msg)\(reset)") }
    public static func error(_ msg: String)   { print("\(brightRed)  ✘\(reset) \(brightRed)\(msg)\(reset)") }
    public static func section(_ msg: String) { print("\n\(bold)\(brightBlue)  ══ \(msg) ══\(reset)") }
}
