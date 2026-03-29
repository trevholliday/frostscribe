import SwiftUI

struct LogsView: View {
    @State private var lines: [LogLine] = []
    @State private var filter: String = ""

    private static let logURL = URL(fileURLWithPath: NSHomeDirectory())
        .appending(path: "Library/Logs/Frostscribe/worker.log")

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
        let id: Int
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
                    .font(.title3).bold()
                Spacer()
                if !lines.isEmpty {
                    Text("\(lines.count) lines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, FrostTheme.paddingL)
            .padding(.top, FrostTheme.paddingL)
            .padding(.bottom, FrostTheme.paddingM)

            // Search
            HStack(spacing: FrostTheme.spacing) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Filter…", text: $filter)
                    .textFieldStyle(.frost)
                    .font(.caption)
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
                    Text(Self.logURL.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered) { line in
                            HStack(alignment: .top, spacing: FrostTheme.spacing) {
                                Text(line.timestamp)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 160, alignment: .leading)
                                Text(line.message)
                                    .font(.caption.monospaced())
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
        guard let raw = try? String(contentsOf: Self.logURL, encoding: .utf8) else {
            lines = []
            return
        }
        let parsed = raw
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .enumerated()
            .map { (idx, line) -> LogLine in
                let raw = line
                // Format: [2026-03-28T14:00:49Z] Message text
                var ts = ""
                var msg = raw
                if raw.hasPrefix("["), let close = raw.firstIndex(of: "]") {
                    ts  = String(raw[raw.index(after: raw.startIndex)..<close])
                    msg = String(raw[raw.index(after: close)...]).trimmingCharacters(in: .whitespaces)
                }
                if let date = Self.isoParser.date(from: ts) {
                    ts = Self.localFormatter.string(from: date)
                }
                let level: LogLine.Level = msg.lowercased().contains("fail") || msg.lowercased().contains("error")
                    ? .error
                    : msg.lowercased().contains("warn") ? .warning : .info
                return LogLine(id: idx, timestamp: ts, message: msg, level: level)
            }
        lines = Array(parsed.reversed())
    }

    private func color(for level: LogLine.Level) -> Color {
        switch level {
        case .error:   return FrostTheme.alert
        case .warning: return FrostTheme.glacier
        case .info:    return FrostTheme.textPrimary.opacity(0.85)
        }
    }
}
