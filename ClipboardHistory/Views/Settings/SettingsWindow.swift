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

            PasteSettingsView()
                .tabItem {
                    Label("粘贴", systemImage: "doc.on.clipboard")
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
        // 尺寸取「最挤的那一页需要多高」再留余量。
        //
        // 当前各页实测（含最坏情况）：通用 323 / 粘贴 332 / 快捷键 187 / 关于 301，
        // 加上标签栏约 50 点，440 高足够全部放下，**任何一页都不需要滚动**。
        //
        // 若日后往某页加了较多内容，有两种选择，不要盲目撑大窗口：
        //   1. 把内容拆到新标签页（推荐，本次即如此）
        //   2. 保持窗口尺寸，让该页滚动——Form 自带滚动能力，
        //      但 macOS 默认不显示滚动条，藏在下方的内容用户可能永远发现不了
        //      （这正是 2026-09-21 那次「开关看不见」事故的成因）。
        // 改动设置页内容后务必重新测量，方法见 dev-logs/2026-09-21.md。
        .frame(minWidth: 440, minHeight: 440)
    }
}
