import Testing
@testable import FrostscribeCore
import Foundation

@Suite("PathBuilder")
struct PathBuilderTests {
    private let base = URL(fileURLWithPath: "/Media")

    // MARK: - Movies (all servers use same movie layout)

    @Test func moviePathJellyfin() {
        let url = PathBuilder.moviePath(title: "The Matrix", year: "1999", baseDir: base, mediaServer: .jellyfin)
        #expect(url.path.hasSuffix("The Matrix (1999)/The Matrix (1999).mkv"))
    }

    @Test func moviePathPlex() {
        let url = PathBuilder.moviePath(title: "The Matrix", year: "1999", baseDir: base, mediaServer: .plex)
        #expect(url.path.hasSuffix("The Matrix (1999)/The Matrix (1999).mkv"))
    }

    @Test func moviePathKodi() {
        let url = PathBuilder.moviePath(title: "The Matrix", year: "1999", baseDir: base, mediaServer: .kodi)
        #expect(url.path.hasSuffix("The Matrix (1999)/The Matrix (1999).mkv"))
    }

    @Test func moviePathBaseDir() {
        let url = PathBuilder.moviePath(title: "Inception", year: "2010", baseDir: base, mediaServer: .jellyfin)
        #expect(url.path.hasPrefix("/Media/"))
    }

    // MARK: - TV: Jellyfin / Emby

    @Test func episodePathJellyfin() {
        let url = PathBuilder.episodePath(
            show: "Breaking Bad", year: "2008", season: 1, episode: 1,
            baseDir: base, mediaServer: .jellyfin
        )
        let path = url.path
        #expect(path.contains("Breaking Bad (2008)"))
        #expect(path.contains("Season 01"))
        #expect(path.hasSuffix("Breaking Bad (2008) - S01E01.mkv"))
    }

    @Test func episodePathJellyfinDoubleDigits() {
        let url = PathBuilder.episodePath(
            show: "The Wire", year: "2002", season: 3, episode: 12,
            baseDir: base, mediaServer: .jellyfin
        )
        #expect(url.path.hasSuffix("The Wire (2002) - S03E12.mkv"))
        #expect(url.path.contains("Season 03"))
    }

    // MARK: - TV: Plex

    @Test func episodePathPlex() {
        let url = PathBuilder.episodePath(
            show: "Breaking Bad", year: "2008", season: 1, episode: 1,
            baseDir: base, mediaServer: .plex
        )
        let path = url.path
        #expect(path.contains("Breaking Bad/"))
        #expect(!path.contains("Breaking Bad ("))
        #expect(path.contains("Season 01"))
        #expect(path.hasSuffix("S01E01.mkv"))
    }

    @Test func episodePathPlexDoubleDigits() {
        let url = PathBuilder.episodePath(
            show: "The Wire", year: "2002", season: 3, episode: 12,
            baseDir: base, mediaServer: .plex
        )
        #expect(url.path.hasSuffix("S03E12.mkv"))
    }

    // MARK: - TV: Kodi

    @Test func episodePathKodi() {
        let url = PathBuilder.episodePath(
            show: "Breaking Bad", year: "2008", season: 1, episode: 1,
            baseDir: base, mediaServer: .kodi
        )
        let path = url.path
        #expect(path.contains("Breaking Bad/"))
        #expect(!path.contains("Breaking Bad ("))
        #expect(path.contains("Season01"))
        #expect(!path.contains("Season 01"))
        #expect(path.hasSuffix("Breaking Bad S01E01.mkv"))
    }

    @Test func episodePathKodiDoubleDigits() {
        let url = PathBuilder.episodePath(
            show: "The Wire", year: "2002", season: 3, episode: 12,
            baseDir: base, mediaServer: .kodi
        )
        #expect(url.path.contains("Season03"))
        #expect(url.path.hasSuffix("The Wire S03E12.mkv"))
    }
}
