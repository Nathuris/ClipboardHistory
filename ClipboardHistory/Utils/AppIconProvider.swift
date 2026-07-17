import AppKit

/// 通过 Bundle ID 获取 App 图标
enum AppIconProvider {

    /// 根据 Bundle ID 获取 App 图标（32x32 像素）
    /// - Parameter bundleId: App 的 Bundle Identifier，如 "com.apple.Safari"
    /// - Returns: NSImage 图标，获取失败返回 nil
    static func icon(for bundleId: String) -> NSImage? {
        // 尝试通过 Bundle ID 找到 App 路径
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleId
        ) else {
            // 如果找不到具体 App，返回默认图标
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        }

        // 从 App 包中提取图标
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }

    /// 根据 App 显示名称获取图标（备用方案）
    /// - Parameter appName: App 显示名称，如 "Safari"
    /// - Returns: NSImage 图标
    static func icon(forAppName appName: String) -> NSImage? {
        // 查找正在运行的 App
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.localizedName == appName }),
           let bundleId = app.bundleIdentifier {
            return icon(for: bundleId)
        }

        // 返回默认图标
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil)
    }
}
