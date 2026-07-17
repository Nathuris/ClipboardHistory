import AppKit
import Carbon

/// 全局快捷键管理器 — 使用 Carbon RegisterEventHotKey
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    /// 由 AppDelegate 注入的回调闭包
    var toggleAction: (() -> Void)?

    func register() {
        unregister()

        let keyCode = UInt32(AppSettings.shared.shortcutKeyCode)
        let modifiers = UInt32(AppSettings.shared.shortcutModifiers)

        var gEventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(
            Unmanaged.passUnretained(self).toOpaque()
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let userData = userData else { return -1 }
                Unmanaged<HotkeyManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                    .handleHotkey()
                return noErr
            },
            1,
            &gEventType,
            selfPtr,
            &eventHandler
        )

        guard status == noErr else {
            print("❌ 快捷键事件处理器安装失败: \(status)")
            return
        }

        let hotkeyID = EventHotKeyID(signature: 0x4348_4953, id: 1)
        let regStatus = RegisterEventHotKey(
            keyCode, modifiers, hotkeyID,
            GetApplicationEventTarget(), 0, &hotkeyRef
        )

        if regStatus == noErr {
            print("⌨️ 全局快捷键已注册: \(AppSettings.shared.shortcutDisplayString)")
        } else {
            print("❌ 快捷键注册失败: \(regStatus)")
        }
    }

    func unregister() {
        if let ref = hotkeyRef { UnregisterEventHotKey(ref); hotkeyRef = nil }
        if let handler = eventHandler { RemoveEventHandler(handler); eventHandler = nil }
    }

    private func handleHotkey() {
        DispatchQueue.main.async { [weak self] in
            self?.toggleAction?()
        }
    }
}
