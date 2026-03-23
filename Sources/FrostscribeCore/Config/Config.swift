public struct Config: Sendable {
    public var mediaServer: MediaServer
    public var moviesDir: String
    public var tvDir: String
    public var tempDir: String
    public var tmdbApiKey: String
    public var makemkvKey: String
    public var makemkvBin: String
    public var handbrakeBin: String
    public var notificationsEnabled: Bool
    /// When true, the user is present — the app guides ripping interactively (Vigil Mode).
    /// When false, AutoScribe is active — the app auto-rips any inserted disc without user input.
    public var vigilMode: Bool
    public var selectAudioTracks: Bool
    public var qualityDVD: EncodeQuality
    public var qualityBluray: EncodeQuality
    public var qualityUHD: EncodeQuality

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
        vigilMode: Bool = true,
        selectAudioTracks: Bool = false,
        qualityDVD: EncodeQuality = .q80,
        qualityBluray: EncodeQuality = .q70,
        qualityUHD: EncodeQuality = .q70
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
        self.qualityDVD = qualityDVD
        self.qualityBluray = qualityBluray
        self.qualityUHD = qualityUHD
    }
}

extension Config: Codable {
    enum CodingKeys: String, CodingKey {
        case mediaServer, moviesDir, tvDir, tempDir, tmdbApiKey, makemkvKey,
             makemkvBin, handbrakeBin, notificationsEnabled, vigilMode,
             selectAudioTracks, qualityDVD, qualityBluray, qualityUHD
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mediaServer          = (try? c.decode(MediaServer.self,    forKey: .mediaServer))      ?? .jellyfin
        moviesDir            = (try? c.decode(String.self,         forKey: .moviesDir))         ?? ""
        tvDir                = (try? c.decode(String.self,         forKey: .tvDir))             ?? ""
        tempDir              = (try? c.decode(String.self,         forKey: .tempDir))           ?? ""
        tmdbApiKey           = (try? c.decode(String.self,         forKey: .tmdbApiKey))        ?? ""
        makemkvKey           = (try? c.decode(String.self,         forKey: .makemkvKey))        ?? ""
        makemkvBin           = (try? c.decode(String.self,         forKey: .makemkvBin))        ?? ""
        handbrakeBin         = (try? c.decode(String.self,         forKey: .handbrakeBin))      ?? ""
        notificationsEnabled = (try? c.decode(Bool.self,           forKey: .notificationsEnabled)) ?? true
        vigilMode            = (try? c.decode(Bool.self,           forKey: .vigilMode))         ?? true
        selectAudioTracks    = (try? c.decode(Bool.self,           forKey: .selectAudioTracks)) ?? false
        qualityDVD           = (try? c.decode(EncodeQuality.self,  forKey: .qualityDVD))        ?? .q80
        qualityBluray        = (try? c.decode(EncodeQuality.self,  forKey: .qualityBluray))     ?? .q70
        qualityUHD           = (try? c.decode(EncodeQuality.self,  forKey: .qualityUHD))        ?? .q70
    }
}
