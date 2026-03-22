import Foundation

public enum DiscEjector {
    @discardableResult
    public static func eject() -> Bool {
        for _ in 0..<5 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/drutil")
            process.arguments = ["eject"]
            try? process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 { return true }
            Thread.sleep(forTimeInterval: 2)
        }
        return false
    }
}
