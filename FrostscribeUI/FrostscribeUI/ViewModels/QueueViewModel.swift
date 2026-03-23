import Foundation
import FrostscribeCore

@MainActor
@Observable
final class QueueViewModel {
    private(set) var jobs: [EncodeJob] = []

    var activeCount: Int { jobs.filter(\.isActive).count }

    private let queueManager: any QueueManaging
    private var pollTask: Task<Void, Never>?

    init(queueManager: any QueueManaging) {
        self.queueManager = queueManager
    }

    func startPolling() {
        guard pollTask == nil else { return }
        refresh()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                refresh()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() {
        jobs = (try? queueManager.read()) ?? []
    }
}
