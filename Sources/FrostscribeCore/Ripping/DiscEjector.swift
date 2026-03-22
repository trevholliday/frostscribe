import Foundation

/// Ejects the optical disc drive using drutil.
public enum DiscEjector {
    /// Attempts to eject the disc, retrying up to 5 times with a 2 second delay.
    /// Returns true if ejection succeeded, false if all attempts failed.
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
