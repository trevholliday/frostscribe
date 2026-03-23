import Foundation
import FrostscribeCore

/// Watches the frostscribe app-support directory for changes to status.json and queue.json
/// using a DispatchSource VNODE watch on the directory. Atomic writes (replaceItemAt) change
/// the inode, so we watch the directory rather than individual file descriptors.
// @unchecked Sendable: mutable state (source, fd, mtimes) is only ever touched
// on the private serial `queue`, except for the main-queue callbacks which are
// value captures — no shared mutable state crosses queue boundaries.
final class AppSupportWatcher: @unchecked Sendable {
    private let dirURL: URL
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private let queue = DispatchQueue(label: "com.frostscribe.appSupportWatcher", qos: .utility)

    private var lastStatusMTime: Date?
    private var lastQueueMTime: Date?

    var onStatusChange: (() -> Void)?
    var onQueueChange: (() -> Void)?

    init(dirURL: URL = ConfigManager.appSupportURL) {
        self.dirURL = dirURL
    }

    func start() {
        fd = open(dirURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: queue
        )

        src.setEventHandler { [weak self] in self?.handleEvent() }
        src.setCancelHandler { [weak self] in
            guard let self, self.fd >= 0 else { return }
            close(self.fd)
            self.fd = -1
        }

        source = src
        src.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func handleEvent() {
        let statusURL = dirURL.appending(path: "status.json")
        let queueURL  = dirURL.appending(path: "queue.json")

        let statusMTime = mtime(of: statusURL)
        let queueMTime  = mtime(of: queueURL)

        var statusChanged = false
        var queueChanged  = false

        if let m = statusMTime, m != lastStatusMTime {
            lastStatusMTime = m
            statusChanged = true
        }
        if let m = queueMTime, m != lastQueueMTime {
            lastQueueMTime = m
            queueChanged = true
        }

        if statusChanged || queueChanged {
            DispatchQueue.main.async { [weak self] in
                if statusChanged { self?.onStatusChange?() }
                if queueChanged  { self?.onQueueChange?() }
            }
        }
    }

    private func mtime(of url: URL) -> Date? {
        var st = stat()
        guard stat(url.path, &st) == 0 else { return nil }
        return Date(timeIntervalSince1970: Double(st.st_mtimespec.tv_sec))
    }
}
