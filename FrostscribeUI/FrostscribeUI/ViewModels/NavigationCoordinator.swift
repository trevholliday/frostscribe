import Foundation

enum AppSection: Hashable {
    case rip
    case encodeQueue
    case history
    case logs
    case settings

    var label: String {
        switch self {
        case .rip:         return "Rip"
        case .encodeQueue: return "Encode Queue"
        case .history:     return "History"
        case .logs:        return "Logs"
        case .settings:    return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .rip:         return "opticaldisc"
        case .encodeQueue: return "list.bullet"
        case .history:     return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .logs:        return "doc.text"
        case .settings:    return "gear"
        }
    }
}

@MainActor
@Observable
final class NavigationCoordinator {
    var selectedSection: AppSection = .rip
}
