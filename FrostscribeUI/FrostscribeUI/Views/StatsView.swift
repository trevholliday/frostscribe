import SwiftUI
import FrostscribeCore

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = StatsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: FrostTheme.paddingL) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                // Row 1 — 3 cards
                HStack(spacing: FrostTheme.paddingM) {
                    totalRipsCard
                    dataRippedCard
                    avgTimeCard
                }

                // Row 2 — 2 cards
                HStack(spacing: FrostTheme.paddingM) {
                    fastestRipCard
                    discBreakdownCard
                }
                .padding(.horizontal, cardPyramidInset(row: 1, rows: 4))

                // Row 3 — 2 success rate cards
                HStack(spacing: FrostTheme.paddingM) {
                    ripSuccessCard
                    encodeSuccessCard
                }
                .padding(.horizontal, cardPyramidInset(row: 2, rows: 4))

                // Row 4 — 2 ML cards
                HStack(spacing: FrostTheme.paddingM) {
                    selectionsRecordedCard
                    suggestionAccuracyCard
                }
                .padding(.horizontal, cardPyramidInset(row: 3, rows: 4))
            }
            .padding(FrostTheme.paddingL)
        }
        .background(FrostTheme.background)
        .foregroundStyle(FrostTheme.textPrimary)
        .colorScheme(.dark)
        .onAppear { vm.load() }
    }

    // MARK: - Cards

    private var totalRipsCard: some View {
        StatCard(
            icon: "opticaldisc",
            iconColor: FrostTheme.frostCyan,
            label: "Total Rips",
            value: "\(vm.totalRips)",
            detail: vm.totalRips == 1 ? "disc ripped" : "discs ripped"
        )
    }

    private var dataRippedCard: some View {
        let (value, unit) = formatData(vm.dataRippedGB)
        return StatCard(
            icon: "internaldrive",
            iconColor: FrostTheme.teal,
            label: "Data Ripped",
            value: value,
            detail: unit
        )
    }

    private var avgTimeCard: some View {
        StatCard(
            icon: "timer",
            iconColor: FrostTheme.glacier,
            label: "Avg Rip Time",
            value: formatMinutes(vm.avgRipMinutes),
            detail: "per disc"
        )
    }

    private var fastestRipCard: some View {
        StatCard(
            icon: "bolt.fill",
            iconColor: .yellow,
            label: "Fastest Rip",
            value: formatMinutes(vm.fastestMinutes),
            detail: vm.fastestLabel.isEmpty ? "—" : vm.fastestLabel,
            detailLineLimit: 1
        )
    }

    private var discBreakdownCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FrostTheme.paddingS) {
                cardHeader(icon: "square.stack.3d.up", color: FrostTheme.deepBlue, label: "Disc Types")
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 6) {
                    discTypeRow("Blu-ray",  count: vm.breakdown.bluray, color: FrostTheme.frostCyan)
                    discTypeRow("DVD",      count: vm.breakdown.dvd,    color: FrostTheme.teal)
                    discTypeRow("UHD 4K",   count: vm.breakdown.uhd,    color: .purple)
                }
            }
            .padding(FrostTheme.paddingM)
        }
    }

    private var selectionsRecordedCard: some View {
        StatCard(
            icon: "brain",
            iconColor: .purple,
            label: "Training Samples",
            value: "\(vm.selectionEvents)",
            detail: vm.titlesRecorded == 0
                ? "no data yet"
                : "\(vm.titlesRecorded) titles recorded"
        )
    }

    private var suggestionAccuracyCard: some View {
        StatCard(
            icon: "sparkles",
            iconColor: .yellow,
            label: "Suggestion Accuracy",
            value: vm.selectionEvents == 0 ? "—" : String(format: "%.0f%%", vm.suggestionAccuracy),
            detail: vm.selectionEvents == 0
                ? "no selections yet"
                : "\(vm.suggestionMatchCount) of \(vm.selectionEvents) correct"
        )
    }

    private var ripSuccessCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FrostTheme.paddingS) {
                cardHeader(icon: "opticaldisc.fill", color: FrostTheme.teal, label: "Rip Success")
                Spacer(minLength: 0)
                Text(vm.totalAttempts == 0 ? "—" : String(format: "%.0f%%", vm.successRate))
                    .font(.system(size: 45, weight: .bold, design: .rounded))
                    .foregroundStyle(rateColor(vm.successRate, hasData: vm.totalAttempts > 0))
                HStack(spacing: 4) {
                    statPill("\(vm.totalRips) ok", color: FrostTheme.teal)
                    statPill("\(vm.totalAttempts - vm.totalRips) failed", color: .red.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FrostTheme.paddingM)
        }
    }

    private var encodeSuccessCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FrostTheme.paddingS) {
                cardHeader(icon: "arrow.trianglehead.2.clockwise.rotate.90", color: FrostTheme.glacier, label: "Encode Success")
                Spacer(minLength: 0)
                Text(vm.totalEncodes == 0 ? "—" : String(format: "%.0f%%", vm.encodeSuccessRate))
                    .font(.system(size: 45, weight: .bold, design: .rounded))
                    .foregroundStyle(rateColor(vm.encodeSuccessRate, hasData: vm.totalEncodes > 0))
                HStack(spacing: 4) {
                    statPill("\(vm.totalEncodes - vm.encodeErrors) ok", color: FrostTheme.glacier)
                    statPill("\(vm.encodeErrors) failed", color: .red.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FrostTheme.paddingM)
        }
    }

    // MARK: - Helpers

    private func discTypeRow(_ label: String, count: Int, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 19))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 19, weight: .bold).monospacedDigit())
                .foregroundStyle(count > 0 ? AnyShapeStyle(color) : AnyShapeStyle(.tertiary))
        }
    }

    private func statPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func cardHeader(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    private func rateColor(_ rate: Double, hasData: Bool) -> Color {
        guard hasData else { return .secondary }
        if rate >= 90 { return FrostTheme.teal }
        if rate >= 70 { return .yellow }
        return .red
    }

    /// Returns inset for each pyramid row so cards narrow toward the bottom.
    private func cardPyramidInset(row: Int, rows: Int) -> CGFloat {
        CGFloat(row) * 40
    }

    private func formatData(_ gb: Double) -> (String, String) {
        if gb >= 1000 { return (String(format: "%.2f", gb / 1000), "TB") }
        return (String(format: "%.1f", gb), "GB")
    }

    private func formatMinutes(_ minutes: Double) -> String {
        guard minutes > 0 else { return "—" }
        let m = Int(minutes)
        let s = Int((minutes - Double(m)) * 60)
        return s > 0 ? "\(m)m \(s)s" : "\(m)m"
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let detail: String
    var detailLineLimit: Int = 2

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FrostTheme.paddingS) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                    Text(label.uppercased())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(value)
                    .font(.system(size: 45, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(detailLineLimit)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FrostTheme.paddingM)
        }
    }
}

// MARK: - Glass card container

private struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(minHeight: 120)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}
