import Foundation

enum AppSection: Hashable, CaseIterable {
    case rip
    case ripJob
    case encodeQueue
    case history
    case logs

    var label: String {
        switch self {
        case .rip:         return "Rip"
        case .ripJob:      return "Rip Job"
        case .encodeQueue: return "Encode Queue"
        case .history:     return "History"
        case .logs:        return "Logs"
        }
    }

    var icon: String {
        switch self {
        case .rip:         return "opticaldisc"
        case .ripJob:      return "waveform"
        case .encodeQueue: return "list.bullet"
        case .history:     return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .logs:        return "doc.text"
        }
    }
}

@MainActor
@Observable
final class NavigationCoordinator {
    var selectedSection: AppSection? = .rip
}
