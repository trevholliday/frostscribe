import Foundation

public enum MakeMKVParser {
    public enum Line {
        case message(String)
        case progress(current: Int, total: Int, max: Int)
        case progressTitle(String)
        case discType(String)
        case discName(String)
        case titleInfo(titleNum: Int, attribute: Int, value: String)
        case unknown
    }

    public static func parse(_ line: String) -> Line {
        if let m = line.firstMatch(of: /^MSG:\d+,\d+,\d+,"([^"]+)"/) {
            return .message(String(m.1))
        }
        if let m = line.firstMatch(of: /^PRGV:(\d+),(\d+),(\d+)/) {
            return .progress(
                current: Int(m.1)!,
                total: Int(m.2)!,
                max: Int(m.3)!
            )
        }
        if let m = line.firstMatch(of: /^PRGC:\d+,\d+,"([^"]+)"/) {
            return .progressTitle(String(m.1))
        }
        if let m = line.firstMatch(of: /^CINFO:1,\d+,"(.*)"/) {
            return .discType(String(m.1))
        }
        if let m = line.firstMatch(of: /^CINFO:2,\d+,"(.*)"/) {
            return .discName(String(m.1))
        }
        if let m = line.firstMatch(of: /^TINFO:(\d+),(\d+),\d+,"(.*)"/) {
            return .titleInfo(
                titleNum: Int(m.1)!,
                attribute: Int(m.2)!,
                value: String(m.3)
            )
        }
        return .unknown
    }
}
