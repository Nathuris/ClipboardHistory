import Foundation
import SQLite3

/// 剪贴板条目 — 纯数据结构（不使用 GRDB，用原生 SQLite3 存取）
struct ClipboardEntry: Identifiable {
    var id: String = UUID().uuidString
    var contentType: String = "text"
    var textContent: String?
    var imagePath: String?
    var sourceApp: String = ""
    var sourceBundle: String = ""
    var isPinned: Bool = false
    var isSensitive: Bool = false
    var encryptedData: Data?
    var createdAt: Date = Date()

    /// 用于界面排序：置顶优先，然后按时间倒序
    static func sortedByPinAndTime(_ entries: [ClipboardEntry]) -> [ClipboardEntry] {
        entries.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }
    }
}

/// 从 SQLite 行解析 ClipboardEntry
extension ClipboardEntry {
    /// 列索引映射
    struct Col {
        static let id = 0
        static let contentType = 1
        static let textContent = 2
        static let imagePath = 3
        static let sourceApp = 4
        static let sourceBundle = 5
        static let isPinned = 6
        static let isSensitive = 7
        static let encryptedData = 8
        static let createdAt = 9
    }

    /// 从 sqlite3_stmt 读取一条记录
    static func fromStatement(_ stmt: OpaquePointer) -> ClipboardEntry {
        var entry = ClipboardEntry()

        if let ptr = sqlite3_column_text(stmt, Int32(Col.id)) {
            entry.id = String(cString: ptr)
        }
        if let ptr = sqlite3_column_text(stmt, Int32(Col.contentType)) {
            entry.contentType = String(cString: ptr)
        }
        if let ptr = sqlite3_column_text(stmt, Int32(Col.textContent)) {
            entry.textContent = String(cString: ptr)
        }
        if let ptr = sqlite3_column_text(stmt, Int32(Col.imagePath)) {
            entry.imagePath = String(cString: ptr)
        }
        if let ptr = sqlite3_column_text(stmt, Int32(Col.sourceApp)) {
            entry.sourceApp = String(cString: ptr)
        }
        if let ptr = sqlite3_column_text(stmt, Int32(Col.sourceBundle)) {
            entry.sourceBundle = String(cString: ptr)
        }
        entry.isPinned = sqlite3_column_int(stmt, Int32(Col.isPinned)) != 0
        entry.isSensitive = sqlite3_column_int(stmt, Int32(Col.isSensitive)) != 0

        if let blob = sqlite3_column_blob(stmt, Int32(Col.encryptedData)) {
            let count = Int(sqlite3_column_bytes(stmt, Int32(Col.encryptedData)))
            entry.encryptedData = Data(bytes: blob, count: count)
        }

        if let ptr = sqlite3_column_text(stmt, Int32(Col.createdAt)) {
            let dateStr = String(cString: ptr)
            let formatter = ISO8601DateFormatter()
            entry.createdAt = formatter.date(from: dateStr) ?? Date()
        }

        return entry
    }
}
