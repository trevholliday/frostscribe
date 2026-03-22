import Foundation

enum Prompt {

    @discardableResult
    static func ask(_ label: String, default defaultValue: String? = nil) -> String {
        while true {
            if let def = defaultValue {
                print("  \(Colors.frostCyan)›\(Colors.reset) \(label) \(Colors.dim)(\(def))\(Colors.reset): ", terminator: "")
            } else {
                print("  \(Colors.frostCyan)›\(Colors.reset) \(label): ", terminator: "")
            }
            fflush(stdout)

            let input = readLine(strippingNewline: true) ?? ""
            let trimmed = input.trimmingCharacters(in: .whitespaces)

            if !trimmed.isEmpty { return trimmed }
            if let def = defaultValue { return def }
            Colors.error("This field is required.")
        }
    }

    static func confirm(_ label: String, default defaultValue: Bool = true) -> Bool {
        let hint = defaultValue ? "Y/n" : "y/N"
        print("  \(Colors.frostCyan)›\(Colors.reset) \(label) \(Colors.dim)[\(hint)]\(Colors.reset): ", terminator: "")
        fflush(stdout)

        let input = (readLine(strippingNewline: true) ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        if input.isEmpty { return defaultValue }
        return input == "y" || input == "yes"
    }

    static func pick<T: CustomStringConvertible>(_ label: String, options: [T], default defaultIndex: Int = 0) -> T {
        print("  \(Colors.frostCyan)›\(Colors.reset) \(label):")
        for (i, option) in options.enumerated() {
            let marker = i == defaultIndex ? Colors.frostCyan + "  ❯" + Colors.reset : "   "
            print("\(marker) \(Colors.dim)[\(i + 1)]\(Colors.reset) \(option)")
        }
        while true {
            print("  \(Colors.frostCyan)›\(Colors.reset) Enter number \(Colors.dim)(default: \(defaultIndex + 1))\(Colors.reset): ", terminator: "")
            fflush(stdout)
            let input = (readLine(strippingNewline: true) ?? "").trimmingCharacters(in: .whitespaces)
            if input.isEmpty { return options[defaultIndex] }
            if let n = Int(input), n >= 1, n <= options.count { return options[n - 1] }
            Colors.error("Enter a number between 1 and \(options.count).")
        }
    }
}
