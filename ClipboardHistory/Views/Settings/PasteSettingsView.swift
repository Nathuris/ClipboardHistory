import SwiftUI

/// 粘贴设置 — 「点击后自动粘贴」开关与辅助功能权限引导
///
/// 单独开一页而不是塞进「通用」页：连同权限引导在内这一块内容较高，
/// 塞进「通用」会把那一页撑到 605 点、被窗口裁掉（曾实测确认）。
struct PasteSettingsView: View {
    /// 是否开启「点击后自动粘贴」
    @State private var autoPasteEnabled: Bool = AppSettings.shared.autoPasteEnabled
    /// 是否已获得「辅助功能」权限（自动粘贴的前提）
    @State private var hasAccessibilityPermission: Bool = AutoPaster.hasPermission

    var body: some View {
        Form {
            Section {
                Toggle("点击后自动粘贴", isOn: $autoPasteEnabled)
                    .font(.system(size: 14))
                    .onChange(of: autoPasteEnabled) { _, newValue in
                        AppSettings.shared.autoPasteEnabled = newValue
                    }
                    .padding(.vertical, 4)

                Text("开启后，点击历史条目会自动替你按下 ⌘V，内容直接出现在你刚才使用的软件里。"
                     + "关掉则回到原样：内容进剪贴板，你自己按 ⌘V 粘贴。")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#AAAAAA"))
                    .fixedSize(horizontal: false, vertical: true)

                // 开着自动粘贴、但还没拿到辅助功能权限时，给出可操作的授权引导
                if autoPasteEnabled && !hasAccessibilityPermission {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("还需要授予「辅助功能」权限")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#E07575"))

                        Text("macOS 出于安全，默认不允许软件替你按键盘。请点下面的按钮，"
                             + "在弹出的提示中打开系统设置，勾选本软件。"
                             + "授权之前点击条目仍会退回手动粘贴。")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#888888"))
                            .fixedSize(horizontal: false, vertical: true)

                        Button("去授权") {
                            AutoPaster.requestPermission()
                        }
                        .font(.system(size: 12))
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 6)
                } else if autoPasteEnabled && hasAccessibilityPermission {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#7EC8E3"))
                        Text("已获得辅助功能权限，自动粘贴可用")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#888888"))
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("自动粘贴")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .onAppear {
            refreshPermissionState()
        }
        // 用户很可能刚去系统设置授权再切回来，而系统不会通知权限变了
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            refreshPermissionState()
        }
    }

    /// 从系统读取真实状态，回填界面
    private func refreshPermissionState() {
        hasAccessibilityPermission = AutoPaster.hasPermission
        autoPasteEnabled = AppSettings.shared.autoPasteEnabled
    }
}
