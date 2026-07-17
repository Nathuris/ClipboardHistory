import SwiftUI

/// 颜色扩展 - 支持深色模式自动适配
/// 根据 design-spec.md 中定义的配色方案
extension Color {

    // MARK: - 主色调

    /// 主蓝 #7EC8E3
    static let adaptivePrimary = Color(hex: "#7EC8E3")

    /// 主蓝深 #5BA4BD
    static let adaptivePrimaryDark = Color(hex: "#5BA4BD")

    /// 主蓝浅 #B8DEEE
    static let adaptivePrimaryLight = Color(hex: "#B8DEEE")

    /// 主蓝极浅（置顶背景）浅色: #E8F4F9 / 深色: #2A3A44
    static let adaptivePinBackground = Color(light: "#E8F4F9", dark: "#2A3A44")

    // MARK: - 中性色

    /// 面板背景 浅色: #FFFFFF / 深色: #2C2C2E
    static let adaptivePanelBackground = Color(light: "#FFFFFF", dark: "#2C2C2E")

    /// 卡片背景 浅色: #F8F9FA / 深色: #3A3A3C
    static let adaptiveCardBackground = Color(light: "#F8F9FA", dark: "#3A3A3C")

    /// 主要文字 浅色: #333333 / 深色: #F2F2F7
    static let adaptiveTextPrimary = Color(light: "#333333", dark: "#F2F2F7")

    /// 次要文字 浅色: #888888 / 深色: #98989D
    static let adaptiveTextSecondary = Color(light: "#888888", dark: "#98989D")

    /// 三级文字 浅色: #AAAAAA / 深色: #8E8E93
    static let adaptiveTextTertiary = Color(light: "#AAAAAA", dark: "#8E8E93")

    /// 分割线 浅色: #E8E8ED / 深色: #48484A
    static let adaptiveDivider = Color(light: "#E8E8ED", dark: "#48484A")

    // MARK: - 功能色

    /// 删除/错误 红色 #E07575
    static let adaptiveDestructive = Color(hex: "#E07575")

    /// 删除/错误 红色深 #C96060
    static let adaptiveDestructiveDark = Color(hex: "#C96060")

    /// 成功 绿色 #7BC89C
    static let adaptiveSuccess = Color(hex: "#7BC89C")

    /// 警告 黄色 #E8D07A
    static let adaptiveWarning = Color(hex: "#E8D07A")

    // MARK: - 置顶边框

    /// 置顶边框 浅色: #B8DEEE / 深色: #3A5A6A
    static let adaptivePinBorder = Color(light: "#B8DEEE", dark: "#3A5A6A")

    /// 普通边框 浅色: #E8E8ED / 深色: #48484A
    static let adaptiveBorder = Color(light: "#E8E8ED", dark: "#48484A")

    // MARK: - 按钮状态

    /// 未激活按钮 浅色: #CCCCCC / 深色: #636366
    static let adaptiveButtonInactive = Color(light: "#CCCCCC", dark: "#636366")
}

// MARK: - 深色模式适配初始化方法

extension Color {
    /// 创建自适应深色模式的颜色
    /// - Parameters:
    ///   - light: 浅色模式的 Hex 颜色值
    ///   - dark: 深色模式的 Hex 颜色值
    init(light: String, dark: String) {
        let nsColor = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(hex: hex) ?? NSColor.black
        }
        self.init(nsColor: nsColor)
    }
}

// MARK: - NSColor Hex 初始化

extension NSColor {
    /// 从 Hex 字符串创建 NSColor
    /// - Parameter hex: Hex 颜色字符串（支持 #RGB, #RRGGBB, #RRGGBBAA）
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
