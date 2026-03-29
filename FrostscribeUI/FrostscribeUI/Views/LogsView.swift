import SwiftUI
import FrostscribeCore

struct LogsView: View {
    @State private var lines: [LogLine] = []
    @State private var filter: String = ""

    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private static let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let localFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    struct LogLine: Identifiable {
        let id: Int64
        let timestamp: String
        let message: String
        let level: Level

        enum Level { case info, error, warning }
    }

    var filtered: [LogLine] {
        guard !filter.isEmpty else { return lines }
        return lines.filter { $0.timestamp.localizedCaseInsensitiveContains(filter) ||
                               $0.message.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Logs")
                    .font(.system(size: 25, weight: .bold))
                Spacer()
                if !lines.isEmpty {
                    Text("\(lines.count) lines")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                Button {
                    LogStore(appSupportURL: ConfigManager.appSupportURL).clear()
                    load()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear all logs")
            }
            .padding(.horizontal, FrostTheme.paddingL)
            .padding(.top, FrostTheme.paddingL)
            .padding(.bottom, FrostTheme.paddingM)

            // Search
            HStack(spacing: FrostTheme.spacing) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15))
                TextField("Filter…", text: $filter)
                    .textFieldStyle(.frost)
                    .font(.system(size: 15))
                if !filter.isEmpty {
                    Button { filter = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FrostTheme.paddingL)
            .padding(.bottom, FrostTheme.paddingM)

            Divider()

            if lines.isEmpty {
                VStack {
                    Spacer()
                    Text("No log entries yet.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered) { line in
                            HStack(alignment: .top, spacing: FrostTheme.spacing) {
                                Text(line.timestamp)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 200, alignment: .leading)
                                Text(line.message)
                                    .font(.system(size: 15, design: .monospaced))
                                    .foregroundStyle(color(for: line.level))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, FrostTheme.paddingL)
                            .padding(.vertical, 3)
                            Divider().opacity(0.3)
                        }
                    }
                    .padding(.vertical, FrostTheme.paddingS)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { load() }
        .onReceive(timer) { _ in load() }
    }

    // MARK: - Load

    private func load() {
        let entries = LogStore(appSupportURL: ConfigManager.appSupportURL).load()
        lines = entries.map { entry -> LogLine in
            var ts = entry.timestamp
            if let date = Self.isoParser.date(from: ts) {
                ts = Self.localFormatter.string(from: date)
            }
            let level: LogLine.Level = entry.level == "error"
                ? .error
                : entry.level == "warning" ? .warning : .info
            return LogLine(id: entry.id, timestamp: ts, message: entry.message, level: level)
        }
    }

    private func color(for level: LogLine.Level) -> Color {
        switch level {
        case .error:   return FrostTheme.alert
        case .warning: return FrostTheme.glacier
        case .info:    return FrostTheme.textPrimary.opacity(0.85)
        }
    }
}
