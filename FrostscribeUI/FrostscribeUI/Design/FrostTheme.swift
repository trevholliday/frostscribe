import SwiftUI
import FrostscribeCore

enum FrostTheme {
    // Colors — matching the CLI frost palette (Colors.swift)
    static let frostCyan = Color(.sRGB, red: 0,    green: 0.85, blue: 1,   opacity: 1)
    static let glacier   = Color(.sRGB, red: 0.4,  green: 0.7,  blue: 1,   opacity: 1)
    static let teal      = Color(.sRGB, red: 0,    green: 0.5,  blue: 0.5, opacity: 1)
    static let alert     = Color(.sRGB, red: 1,    green: 0.3,  blue: 0.3, opacity: 1)

    // Layout
    static let paddingS: CGFloat     = 8
    static let paddingM: CGFloat     = 12
    static let paddingL: CGFloat     = 16
    static let spacing: CGFloat      = 8
    static let cornerRadius: CGFloat = 6
    static let popoverWidth: CGFloat = 320
}

// MARK: - Status color

extension StatusManager.RipperStatus {
    var color: Color {
        switch self {
        case .idle:     return .secondary
        case .ripping:  return FrostTheme.teal
        case .encoding: return FrostTheme.glacier
        case .error:    return FrostTheme.alert
        }
    }
}

// MARK: - Progress parsing

extension String {
    /// Converts a progress string like "47%" to a clamped 0–1 fraction.
    var progressFraction: Double {
        let value = Double(replacingOccurrences(of: "%", with: "")) ?? 0
        return min(max(value / 100.0, 0), 1)
    }
}
