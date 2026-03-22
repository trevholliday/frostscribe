import Testing
@testable import FrostscribeCore

@Suite("MakeMKVParser")
struct MakeMKVParserTests {

    // MARK: - Progress

    @Test func parsesProgressLine() {
        let line = "PRGV:1234,5000,10000"
        guard case .progress(let cur, let total, let max) = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .progress"); return
        }
        #expect(cur == 1234)
        #expect(total == 5000)
        #expect(max == 10000)
    }

    @Test func parsesProgressTitle() {
        let line = #"PRGC:0,1,"Ripping track 1""#
        guard case .progressTitle(let title) = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .progressTitle"); return
        }
        #expect(title == "Ripping track 1")
    }

    // MARK: - Messages

    @Test func parsesRegularMessage() {
        let line = #"MSG:1000,0,0,"Copy complete""#
        guard case .message(let text) = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .message"); return
        }
        #expect(text == "Copy complete")
    }

    @Test func parsesCriticalError() {
        let line = #"MSG:4100,0,0,"Critical drive error""#
        guard case .criticalError(let code, let message) = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .criticalError"); return
        }
        #expect(code == 4100)
        #expect(message == "Critical drive error")
    }

    @Test func parsesLowerBoundCriticalError() {
        let line = #"MSG:4000,0,0,"Error at lower bound""#
        guard case .criticalError(let code, _) = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .criticalError"); return
        }
        #expect(code == 4000)
    }

    @Test func parsesUpperBoundCriticalError() {
        let line = #"MSG:4999,0,0,"Error at upper bound""#
        guard case .criticalError(let code, _) = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .criticalError"); return
        }
        #expect(code == 4999)
    }

    @Test func treatsCode3999AsMessage() {
        let line = #"MSG:3999,0,0,"Not critical""#
        guard case .message = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .message, not .criticalError"); return
        }
    }

    @Test func treatsCode5000AsMessage() {
        let line = #"MSG:5000,0,0,"Also not critical""#
        guard case .message = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .message, not .criticalError"); return
        }
    }

    // MARK: - Disc info

    @Test func parsesDiscType() {
        let line = #"CINFO:1,0,"Blu-ray disc""#
        guard case .discType(let type) = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .discType"); return
        }
        #expect(type == "Blu-ray disc")
    }

    @Test func parsesDiscName() {
        let line = #"CINFO:2,0,"THE_DARK_KNIGHT""#
        guard case .discName(let name) = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .discName"); return
        }
        #expect(name == "THE_DARK_KNIGHT")
    }

    // MARK: - Title info

    @Test func parsesTitleInfo() {
        let line = #"TINFO:3,27,0,"01:52:31""#
        guard case .titleInfo(let num, let attr, let value) = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .titleInfo"); return
        }
        #expect(num == 3)
        #expect(attr == 27)
        #expect(value == "01:52:31")
    }

    // MARK: - Stream info

    @Test func parsesStreamInfo() {
        let line = #"SINFO:0,1,21,0,"English""#
        guard case .streamInfo(let titleNum, let streamNum, let attr, let value) = MakeMKVParser.parse(line) else {
            #expect(Bool(false), "Expected .streamInfo"); return
        }
        #expect(titleNum == 0)
        #expect(streamNum == 1)
        #expect(attr == 21)
        #expect(value == "English")
    }

    // MARK: - Unknown

    @Test func returnsUnknownForGarbage() {
        guard case .unknown = MakeMKVParser.parse("JUNK:garbage line") else {
            #expect(Bool(false), "Expected .unknown"); return
        }
    }

    @Test func returnsUnknownForEmpty() {
        guard case .unknown = MakeMKVParser.parse("") else {
            #expect(Bool(false), "Expected .unknown"); return
        }
    }
}
