import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()
        HotkeyManager.shared.toggleAction = { [weak self] in
            self?.menuBarController?.toggleFromHotkey()
        }
        print("✅ 菜单栏已就绪")
    }

    func togglePopoverFromHotkey() {
        menuBarController?.toggleFromHotkey()
    }
}
