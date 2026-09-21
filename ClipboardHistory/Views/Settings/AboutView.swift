import SwiftUI

/// 关于页面
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App 图标
            Image(systemName: "clipboard")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#7EC8E3"))
                .frame(width: 80, height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(hex: "#E8F4F9"))
                )

            // 名称和版本
            VStack(spacing: 6) {
                Text("ClipboardHistory")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#333333"))
                Text("版本 1.0")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#888888"))
            }

            Text("macOS 历史剪贴板管理工具\n自动记录、搜索、管理你的剪贴板内容")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#AAAAAA"))
                .multilineTextAlignment(.center)

            Spacer()

            Button("退出应用") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 13))
            .foregroundColor(Color(hex: "#888888"))
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
