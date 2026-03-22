import DiskArbitration
import Foundation

extension Notification.Name {
    static let vigilDiscInserted = Notification.Name("com.frostscribe.vigilDiscInserted")
}

/// Observes the system for optical disc insertion events via DiskArbitration.
/// Posts `.vigilDiscInserted` on NotificationCenter.default when a supported disc appears.
/// Must be started and stopped on the main thread.
final class VigilWatcher: @unchecked Sendable {
    private var session: DASession?

    func start() {
        guard session == nil else { return }
        let s = DASessionCreate(kCFAllocatorDefault)!
        DASessionScheduleWithRunLoop(s, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        DARegisterDiskAppearedCallback(s, nil, vigilDiskAppearedCallback, Unmanaged.passUnretained(self).toOpaque())
        session = s
    }

    func stop() {
        guard let s = session else { return }
        DASessionUnscheduleFromRunLoop(s, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        session = nil
    }

    fileprivate func isOpticalDisc(_ desc: [CFString: Any]) -> Bool {
        // Must be the whole device (not a partition)
        guard (desc[kDADiskDescriptionMediaWholeKey] as? Bool) == true else { return false }
        // Must be ejectable media
        guard (desc[kDADiskDescriptionMediaEjectableKey] as? Bool) == true else { return false }
        // If media type is present, check for optical formats
        if let type = desc[kDADiskDescriptionMediaTypeKey] as? String {
            return type.hasPrefix("DVD") || type.hasPrefix("BD") || type.hasPrefix("CD-ROM")
        }
        // Blu-ray discs often lack a media type on macOS (no native driver).
        // Accept unmountable ejectable whole discs — MakeMKV will verify support.
        let mountable = desc[kDADiskDescriptionVolumeMountableKey] as? Bool
        return mountable == false || mountable == nil
    }
}

// File-level C-compatible callback — no Swift captures allowed.
private func vigilDiskAppearedCallback(disk: DADisk, context: UnsafeMutableRawPointer?) {
    guard let ctx = context else { return }
    let watcher = Unmanaged<VigilWatcher>.fromOpaque(ctx).takeUnretainedValue()
    guard let desc = DADiskCopyDescription(disk) as? [CFString: Any] else { return }
    guard watcher.isOpticalDisc(desc) else { return }
    NotificationCenter.default.post(name: .vigilDiscInserted, object: nil)
}
