import SwiftUI

/// 通用设置 — 保留天数选择 + 开机启动开关
struct GeneralSettingsView: View {
    @State private var retentionDays: Int = AppSettings.shared.retentionDays
    @State private var launchAtLogin: Bool = AppSettings.shared.launchAtLogin

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
                    .onChange(of: retentionDays) { newValue in
                        AppSettings.shared.retentionDays = newValue
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("数据保留")
            }

            Section {
                // 开机启动
                Toggle("开机时自动启动", isOn: $launchAtLogin)
                    .font(.system(size: 14))
                    .onChange(of: launchAtLogin) { newValue in
                        AppSettings.shared.launchAtLogin = newValue
                    }
                    .padding(.vertical, 4)
            } header: {
                Text("启动")
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
