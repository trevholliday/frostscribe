import SwiftUI
import FrostscribeCore

enum FrostTheme {
    // Colors — matching the CLI frost palette (Colors.swift)
    static let frostCyan = Color(.sRGB, red: 0,    green: 0.85, blue: 1,   opacity: 1)
    static let glacier   = Color(.sRGB, red: 0.4,  green: 0.7,  blue: 1,   opacity: 1)
    static let teal      = Color(.sRGB, red: 0,    green: 0.5,  blue: 0.5, opacity: 1)
    static let deepBlue  = Color(.sRGB, red: 0.05, green: 0.15, blue: 0.3, opacity: 1)
    static let alert     = Color(.sRGB, red: 1,    green: 0.3,  blue: 0.3, opacity: 1)

    // UI chrome
    static let background  = Color(.sRGB, red: 0.04, green: 0.22, blue: 0.28, opacity: 1)
    static let textPrimary = Color(.sRGB, red: 0.82, green: 0.90, blue: 0.93, opacity: 1)
    static let divider     = Color(.sRGB, red: 0.1,  green: 0.32, blue: 0.38, opacity: 1)

    // Layout
    static let paddingS: CGFloat     = 8
    static let paddingM: CGFloat     = 12
    static let paddingL: CGFloat     = 16
    static let spacing: CGFloat      = 8
    static let cornerRadius: CGFloat = 6
    static let popoverWidth: CGFloat = 320
}

// MARK: - Button styles

struct FrostPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.bold())
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                FrostTheme.frostCyan.opacity(configuration.isPressed ? 0.75 : 1),
                in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius)
            )
    }
}

struct FrostDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                FrostTheme.alert.opacity(configuration.isPressed ? 0.75 : 1),
                in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius)
            )
    }
}

extension ButtonStyle where Self == FrostPrimaryButtonStyle {
    static var frostPrimary: FrostPrimaryButtonStyle { FrostPrimaryButtonStyle() }
}

extension ButtonStyle where Self == FrostDestructiveButtonStyle {
    static var frostDestructive: FrostDestructiveButtonStyle { FrostDestructiveButtonStyle() }
}

// MARK: - Text field style

extension FrostTheme {
    static let inputBackground = Color(.sRGB, red: 0.22, green: 0.22, blue: 0.24, opacity: 1)
}

struct FrostTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(FrostTheme.inputBackground, in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FrostTheme.cornerRadius)
                    .stroke(FrostTheme.divider, lineWidth: 1)
            )
    }
}

extension TextFieldStyle where Self == FrostTextFieldStyle {
    static var frost: FrostTextFieldStyle { FrostTextFieldStyle() }
}

// MARK: - Shared input container modifier

struct FrostInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(FrostTheme.inputBackground, in: RoundedRectangle(cornerRadius: FrostTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FrostTheme.cornerRadius)
                    .stroke(FrostTheme.divider, lineWidth: 1)
            )
    }
}

extension View {
    func frostInputStyle() -> some View {
        modifier(FrostInputModifier())
    }
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
