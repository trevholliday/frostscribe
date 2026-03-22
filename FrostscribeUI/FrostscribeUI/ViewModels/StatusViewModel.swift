import Foundation
import FrostscribeCore

@MainActor
@Observable
final class StatusViewModel {
    private(set) var file = StatusManager.StatusFile(
        status: .idle, updatedAt: .now, currentJob: nil, history: []
    )

    private let statusManager: any StatusManaging
    private var pollTask: Task<Void, Never>?

    init(statusManager: any StatusManaging) {
        self.statusManager = statusManager
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

    private func refresh() {
        file = (try? statusManager.read()) ?? StatusManager.StatusFile(
            status: .idle, updatedAt: .now, currentJob: nil, history: []
        )
    }
}
