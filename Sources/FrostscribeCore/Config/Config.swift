public struct Config: Codable, Sendable {
    public var mediaServer: MediaServer
    public var moviesDir: String
    public var tvDir: String
    public var tempDir: String
    public var tmdbApiKey: String
    public var makemkvKey: String
    public var makemkvBin: String
    public var handbrakeBin: String
    public var notificationsEnabled: Bool
    public var vigilMode: Bool
    public var selectAudioTracks: Bool

    public init(
        mediaServer: MediaServer = .jellyfin,
        moviesDir: String = "",
        tvDir: String = "",
        tempDir: String = "",
        tmdbApiKey: String = "",
        makemkvKey: String = "",
        makemkvBin: String = "",
        handbrakeBin: String = "",
        notificationsEnabled: Bool = true,
        vigilMode: Bool = false,
        selectAudioTracks: Bool = false
    ) {
        self.mediaServer = mediaServer
        self.moviesDir = moviesDir
        self.tvDir = tvDir
        self.tempDir = tempDir
        self.tmdbApiKey = tmdbApiKey
        self.makemkvKey = makemkvKey
        self.makemkvBin = makemkvBin
        self.handbrakeBin = handbrakeBin
        self.notificationsEnabled = notificationsEnabled
        self.vigilMode = vigilMode
        self.selectAudioTracks = selectAudioTracks
    }
}
