import Foundation

public enum PathBuilder {
    public static func moviePath(
        title: String,
        year: String,
        baseDir: URL,
        mediaServer: MediaServer
    ) -> URL {
        let folder = "\(title) (\(year))"
        let filename = "\(title) (\(year)).mkv"
        return baseDir.appending(path: folder).appending(path: filename)
    }

    public static func episodePath(
        show: String,
        year: String,
        season: Int,
        episode: Int,
        baseDir: URL,
        mediaServer: MediaServer
    ) -> URL {
        let episodeID = String(format: "S%02dE%02d", season, episode)

        switch mediaServer {
        case .jellyfin, .emby:
            let showFolder   = "\(show) (\(year))"
            let seasonFolder = String(format: "Season %02d", season)
            let filename     = "\(show) (\(year)) - \(episodeID).mkv"
            return baseDir.appending(path: showFolder).appending(path: seasonFolder).appending(path: filename)

        case .plex:
            let showFolder   = show
            let seasonFolder = String(format: "Season %02d", season)
            let filename     = "\(episodeID).mkv"
            return baseDir.appending(path: showFolder).appending(path: seasonFolder).appending(path: filename)

        case .kodi:
            let showFolder   = show
            let seasonFolder = String(format: "Season%02d", season)
            let filename     = "\(show) \(episodeID).mkv"
            return baseDir.appending(path: showFolder).appending(path: seasonFolder).appending(path: filename)
        }
    }
}
