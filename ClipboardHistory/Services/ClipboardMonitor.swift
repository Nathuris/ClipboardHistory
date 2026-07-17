import AppKit
import Foundation

/// 剪贴板监听器 — 轮询 NSPasteboard，检测变化并记录
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var isRunning = false
    /// 临时暂停监听（粘贴历史内容时不记录新条目）
    private var skipNextChange = false

    private let pollInterval: TimeInterval = 0.5

    // MARK: - 启动/停止

    func start() {
        guard !isRunning else { return }
        isRunning = true

        lastChangeCount = NSPasteboard.general.changeCount

        timer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkPasteboard()
        }

        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        print("📋 剪贴板监听已启动（间隔 \(pollInterval) 秒）")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// 临时跳过下一次剪贴板变化（粘贴历史内容时调用）
    func ignoreNextChange() {
        skipNextChange = true
    }

    // MARK: - 核心逻辑

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }

        // 粘贴历史内容时跳过本次变化
        if skipNextChange {
            skipNextChange = false
            lastChangeCount = currentChangeCount
            return
        }
        lastChangeCount = currentChangeCount

        // 获取当前最前方 App 的信息
        let frontApp = NSWorkspace.shared.frontmostApplication
        let sourceAppName = frontApp?.localizedName ?? "未知应用"
        let sourceBundleId = frontApp?.bundleIdentifier ?? ""

        // 获取剪贴板中可用的类型
        let availableTypes = pasteboard.types ?? []
        print("📋 剪贴板变化！类型: \(availableTypes.map { $0.rawValue }), 来源: \(sourceAppName)")

        // 优先读文字
        if let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            handleTextContent(text, sourceApp: sourceAppName, sourceBundle: sourceBundleId)
            return
        }

        // 尝试读图片
        if let imageData = pasteboard.data(forType: .tiff) {
            handleImageContent(imageData, sourceApp: sourceAppName, sourceBundle: sourceBundleId)
            return
        }

        // 尝试 PNG
        if let pngData = pasteboard.data(forType: .png) {
            handleImageContent(pngData, sourceApp: sourceAppName, sourceBundle: sourceBundleId)
            return
        }

        print("📋 未能识别的剪贴板内容")
    }

    /// 处理文字内容
    private func handleTextContent(_ text: String, sourceApp: String, sourceBundle: String) {
        // 用时间戳+随机数确保 ID 绝不重复
        let uniqueId = "\(Int(Date().timeIntervalSince1970 * 1_000_000))-\(arc4random())"
        var entry = ClipboardEntry(
            id: uniqueId,
            contentType: "text",
            textContent: text,
            sourceApp: sourceApp,
            sourceBundle: sourceBundle
        )

        // 如果来源在黑名单中，加密存储
        if AppSettings.shared.isBlacklisted(sourceBundle) {
            entry.isSensitive = true
            if let encrypted = PrivacyManager.shared.encrypt(text) {
                entry.encryptedData = encrypted
                entry.textContent = nil
            }
        }

        do {
            try DatabaseManager.shared.insert(entry)
            print("📝 记录文字: \(text.prefix(50))... [来自 \(sourceApp)]")
        } catch {
            print("❌ 记录文字失败: \(error)")
        }
    }

    /// 处理图片内容
    private func handleImageContent(_ imageData: Data, sourceApp: String, sourceBundle: String) {
        let uuid = UUID().uuidString

        do {
            let imagePath = try DatabaseManager.shared.imageStoragePath(for: uuid)

            if let image = NSImage(data: imageData),
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try pngData.write(to: URL(fileURLWithPath: imagePath))
            } else {
                try imageData.write(to: URL(fileURLWithPath: imagePath))
            }

            // 生成缩略图
            if let image = NSImage(data: imageData) {
                ImageResizer.saveThumbnail(image, forUUID: uuid)
            }

            let uniqueImgId = "\(Int(Date().timeIntervalSince1970 * 1_000_000))-\(arc4random())"
            var entry = ClipboardEntry(
                id: uniqueImgId,
                contentType: "image",
                imagePath: imagePath,
                sourceApp: sourceApp,
                sourceBundle: sourceBundle
            )

            if AppSettings.shared.isBlacklisted(sourceBundle) {
                entry.isSensitive = true
            }

            try DatabaseManager.shared.insert(entry)
            print("🖼️ 记录图片 [来自 \(sourceApp)]")
        } catch {
            print("❌ 记录图片失败: \(error)")
        }
    }
}
