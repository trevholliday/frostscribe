import SwiftUI
import FrostscribeCore

struct MenuBarIcon: View {
    let status: StatusManager.RipperStatus

    var body: some View {
        Image(systemName: symbolName)
            .foregroundStyle(iconColor)
            .symbolEffect(.pulse, isActive: isAnimating)
    }

    private var symbolName: String {
        switch status {
        case .idle:     return "snowflake"
        case .ripping:  return "opticaldisc"
        case .encoding: return "film.stack"
        case .error:    return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color { status.color }

    private var isAnimating: Bool {
        status == .ripping || status == .encoding
    }
}
