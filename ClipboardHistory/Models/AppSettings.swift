import Foundation

// Carbon 修饰键常量（不 import Carbon 以避免导出时的兼容问题）
private let cmdKey: Int     = 256   // 1 << 8
private let shiftKey: Int   = 512   // 1 << 9
private let optionKey: Int  = 2048  // 1 << 11
private let controlKey: Int = 4096  // 1 << 12

/// 管理 App 的所有用户设置（基于 UserDefaults）
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - 存储键

    private enum Keys {
        static let retentionDays = "retention_days"
        static let blacklistedBundles = "blacklisted_bundles"
        static let autoPasteEnabled = "auto_paste_enabled"
        static let shortcutKeyCode = "shortcut_keyCode"
        static let shortcutModifiers = "shortcut_modifiers"
    }

    // MARK: - 设置项

    /// 保留天数：1、3 或 5，默认为 3
    var retentionDays: Int {
        get {
            let value = defaults.integer(forKey: Keys.retentionDays)
            return [1, 3, 5].contains(value) ? value : 3
        }
        set {
            defaults.set(newValue, forKey: Keys.retentionDays)
        }
    }

    /// 黑名单 App 的 Bundle ID 列表
    var blacklistedBundles: [String] {
        get {
            defaults.stringArray(forKey: Keys.blacklistedBundles) ?? []
        }
        set {
            defaults.set(newValue, forKey: Keys.blacklistedBundles)
        }
    }

    /// 检查某个 Bundle ID 是否在黑名单中
    func isBlacklisted(_ bundleId: String) -> Bool {
        blacklistedBundles.contains(bundleId)
    }

    /// 是否开启「自动粘贴」：点击历史条目后，自动替用户按下 Cmd+V
    ///
    /// 默认**开启**。注意：`UserDefaults.bool(forKey:)` 在键不存在时返回 false，
    /// 所以不能直接用它当默认值，必须先判断键是否存在，否则默认会变成「关」。
    var autoPasteEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.autoPasteEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.autoPasteEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.autoPasteEnabled)
        }
    }

    // MARK: - 快捷键

    /// 快捷键键码（Carbon key code，默认 9 = V）
    var shortcutKeyCode: Int {
        get { defaults.integer(forKey: Keys.shortcutKeyCode) == 0 ? 9 : defaults.integer(forKey: Keys.shortcutKeyCode) }
        set { defaults.set(newValue, forKey: Keys.shortcutKeyCode) }
    }

    /// 快捷键修饰键（Carbon modifier mask，默认 cmd+shift）
    var shortcutModifiers: Int {
        get {
            let v = defaults.integer(forKey: Keys.shortcutModifiers)
            return v == 0 ? Int(cmdKey | shiftKey) : v
        }
        set { defaults.set(newValue, forKey: Keys.shortcutModifiers) }
    }

    /// 快捷键的人类可读描述
    var shortcutDisplayString: String {
        var parts: [String] = []
        let mods = shortcutModifiers
        if mods & Int(cmdKey) != 0 { parts.append("⌘") }
        if mods & Int(shiftKey) != 0 { parts.append("⇧") }
        if mods & Int(optionKey) != 0 { parts.append("⌥") }
        if mods & Int(controlKey) != 0 { parts.append("⌃") }

        // Carbon key code → 字符映射
        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P",
            37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            49: "Space", 36: "Return", 53: "Escape", 51: "Delete",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        parts.append(keyMap[shortcutKeyCode] ?? "Key\(shortcutKeyCode)")
        return parts.joined()
    }
}
