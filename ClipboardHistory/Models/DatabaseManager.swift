import Foundation
import SQLite3

/// SQLITE_TRANSIENT — 告诉 SQLite 复制字符串（而非信任指针永久有效）
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 数据库管理器 — 使用原生 SQLite3（无外部依赖）
final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?

    /// 数据库是否已初始化成功
    var isReady: Bool { db != nil }

    // MARK: - 初始化

    func setup() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let dbDir = appSupport.appendingPathComponent("ClipboardHistory")
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)

        let imagesDir = dbDir.appendingPathComponent("Images")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        let dbPath = dbDir.appendingPathComponent("clipboard.db").path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errMsg = db != nil ? String(cString: sqlite3_errmsg(db)) : "无法打开数据库"
            throw DatabaseError.openFailed(errMsg)
        }

        try createTables()
        print("📦 数据库已就绪: \(dbPath)")
    }

    // MARK: - 建表

    private func createTables() throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        let sql = """
            CREATE TABLE IF NOT EXISTS clipboard_entries (
                id TEXT PRIMARY KEY,
                contentType TEXT NOT NULL,
                textContent TEXT,
                imagePath TEXT,
                sourceApp TEXT NOT NULL DEFAULT '',
                sourceBundle TEXT NOT NULL DEFAULT '',
                isPinned INTEGER NOT NULL DEFAULT 0,
                isSensitive INTEGER NOT NULL DEFAULT 0,
                encryptedData BLOB,
                createdAt TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_created_at ON clipboard_entries(createdAt);
            CREATE INDEX IF NOT EXISTS idx_pinned ON clipboard_entries(isPinned);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - 写入

    func insert(_ entry: ClipboardEntry) throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        let formatter = ISO8601DateFormatter()
        let dateStr = formatter.string(from: entry.createdAt)

        let sql = """
            INSERT INTO clipboard_entries
            (id, contentType, textContent, imagePath, sourceApp, sourceBundle, isPinned, isSensitive, encryptedData, createdAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, entry.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, entry.contentType, -1, SQLITE_TRANSIENT)
        if let text = entry.textContent {
            sqlite3_bind_text(stmt, 3, text, -1, SQLITE_TRANSIENT)
        } else { sqlite3_bind_null(stmt, 3) }
        if let path = entry.imagePath {
            sqlite3_bind_text(stmt, 4, path, -1, SQLITE_TRANSIENT)
        } else { sqlite3_bind_null(stmt, 4) }
        sqlite3_bind_text(stmt, 5, entry.sourceApp, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, entry.sourceBundle, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 7, entry.isPinned ? 1 : 0)
        sqlite3_bind_int(stmt, 8, entry.isSensitive ? 1 : 0)
        if let data = entry.encryptedData {
            _ = data.withUnsafeBytes { ptr in
                sqlite3_bind_blob(stmt, 9, ptr.baseAddress, Int32(data.count), nil)
            }
        } else { sqlite3_bind_null(stmt, 9) }
        sqlite3_bind_text(stmt, 10, dateStr, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    /// 删除所有记录
    func deleteAll() throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        // 清理图片文件
        let all = (try? fetchAll()) ?? []
        for entry in all {
            if let path = entry.imagePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        let sql = "DELETE FROM clipboard_entries;"
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    /// 更新条目的时间戳（粘贴时移到最前面）
    func updateTimestamp(id: String) throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        let now = ISO8601DateFormatter().string(from: Date())
        let sql = "UPDATE clipboard_entries SET createdAt = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, now, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
    }

    func togglePin(id: String) throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        let sql = "UPDATE clipboard_entries SET isPinned = CASE WHEN isPinned = 1 THEN 0 ELSE 1 END WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func delete(id: String) throws {
        guard let db = db else { throw DatabaseError.notInitialized }
        let entry = try fetchOne(id: id)

        let sql = "DELETE FROM clipboard_entries WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }

        if let imagePath = entry?.imagePath {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
    }

    // MARK: - 查询

    func fetchAll() throws -> [ClipboardEntry] {
        guard db != nil else { throw DatabaseError.notInitialized }
        let sql = "SELECT * FROM clipboard_entries ORDER BY isPinned DESC, createdAt DESC;"
        return try query(sql)
    }

    func search(keyword: String) throws -> [ClipboardEntry] {
        guard let db = db else { throw DatabaseError.notInitialized }
        let sql = """
            SELECT * FROM clipboard_entries
            WHERE textContent LIKE ?
            ORDER BY isPinned DESC, createdAt DESC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        let pattern = "%\(keyword)%"
        sqlite3_bind_text(stmt, 1, pattern, -1, SQLITE_TRANSIENT)

        var entries: [ClipboardEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            entries.append(ClipboardEntry.fromStatement(stmt!))
        }
        return entries
    }

    func isDuplicate(text: String) throws -> Bool {
        guard let db = db else { return false }
        let sql = "SELECT textContent FROM clipboard_entries ORDER BY createdAt DESC LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW,
           let ptr = sqlite3_column_text(stmt, 0) {
            return String(cString: ptr) == text
        }
        return false
    }

    func cleanupExpired(retentionDays: Int) throws -> Int {
        guard let db = db else { return 0 }
        let cutoff = Date().addingTimeInterval(TimeInterval(-retentionDays * 24 * 3600))
        let formatter = ISO8601DateFormatter()
        let cutoffStr = formatter.string(from: cutoff)

        let expired = try query(
            "SELECT * FROM clipboard_entries WHERE isPinned = 0 AND createdAt < ?;",
            bind: { stmt in sqlite3_bind_text(stmt, 1, cutoffStr, -1, SQLITE_TRANSIENT) }
        )

        for entry in expired {
            if let imagePath = entry.imagePath {
                try? FileManager.default.removeItem(atPath: imagePath)
            }
        }

        let sql = "DELETE FROM clipboard_entries WHERE isPinned = 0 AND createdAt < ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, cutoffStr, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) == SQLITE_DONE { return expired.count }
        return 0
    }

    // MARK: - 私有方法

    private func fetchOne(id: String) throws -> ClipboardEntry? {
        guard let db = db else { return nil }
        let sql = "SELECT * FROM clipboard_entries WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return ClipboardEntry.fromStatement(stmt!)
        }
        return nil
    }

    private func query(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil) throws -> [ClipboardEntry] {
        guard let db = db else { throw DatabaseError.notInitialized }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        bind?(stmt!)

        var entries: [ClipboardEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            entries.append(ClipboardEntry.fromStatement(stmt!))
        }
        return entries
    }

    // MARK: - 图片路径

    func imageStoragePath(for uuid: String) throws -> String {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil, create: false
        )
        return appSupport
            .appendingPathComponent("ClipboardHistory")
            .appendingPathComponent("Images")
            .appendingPathComponent("\(uuid).png").path
    }

    deinit {
        if let db = db { sqlite3_close(db) }
    }
}

enum DatabaseError: LocalizedError {
    case notInitialized
    case openFailed(String)
    case execFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized: return "数据库未初始化"
        case .openFailed(let msg): return "无法打开数据库: \(msg)"
        case .execFailed(let msg): return "数据库操作失败: \(msg)"
        }
    }
}
