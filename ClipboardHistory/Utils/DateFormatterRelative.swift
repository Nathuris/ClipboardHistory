import Foundation

/// 相对时间格式化工具
extension Date {
    /// 返回相对时间字符串，如"刚刚"、"3 分钟前"、"2 小时前"、"昨天 14:30"
    var relativeDisplay: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.second, .minute, .hour, .day], from: self, to: now)

        if let day = components.day, day > 1 {
            // 超过 1 天 → 显示具体日期和时间
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")

            if day <= 7 {
                // 一周内显示"周X HH:mm"
                formatter.dateFormat = "EEEE HH:mm"
            } else {
                // 更早显示"MM-dd HH:mm"
                formatter.dateFormat = "MM-dd HH:mm"
            }
            return formatter.string(from: self)
        }

        if let day = components.day, day == 1 {
            // 昨天
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: self))"
        }

        if let hour = components.hour, hour > 0 {
            // 几小时前
            let min = components.minute ?? 0
            if min > 0 {
                return "\(hour) 小时 \(min) 分钟前"
            }
            return "\(hour) 小时前"
        }

        if let minute = components.minute, minute > 0 {
            return "\(minute) 分钟前"
        }

        return "刚刚"
    }
}
