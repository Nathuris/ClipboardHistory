import SwiftUI

/// 通用设置 — 保留天数选择 + 开机启动开关
///
/// 关于开机自启：开关的值**读自系统真实状态**（`LaunchAtLogin.state`），
/// 拨动后立即调用系统接口，并把系统反馈的真实结果回填到界面。
/// 这样界面永远不会出现「显示是开的、其实没开」的假象。
struct GeneralSettingsView: View {
    @State private var retentionDays: Int = AppSettings.shared.retentionDays

    /// 开机自启开关的当前值（以系统状态为准）
    @State private var launchAtLogin: Bool = LaunchAtLogin.state.isOn
    /// 是否处于「已登记，但需要用户去系统设置里批准」的状态
    @State private var waitingForApproval: Bool = LaunchAtLogin.state.isWaitingForApproval
    /// 系统异常时的说明（非空则禁用开关并显示）
    @State private var switchUnavailable: String?
    /// 设置失败时的提示文字（非空即弹出提示框）
    @State private var launchErrorMessage: String?
    /// 是否正在执行开机自启的设置操作（期间禁用开关，避免快速连拨造成的竞态）
    @State private var isBusy = false

    var body: some View {
        Form {
            Section {
                // 保留天数选择
                VStack(alignment: .leading, spacing: 10) {
                    Text("剪贴板保留天数")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#333333"))

                    Text("超过设定天数的非置顶内容将被自动清理")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#888888"))

                    Picker("", selection: $retentionDays) {
                        Text("1 天").tag(1)
                        Text("3 天").tag(3)
                        Text("5 天").tag(5)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                    .onChange(of: retentionDays) { _, newValue in
                        AppSettings.shared.retentionDays = newValue
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("数据保留")
            }

            Section {
                // 开机启动开关
                //
                // 这里刻意用自定义绑定，而不是 @State + .onChange。
                // 原因：设置失败时我们要把开关回填成系统真实状态，
                // 若用 .onChange，这次回填会再次触发 onChange，
                // 于是重复调用系统接口、并弹出第二个完全误导人的错误框。
                // 自定义绑定的 set 只在**用户真的拨动开关**时被调用，程序回填不会触发它。
                Toggle("开机时自动启动", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        // 上一次设置还没完成时忽略新的拨动。
                        // 否则「关掉后立刻打开」会出问题：注销是异步的，
                        // 第二次点击时系统状态还是「已登记」，代码会以为无需处理而跳过，
                        // 用户的「打开」就被悄悄丢掉了。
                        guard !isBusy else { return }
                        applyLaunchAtLogin(enabled: newValue)
                    }
                ))
                .font(.system(size: 14))
                .disabled(isBusy || switchUnavailable != nil)
                .padding(.vertical, 4)

                if let reason = switchUnavailable {
                    // 系统状态异常：说明原因
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#E07575"))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                } else if waitingForApproval {
                    // 已登记但被系统拦下：引导用户去批准
                    VStack(alignment: .leading, spacing: 6) {
                        Text("需要在系统设置中确认")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#E07575"))

                        Text("本软件已登记开机自启，但被系统拦下了。请到「系统设置 → 通用 → 登录项」中允许它；"
                             + "如果不想让它开机启动，把上面的开关关掉即可。")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#888888"))
                            .fixedSize(horizontal: false, vertical: true)

                        Button("打开系统设置") {
                            LaunchAtLogin.openLoginItemsSettings()
                        }
                        .font(.system(size: 12))
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 6)
                }
            } header: {
                Text("启动")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .onAppear {
            refreshLaunchState()
        }
        // 系统不会通知状态变化。用户很可能切到系统设置关掉它再切回来，
        // 所以每次本 App 重新被激活时都重读一次，保证界面与实际一致。
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            refreshLaunchState()
        }
        .alert(
            "无法设置开机自启",
            isPresented: Binding(
                get: { launchErrorMessage != nil },
                set: { if !$0 { launchErrorMessage = nil } }
            )
        ) {
            Button("知道了", role: .cancel) { launchErrorMessage = nil }
        } message: {
            Text(launchErrorMessage ?? "")
        }
    }

    // MARK: - 开机自启

    /// 从系统读取真实状态，回填界面
    private func refreshLaunchState() {
        let current = LaunchAtLogin.state
        launchAtLogin = current.isOn
        waitingForApproval = current.isWaitingForApproval
        switchUnavailable = current.errorDescription
    }

    /// 用户拨动开关：调用系统接口，然后无论成败都回读真实状态
    private func applyLaunchAtLogin(enabled: Bool) {
        isBusy = true
        // 先乐观更新，让开关立刻跟手；操作完成后会用系统真实状态覆盖
        launchAtLogin = enabled
        Task { @MainActor in
            defer { isBusy = false }
            if let failure = await LaunchAtLogin.setEnabled(enabled) {
                launchErrorMessage = failure
            }
            // 关键：回填系统真实状态，避免界面与实际不符
            refreshLaunchState()
        }
    }
}
