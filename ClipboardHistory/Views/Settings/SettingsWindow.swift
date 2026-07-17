import SwiftUI

/// 设置窗口 — 包含通用、快捷键、隐私、关于四个选项卡
struct SettingsWindow: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }
                .frame(width: 400, height: 250)

            ShortcutSettingsView()
                .tabItem {
                    Label("快捷键", systemImage: "command")
                }
                .frame(width: 400, height: 250)

            PrivacySettingsView()
                .tabItem {
                    Label("隐私", systemImage: "hand.raised")
                }

            AboutView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .frame(width: 400, height: 250)
        }
        .frame(minWidth: 420, minHeight: 380)
    }
}
