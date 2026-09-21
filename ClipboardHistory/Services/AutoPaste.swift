import AppKit
import ApplicationServices
import Foundation

/// 自动粘贴 — 内容写进剪贴板后，替用户按下 Cmd+V
///
/// **关键前提**：macOS 出于安全，默认禁止软件操控键盘。
/// 要模拟按键，必须由用户在「系统设置 → 隐私与安全性 → 辅助功能」中授权。
/// 未授权时本模块不会做任何事，调用方应退回手动模式（内容已在剪贴板里，用户自己按 ⌘V）。
enum AutoPaster {

    // MARK: - 辅助功能权限

    /// 是否已获得辅助功能权限
    static var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    /// 请求授权。
    ///
    /// 用系统官方接口：未授权时它会弹出一个系统对话框，
    /// 里面带「打开系统设置」按钮，直接把用户送到对应的开关处。
    /// （不要自己拼 `x-apple.systempreferences:` 链接——那是私有格式，系统版本一变就可能失效。）
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - 模拟按键

    /// 模拟按下一次 Cmd+V
    ///
    /// 前提：目标 App 此刻必须已经是**前台**窗口，否则按键会送到别的地方去。
    /// 调用方需先切回焦点并留出一点时间。
    static func sendPasteKeystroke() {
        // V 键的虚拟键码是固定的 9
        let vKeyCode: CGKeyCode = 9

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

/// 记住「用户刚才在哪个 App」
///
/// 自动粘贴需要把焦点切回用户原本在用的 App。
/// 但面板一打开、前台就变成我们自己了，所以必须**持续跟踪**，
/// 记住最后一个不是本软件的前台 App。
final class FrontmostAppTracker {
    static let shared = FrontmostAppTracker()

    /// 最后一个不是本软件的前台 App
    private(set) var lastExternalApp: NSRunningApplication?

    private init() {}

    func start() {
        rememberCurrentFrontmost()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        rememberCurrentFrontmost()
    }

    private func rememberCurrentFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }
        lastExternalApp = app
    }
}
