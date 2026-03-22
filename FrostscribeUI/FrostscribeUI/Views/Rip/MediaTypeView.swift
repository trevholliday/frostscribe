import SwiftUI
import FrostscribeCore

struct MediaTypeView: View {
    let vm: RipFlowViewModel
    let chosenTitle: DiscTitle
    let scanResult: DiscScanResult

    var body: some View {
        VStack(spacing: FrostTheme.paddingL) {
            Spacer()
            Text("What type of media is this?")
                .font(.title3)
                .bold()
            Text(chosenTitle.name)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: FrostTheme.paddingL) {
                MediaCard(label: "Movie", icon: "film",
                          color: FrostTheme.glacier) {
                    vm.selectMediaType(isTV: false, chosenTitle: chosenTitle, scanResult: scanResult)
                }
                MediaCard(label: "TV Show", icon: "tv",
                          color: FrostTheme.frostCyan) {
                    vm.selectMediaType(isTV: true, chosenTitle: chosenTitle, scanResult: scanResult)
                }
            }
            .padding(.top, FrostTheme.paddingM)
            Spacer()
        }
        .padding(FrostTheme.paddingL)
    }
}

private struct MediaCard: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: FrostTheme.spacing) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(color)
                Text(label)
                    .bold()
            }
            .frame(width: 160, height: 120)
            .background(
                RoundedRectangle(cornerRadius: FrostTheme.cornerRadius)
                    .fill(isHovered ? Color.primary.opacity(0.07) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: FrostTheme.cornerRadius)
                            .stroke(isHovered ? color.opacity(0.6) : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
