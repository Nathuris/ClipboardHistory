import AppKit
import SwiftUI

extension Notification.Name {
    static let popoverDidClose = Notification.Name("popoverDidClose")
    /// 由面板内部发出：请求把面板收起来
    /// （自动粘贴前必须先收起面板，否则模拟的 ⌘V 会打到我们自己身上）
    static let requestClosePopover = Notification.Name("requestClosePopover")
}

/// 菜单栏控制器 — 管理 NSStatusBar 图标和 Popover
final class MenuBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    override init() {
        super.init()
        setupMenuBar()
        setupPopover()

        // 面板内部请求收起面板时（例如自动粘贴前要让出前台）响应之
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopover),
            name: .requestClosePopover,
            object: nil
        )
    }

    // MARK: - 菜单栏图标

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        if let button = statusItem?.button {
            // 使用 SF Symbol 作为菜单栏图标
            button.image = NSImage(
                systemSymbolName: "clipboard",
                accessibilityDescription: "剪贴板历史"
            )
            button.target = self
            button.action = #selector(togglePopover)
            button.toolTip = "剪贴板历史"

            // 适配不同菜单栏高度
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true  // 自动适配深色/浅色模式
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover?.delegate = self
        popover?.contentSize = NSSize(width: 360, height: 500)
        popover?.behavior = .semitransient  // 点击外部关闭，Touch ID 时不消失
        popover?.animates = true

        // 设置 SwiftUI 视图作为 Popover 内容
        let contentView = HistoryPopover()
        popover?.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            // 显示 Popover
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )

            // 监听全局事件，用于检测点击外部区域
            eventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    @objc private func closePopover() {
        popover?.performClose(nil)

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        // 通知面板重新锁定敏感内容
        NotificationCenter.default.post(name: .popoverDidClose, object: nil)
    }

    /// 外部调用：通过快捷键切换 Popover
    func toggleFromHotkey() {
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
            eventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.closePopover()
            }
        }
    }
}
