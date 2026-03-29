import Foundation
import GRDB

// MARK: - Model

public struct LogEntry: FetchableRecord, Decodable, Sendable {
    public let id: Int64
    public let timestamp: String
    public let message: String
    public let level: String

    public init(row: Row) throws {
        id        = row["id"]
        timestamp = row["timestamp"]
        message   = row["message"]
        level     = row["level"]
    }
}

// MARK: - Store

public struct LogStore: Sendable {
    private let dbQueue: DatabaseQueue?

    public init(appSupportURL: URL) {
        let dbURL = appSupportURL.appending(path: "logs.db")
        do {
            let queue = try DatabaseQueue(path: dbURL.path)
            try Self.migrate(queue)
            self.dbQueue = queue
        } catch {
            self.dbQueue = nil
        }
    }

    private static func migrate(_ db: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "log_entries", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .text).notNull().indexed()
                t.column("message", .text).notNull()
                t.column("level", .text).notNull()
            }
        }
        try migrator.migrate(db)
    }

    // MARK: - Write

    public func append(timestamp: String, message: String, level: String) {
        guard let dbQueue else { return }
        try? dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO log_entries (timestamp, message, level) VALUES (?, ?, ?)",
                arguments: [timestamp, message, level]
            )
        }
    }

    // MARK: - Read

    public func load(limit: Int = 2000) -> [LogEntry] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.write { db in
            // Prune rows older than 7 days
            let cutoff = ISO8601DateFormatter().string(
                from: Date().addingTimeInterval(-7 * 24 * 3600)
            )
            try db.execute(
                sql: "DELETE FROM log_entries WHERE timestamp < ?",
                arguments: [cutoff]
            )
            return try LogEntry.fetchAll(
                db,
                sql: "SELECT * FROM log_entries ORDER BY id DESC LIMIT ?",
                arguments: [limit]
            )
        }) ?? []
    }

    // MARK: - Clear

    public func clear() {
        guard let dbQueue else { return }
        try? dbQueue.write { db in
            try db.execute(sql: "DELETE FROM log_entries")
        }
    }
}
