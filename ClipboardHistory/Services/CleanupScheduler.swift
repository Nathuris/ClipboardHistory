import Foundation

/// 定时清理器 — 按保留天数自动清理过期数据
final class CleanupScheduler {
    static let shared = CleanupScheduler()

    private var timer: Timer?

    /// 清理检查间隔（秒）— 每小时检查一次
    private let checkInterval: TimeInterval = 3600

    // MARK: - 启动/停止

    func start() {
        // 启动时立即执行一次清理
        performCleanup()

        // 设置定时器，每小时检查一次
        timer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            self?.performCleanup()
        }

        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        print("🧹 定时清理已启动（间隔 \(Int(checkInterval / 3600)) 小时）")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 清理逻辑

    private func performCleanup() {
        let retentionDays = AppSettings.shared.retentionDays

        do {
            let removedCount = try DatabaseManager.shared.cleanupExpired(
                retentionDays: retentionDays
            )
            if removedCount > 0 {
                print("🧹 清理了 \(removedCount) 条过期记录（保留天数: \(retentionDays)）")
            }
        } catch {
            print("❌ 清理过期数据失败: \(error)")
        }
    }
}
