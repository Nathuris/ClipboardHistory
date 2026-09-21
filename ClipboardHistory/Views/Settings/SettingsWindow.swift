import SwiftUI

/// 设置窗口 — 包含通用、快捷键、隐私、关于四个选项卡
///
/// 注意：这里**不给每个页面硬性规定高度**。
/// 曾因把「通用」页写死成 250 点高，而该页内容实际需要 323 点，
/// 导致底部的「启动」一栏（开机自启开关）被裁掉、用户完全看不到。
/// 现在改为由窗口保证足够空间、各页按自身内容自然撑开。
struct SettingsWindow: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            ShortcutSettingsView()
                .tabItem {
                    Label("快捷键", systemImage: "command")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("隐私", systemImage: "hand.raised")
                }

            AboutView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 440, minHeight: 440)
    }
}
