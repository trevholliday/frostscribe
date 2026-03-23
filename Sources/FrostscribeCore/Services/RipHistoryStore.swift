import Foundation
import GRDB

// MARK: - GRDB conformance for RipRecord

extension RipRecord: FetchableRecord {
    public init(row: Row) throws {
        id               = UUID(uuidString: row["id"]) ?? UUID()
        timestamp        = row["timestamp"]
        discType         = DiscType(rawValue: row["disc_type"]) ?? .unknown
        titleSizeBytes   = row["title_size_bytes"]
        ripDurationSeconds = row["rip_duration_seconds"]
        jobLabel         = row["job_label"]
        success          = row["success"]
    }
}

extension RipRecord: MutablePersistableRecord {
    public static let databaseTableName = "rip_records"

    public func encode(to container: inout PersistenceContainer) throws {
        container["id"]                   = id.uuidString
        container["timestamp"]            = timestamp
        container["disc_type"]            = discType.rawValue
        container["title_size_bytes"]     = titleSizeBytes
        container["rip_duration_seconds"] = ripDurationSeconds
        container["job_label"]            = jobLabel
        container["success"]              = success
    }
}

// MARK: - Store

public struct RipHistoryStore: Sendable {
    private let dbQueue: DatabaseQueue?

    public init(appSupportURL: URL) {
        let dbURL = appSupportURL.appending(path: "riphistory.db")
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
            try db.create(table: "rip_records", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("timestamp", .datetime).notNull()
                t.column("disc_type", .text).notNull()
                t.column("title_size_bytes", .integer).notNull()
                t.column("rip_duration_seconds", .double).notNull()
                t.column("job_label", .text).notNull()
                t.column("success", .boolean).notNull()
            }
            try db.create(
                index: "rip_records_on_disc_type_size",
                on: "rip_records",
                columns: ["disc_type", "title_size_bytes"],
                ifNotExists: true
            )
        }
        try migrator.migrate(db)
    }

    public func load() -> [RipRecord] {
        guard let dbQueue else { return [] }
        return (try? dbQueue.read { db in
            try RipRecord.order(Column("timestamp").desc).fetchAll(db)
        }) ?? []
    }

    public func append(_ record: RipRecord) throws {
        guard let dbQueue else { return }
        var r = record
        try dbQueue.write { db in try r.insert(db) }
    }

    public func records(for discType: DiscType, near sizeBytes: Int, tolerance: Double = 0.25) -> [RipRecord] {
        guard let dbQueue else { return [] }
        let lower = Int(Double(sizeBytes) * (1 - tolerance))
        let upper = Int(Double(sizeBytes) * (1 + tolerance))
        return (try? dbQueue.read { db in
            try RipRecord
                .filter(Column("disc_type") == discType.rawValue)
                .filter(Column("success") == true)
                .filter(Column("title_size_bytes") >= lower)
                .filter(Column("title_size_bytes") <= upper)
                .fetchAll(db)
        }) ?? []
    }
}
