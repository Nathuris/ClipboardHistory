import SwiftUI
import AppKit

/// 隐私设置 — 黑名单 App 管理
struct PrivacySettingsView: View {
    @State private var blacklistedBundles: [String] = AppSettings.shared.blacklistedBundles
    @State private var installedApps: [(name: String, bundleId: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("黑名单应用")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#333333"))

            Text("从以下应用复制的内容将被加密存储，查看时需要 Touch ID 或密码验证。点击应用名称来添加或移除锁定。")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#888888"))
                .fixedSize(horizontal: false, vertical: true)

            if installedApps.isEmpty {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("正在扫描已安装的应用...")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#888888"))
                }
            } else {
                List {
                    ForEach(installedApps, id: \.bundleId) { app in
                        HStack {
                            if let icon = AppIconProvider.icon(for: app.bundleId) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            Text(app.name)
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#333333"))
                            Spacer()
                            if blacklistedBundles.contains(app.bundleId) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#E07575"))
                                Text("已锁定")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#E07575"))
                            } else {
                                Text("未锁定")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#AAAAAA"))
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleBlacklist(app.bundleId)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(20)
        .onAppear {
            loadInstalledApps()
        }
    }

    private func loadInstalledApps() {
        var apps: [(name: String, bundleId: String)] = []
        let fileManager = FileManager.default

        // 扫描 ~/Applications 和 /Applications
        let searchPaths = [
            NSHomeDirectory() + "/Applications",
            "/Applications",
            "/System/Applications",
        ]

        for path in searchPaths {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let appPath = path + "/" + item
                let name = (item as NSString).deletingPathExtension

                // 读取 Bundle ID
                let infoPath = appPath + "/Contents/Info.plist"
                guard let info = NSDictionary(contentsOfFile: infoPath),
                      let bundleId = info["CFBundleIdentifier"] as? String else { continue }

                // 去重
                if !apps.contains(where: { $0.bundleId == bundleId }) {
                    apps.append((name: name, bundleId: bundleId))
                }
            }
        }

        // 已锁定的排在前面
        installedApps = apps.sorted {
            let aLocked = blacklistedBundles.contains($0.bundleId)
            let bLocked = blacklistedBundles.contains($1.bundleId)
            if aLocked != bLocked { return aLocked }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func toggleBlacklist(_ bundleId: String) {
        if blacklistedBundles.contains(bundleId) {
            blacklistedBundles.removeAll { $0 == bundleId }
        } else {
            blacklistedBundles.append(bundleId)
        }
        AppSettings.shared.blacklistedBundles = blacklistedBundles
    }
}
