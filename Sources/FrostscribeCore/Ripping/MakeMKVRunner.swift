import Foundation

public final class MakeMKVRunner: MakeMKVRunning {
    private let binPath: String

    public init(binPath: String = "makemkvcon") {
        self.binPath = binPath
    }

    public func scan(onMessage: @escaping @Sendable (String) -> Void = { _ in }) async throws -> DiscScanResult {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do { cont.resume(returning: try self.scanSync(onMessage: onMessage)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    public func rip(
        titleNumber: Int,
        to destination: URL,
        onMessage: @escaping @Sendable (String) -> Void = { _ in },
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do { try self.ripSync(titleNumber: titleNumber, to: destination, onMessage: onMessage, onProgress: onProgress); cont.resume() }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    // MARK: - Sync implementations

    private func scanSync(onMessage: @escaping @Sendable (String) -> Void) throws -> DiscScanResult {
        let output = try run(arguments: ["-r", "info", "disc:0"], onLine: onMessage)
        return buildScanResult(from: output)
    }

    private func ripSync(
        titleNumber: Int,
        to destination: URL,
        onMessage: @escaping @Sendable (String) -> Void,
        onProgress: @escaping @Sendable (Int) -> Void
    ) throws {
        let lines = try run(
            arguments: ["-r", "mkv", "disc:0", "\(titleNumber)", destination.path],
            onLine: { line in
                switch MakeMKVParser.parse(line) {
                case .progress(_, let total, let max) where max > 0:
                    let pct = min(Int(Double(total) / Double(max) * 100), 99)
                    onProgress(pct)
                case .progressTitle(let msg):
                    onMessage(msg)
                case .message(let msg):
                    onMessage(msg)
                default:
                    break
                }
            }
        )

        for line in lines {
            if case .criticalError(let code, let message) = MakeMKVParser.parse(line) {
                throw FrostscribeError.makemkvCriticalError(code: code, message: message)
            }
        }
    }

    // MARK: - Process runner

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

    private func buildScanResult(from lines: [String]) -> DiscScanResult {
        var titleData: [Int: [Int: String]] = [:]
        var streamData: [Int: [Int: [Int: String]]] = [:]
        var discName: String?
        var discTypeString: String?

        for line in lines {
            switch MakeMKVParser.parse(line) {
            case .discType(let t): discTypeString = t
            case .discName(let n): discName = n
            case .titleInfo(let num, let attr, let value):
                if titleData[num] == nil { titleData[num] = [:] }
                titleData[num]![attr] = value
            case .streamInfo(let titleNum, let streamNum, let attr, let value):
                if streamData[titleNum] == nil { streamData[titleNum] = [:] }
                if streamData[titleNum]![streamNum] == nil { streamData[titleNum]![streamNum] = [:] }
                streamData[titleNum]![streamNum]![attr] = value
            default: break
            }
        }

        let titles: [DiscTitle] = titleData.compactMap { num, attrs in
            guard let sizeStr = attrs[11], let sizeBytes = Int(sizeStr) else { return nil }
            let streams = streamData[num] ?? [:]
            let audioTracks = buildAudioTracks(from: streams)
            let videoResolution = buildVideoResolution(from: streams)
            let subtitleCount = streams.values.filter { $0[1]?.hasPrefix("S_") == true }.count
            let orderWeight = Int(attrs[33] ?? "0") ?? 0
            return DiscTitle(
                number: num,
                name: attrs[27] ?? "title_\(num)",
                duration: attrs[9] ?? "?",
                chapters: attrs[8] ?? "?",
                sizeBytes: sizeBytes,
                audioTracks: audioTracks,
                videoResolution: videoResolution,
                subtitleCount: subtitleCount,
                orderWeight: orderWeight
            )
        }.sorted { $0.number < $1.number }

        let discType = discTypeString.map { DiscType(makeMKVString: $0) } ?? .unknown
        return DiscScanResult(titles: titles, discName: discName, discType: discType)
    }

    private func buildAudioTracks(from streams: [Int: [Int: String]]) -> [AudioTrack] {
        streams.sorted { $0.key < $1.key }.compactMap { _, attrs in
            guard let typeVal = attrs[1], typeVal.hasPrefix("A_") else { return nil }
            let codec = attrs[2] ?? String(typeVal.dropFirst(2))
            let language = attrs[14] ?? attrs[13] ?? "Unknown"
            // Attr 40 = AP_ItemAttribute_AudioChannelLayoutName ("7.1", "5.1", "2.0", etc.)
            // Fall back to parsing it from the codec string if not present.
            let channels = attrs[40] ?? channelsFromCodec(attrs[2] ?? "")
            return AudioTrack(language: language, codec: codec, channels: channels)
        }
    }

    /// Extracts a channel layout string from codec descriptions like "DTS-HD MA 7.1".
    private func channelsFromCodec(_ codec: String) -> String? {
        let patterns = ["7.1", "5.1", "4.0", "2.0", "1.0", "6.1", "7.0", "5.0"]
        return patterns.first { codec.contains($0) }
    }

    private func buildVideoResolution(from streams: [Int: [Int: String]]) -> String? {
        // Attr 19 = AP_ItemAttribute_VideoSize ("1920x1080", "3840x2160", etc.)
        // Take the first video stream's resolution.
        for (_, attrs) in streams.sorted(by: { $0.key < $1.key }) {
            guard let typeVal = attrs[1], typeVal.hasPrefix("V_") else { continue }
            if let res = attrs[19], !res.isEmpty { return res }
        }
        return nil
    }

    private func resolvedBinPath() -> String {
        if binPath.isEmpty { return "makemkvcon" }
        return binPath
    }
}

// @unchecked Sendable is intentional: readabilityHandler is a sync escaping closure
// that cannot be made async. NSLock below protects all mutable state.
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
