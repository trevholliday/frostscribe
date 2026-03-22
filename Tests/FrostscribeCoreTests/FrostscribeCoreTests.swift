import Testing
@testable import FrostscribeCore

@Suite("FrostscribeCore")
struct FrostscribeCoreTests {
    @Test func parserHandlesProgressLine() {
        let line = "PRGV:1234,5000,10000"
        if case .progress(let cur, let total, let max) = MakeMKVParser.parse(line) {
            #expect(cur == 1234)
            #expect(total == 5000)
            #expect(max == 10000)
        } else {
            #expect(Bool(false), "Expected .progress")
        }
    }

    @Test func pathBuilderMovieJellyfin() throws {
        let path = PathBuilder.moviePath(title: "The Matrix", year: 1999, ext: "mkv", server: .jellyfin)
        #expect(path.hasSuffix("The Matrix (1999)/The Matrix (1999).mkv"))
    }

    @Test func pathBuilderEpisodePlex() throws {
        let path = PathBuilder.episodePath(
            show: "Breaking Bad", season: 1, episode: 1,
            episodeTitle: "Pilot", ext: "mkv", server: .plex
        )
        #expect(path.contains("Season 01"))
        #expect(path.hasSuffix("Breaking Bad - s01e01 - Pilot.mkv"))
    }
}
