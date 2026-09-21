import SwiftUI

/// 设置窗口 — 包含通用、粘贴、快捷键、隐私、关于五个选项卡
///
/// 关于尺寸，这是踩过两次坑才定下来的规则：
///
/// 1. **必须给每页固定宽度**。若不给宽度，各页会按自身内容的「理想宽度」把自己撑开：
///    「隐私」页内含一个列表，理想宽度可达 600 点以上，会把整个窗口撑得非常宽
///    （2026-09-21 实测，用户反馈「设置页面变得好宽」）。
///
/// 2. **不能给每页写死高度**。曾把「通用」页写死成 250 点高，而该页内容实际需要 323 点，
///    导致底部的「启动」一栏（开机自启开关）被裁掉、用户完全看不到。
///    高度应交给窗口统一保证。
struct SettingsWindow: View {
    /// 每一页统一的固定宽度（沿用最初设计值 400）
    private let paneWidth: CGFloat = 400

    var body: some View {
        TabView {
            GeneralSettingsView()
                .frame(width: paneWidth)
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            PasteSettingsView()
                .frame(width: paneWidth)
                .tabItem {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                }

            ShortcutSettingsView()
                .frame(width: paneWidth)
                .tabItem {
                    Label("快捷键", systemImage: "command")
                }

            PrivacySettingsView()
                .frame(width: paneWidth)
                .tabItem {
                    Label("隐私", systemImage: "hand.raised")
                }

            AboutView()
                .frame(width: paneWidth)
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        // 高度取「最挤的那一页需要多高」再留余量。
        //
        // 各页实测（含最坏情况）：通用 323 / 粘贴 332 / 快捷键 187 / 关于 301，
        // 加上标签栏约 50 点，440 高足以全部放下，**任何一页都不需要滚动**。
        //
        // 若日后某页内容变多，不要盲目撑大窗口，两种做法：
        //   1. 把内容拆到新标签页（推荐，2026-09-21 拆分「粘贴」页即如此）
        //   2. 保持窗口尺寸让该页滚动——Form 自带滚动能力，但 macOS 默认不显示滚动条，
        //      藏在下方的内容用户可能永远发现不了，这正是「开关看不见」事故的成因
        // 改动设置页内容后务必重新测量，方法见 dev-logs/2026-09-21.md。
        .frame(minHeight: 440)
    }
}
