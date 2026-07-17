import SwiftUI
import AppKit

/// 快捷键录制视图
struct ShortcutSettingsView: View {
    @State private var isRecording = false
    @State private var currentDisplay = AppSettings.shared.shortcutDisplayString

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("全局快捷键")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#333333"))

            Text("设置一个全局快捷键来快速打开/关闭剪贴板面板")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#888888"))

            HStack(spacing: 16) {
                // 显示当前快捷键
                Text(currentDisplay)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(isRecording ? Color(hex: "#7EC8E3") : Color(hex: "#333333"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isRecording ? Color(hex: "#E8F4F9") : Color(hex: "#F8F9FA"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isRecording ? Color(hex: "#7EC8E3") : Color(hex: "#E8E8ED"),
                                        lineWidth: 1
                                    )
                            )
                    )

                Button(action: { isRecording ? stopRecording() : startRecording() }) {
                    Text(isRecording ? "点击按键..." : "录制快捷键")
                        .font(.system(size: 13))
                        .foregroundColor(isRecording ? Color(hex: "#E07575") : Color(hex: "#7EC8E3"))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color(hex: "#FFF0F0") : Color(hex: "#E8F4F9"))
                )
            }

            Text("提示：录制时按下你想要的组合键即可，支持 ⌘、⇧、⌥、⌃ 组合")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#AAAAAA"))
        }
        .padding(20)
        .onAppear {
            currentDisplay = AppSettings.shared.shortcutDisplayString
        }
    }

    private func startRecording() {
        isRecording = true
        // 监听本地按键事件
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isRecording else { return event }
            self.captureShortcut(event)
            return nil // 吞掉这个事件
        }
    }

    private func stopRecording() {
        isRecording = false
    }

    private func captureShortcut(_ event: NSEvent) {
        let keyCode = Int(event.keyCode)
        var modifiers: Int = 0

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) { modifiers |= 256 }   // cmdKey
        if flags.contains(.shift)   { modifiers |= 512 }   // shiftKey
        if flags.contains(.option)  { modifiers |= 2048 }  // optionKey
        if flags.contains(.control) { modifiers |= 4096 }  // controlKey

        // 至少需要一个修饰键
        guard modifiers != 0 else {
            isRecording = false
            return
        }

        // 保存设置
        AppSettings.shared.shortcutKeyCode = keyCode
        AppSettings.shared.shortcutModifiers = modifiers

        // 重新注册快捷键
        HotkeyManager.shared.register()

        // 更新显示
        currentDisplay = AppSettings.shared.shortcutDisplayString
        isRecording = false
    }
}
