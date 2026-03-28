public struct MediaDetails: Sendable {
    public var tagline: String?
    public var overview: String?
    public var runtimeMinutes: Int?
    public var genres: [String]
    public var releaseDate: String?   // e.g. "05/16/2013 (US)"
    public var certification: String? // e.g. "PG-13"
    public var crew: [CrewMember]

    public struct CrewMember: Sendable {
        public var name: String
        public var job: String
    }

    public var runtimeFormatted: String? {
        guard let min = runtimeMinutes, min > 0 else { return nil }
        let h = min / 60, m = min % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    public init(
        tagline: String? = nil,
        overview: String? = nil,
        runtimeMinutes: Int? = nil,
        genres: [String] = [],
        releaseDate: String? = nil,
        certification: String? = nil,
        crew: [CrewMember] = []
    ) {
        self.tagline = tagline
        self.overview = overview
        self.runtimeMinutes = runtimeMinutes
        self.genres = genres
        self.releaseDate = releaseDate
        self.certification = certification
        self.crew = crew
    }
}
