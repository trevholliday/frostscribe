import Foundation

public final class MakeMKVRunner: Sendable {
    public struct ScanResult: Sendable {
        public var titles: [DiscTitle]
        public var discName: String?
        public var discType: String?
    }

    private let binPath: String

    public init(binPath: String = "makemkvcon") {
        self.binPath = binPath
    }

    public func scan(onMessage: @escaping @Sendable (String) -> Void = { _ in }) throws -> ScanResult {
        let output = try run(arguments: ["-r", "info", "disc:0"], onLine: onMessage)
        return buildScanResult(from: output)
    }

    public func rip(
        titleNumber: Int,
        to destination: URL,
        onMessage: @escaping @Sendable (String) -> Void = { _ in },
        onProgress: @escaping @Sendable (Int) -> Void
    ) throws {
        _ = try run(
            arguments: ["-r", "mkv", "disc:0", "\(titleNumber)", destination.path],
            onLine: { line in
                switch MakeMKVParser.parse(line) {
                case .progress(_, let total, let max) where max > 0:
                    let pct = min(Int(Double(total) / Double(max) * 100), 99)
                    onProgress(pct)
                case .message(let msg):
                    onMessage(msg)
                default:
                    break
                }
            }
        )
    }

    @discardableResult
    private func run(
        arguments: [String],
        onLine: @escaping @Sendable (String) -> Void
    ) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedBinPath())
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let collector = OutputCollector(onLine: onLine)

        pipe.fileHandleForReading.readabilityHandler = { handle in
            collector.consume(handle.availableData)
        }

        try process.run()
        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil

        guard process.terminationStatus == 0 else {
            throw FrostscribeError.makemkvFailed(exitCode: process.terminationStatus)
        }
        return collector.lines
    }

    private func buildScanResult(from lines: [String]) -> ScanResult {
        var titleData: [Int: [Int: String]] = [:]
        var discName: String?
        var discType: String?

        for line in lines {
            switch MakeMKVParser.parse(line) {
            case .discType(let t): discType = t
            case .discName(let n): discName = n
            case .titleInfo(let num, let attr, let value):
                if titleData[num] == nil { titleData[num] = [:] }
                titleData[num]![attr] = value
            default: break
            }
        }

        let titles: [DiscTitle] = titleData.compactMap { num, attrs in
            guard let sizeStr = attrs[11], let sizeBytes = Int(sizeStr) else { return nil }
            return DiscTitle(
                number: num,
                name: attrs[27] ?? "title_\(num)",
                duration: attrs[9] ?? "?",
                chapters: attrs[8] ?? "?",
                sizeBytes: sizeBytes
            )
        }.sorted { $0.number < $1.number }

        return ScanResult(titles: titles, discName: discName, discType: discType)
    }

    private func resolvedBinPath() -> String {
        if binPath.isEmpty { return "makemkvcon" }
        return binPath
    }
}

private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var _lines: [String] = []
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    func consume(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
        while let range = buffer.range(of: Data([0x0A])) ?? buffer.range(of: Data([0x0D])) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex...range.lowerBound)
            if let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespaces),
               !line.isEmpty {
                _lines.append(line)
                onLine(line)
            }
        }
    }

    var lines: [String] {
        lock.withLock { _lines }
    }
}
