import AppKit
import Foundation
import ServiceManagement

/// 开机自启管理器
///
/// 设计要点：**一切以 macOS 系统的真实状态为准**。
/// 开关的当前值直接读 `SMAppService.mainApp.status`，而不是把「开/关」记在 UserDefaults 里。
///
/// 为什么必须这样：早先的实现只把开关状态写进 UserDefaults，从不调用任何系统接口，
/// 结果造出了一个「看起来打开了、实际什么都没做」的假开关——用户拨了它，
/// 重启电脑后软件并不会自动运行，而且界面上完全看不出来。
///
/// 系统**不会通知**状态变化（没有 KVO、也没有通知），所以每次显示界面、
/// 以及每次 App 重新被激活时，都要重新读一次 `state`。
enum LaunchAtLogin {

    // MARK: - 状态

    /// 开机自启的当前状态（读自系统）
    enum State {
        /// 已登记，且已生效
        case enabled
        /// 未登记
        case disabled
        /// 已登记，但用户在「系统设置 → 通用 → 登录项」里把它关掉了，需要用户手动批准
        case requiresApproval
        /// 系统返回了没见过或不正常的结果，附带给用户看的中文说明
        case unavailable(String)

        /// 对用户而言，这个状态算「开」还是「关」
        ///
        /// `requiresApproval` 也算「开」：系统里确实已登记，只是等用户批准。
        /// 若显示成「关」，用户会以为自己没拨成功，反复去拨。
        var isOn: Bool {
            switch self {
            case .enabled, .requiresApproval: return true
            case .disabled, .unavailable: return false
            }
        }

        /// 是否处于「已登记、但需要用户在系统设置里手动批准」的状态
        var isWaitingForApproval: Bool {
            if case .requiresApproval = self { return true }
            return false
        }

        /// 若是异常状态，取出给用户看的说明
        var errorDescription: String? {
            if case .unavailable(let message) = self { return message }
            return nil
        }
    }

    /// 读取系统真实状态
    ///
    /// 实测结论（macOS 14，2026-09-21）：**一个从未登记过开机自启的 App，
    /// 系统返回的是 `.notFound`，而不是 `.notRegistered`**。
    /// 所以 `.notFound` 是「还没开启过」的正常状态，绝不能当成错误报给用户——
    /// 否则每个第一次看到这个开关的人，都会被弹一句吓人的报错。
    ///
    /// 实测依据：用与本 App 完全相同的包配置（bundle id `com.clipboardhistory.app`、
    /// ad-hoc 签名、置于 `~/Applications`），登记前 status 为 `.notFound`，
    /// 调用 `register()` 成功变为 `.enabled`，`unregister()` 后又变为 `.notRegistered`。
    ///
    /// 若软件真的装在不合适的位置（如从编译目录直接运行），真正的失败会由
    /// `setEnabled(_:)` 里的 `register()` 抛出并转成中文提示，不会漏报。
    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            return .disabled
        @unknown default:
            return .unavailable("系统返回了未知状态，暂时无法设置开机自启。")
        }
    }

    // MARK: - 设置

    /// 打开或关闭开机自启
    /// - Returns: 成功返回 `nil`；失败返回一句可以直接显示给用户看的中文原因
    @discardableResult
    static func setEnabled(_ enabled: Bool) async -> String? {
        let current = SMAppService.mainApp.status
        do {
            if enabled {
                // 已登记（含「待用户批准」）时重复注册会报错，直接跳过
                guard current != .enabled, current != .requiresApproval else { return nil }
                try SMAppService.mainApp.register()
            } else {
                // 本来就没登记时去注销会报「Operation not permitted」（已实测），直接跳过
                guard current != .notRegistered, current != .notFound else { return nil }
                // 用异步版：它会等系统真正注销完成。
                // 同步版不等待，紧接着再注册会失败。
                try await SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return friendlyMessage(for: error)
        }
    }

    /// 打开「系统设置 → 通用 → 登录项」，方便用户手动批准本应用
    ///
    /// 用系统官方接口，不要自己拼 `x-apple.systempreferences:` 链接——
    /// 那是私有格式，系统版本一变就可能失效。
    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - 错误信息本地化

    /// 把系统抛出的英文错误，翻译成用户看得懂的中文提示
    ///
    /// 注意两件事：
    /// 1. 运行时抛出的错误域是 `SMAppServiceErrorDomain`（实测确认），
    ///    而 `SMAppServiceErrorDomain` 这个**常量**要 macOS 15 才有，
    ///    本 App 最低支持 14，所以这里只能用字符串字面量比较。
    /// 2. `SMErrors.h` 里那套 `kSMError*`（2、3、6、11、12…）与运行时实际抛出的码
    ///    **不是同一套**（实测抛出的是 1「Operation not permitted」，不在这张表里）。
    ///    所以不能靠数字猜含义，只能对确知的码给提示，其余回落到系统原文。
    private static func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == "SMAppServiceErrorDomain" {
            switch nsError.code {
            case 1:
                // 实测：从非「应用程序」目录运行、重复注册等情况下会出现。
                // 这里不把原因说死，只给出最常见的排查方向；
                // 系统原文附在后面，便于排查时对照。
                return "系统拒绝了这次设置。最常见的原因是软件没有放在「应用程序」文件夹里，"
                     + "或不是从那里启动的。\n（系统原话：\(nsError.localizedDescription)）"
            default:
                break
            }
        }

        // 其余错误：给出中文说明，并保留系统原文便于排查
        return "系统未能完成设置：\(nsError.localizedDescription)"
    }
}
