import SwiftUI
import Combine

/// 主面板视图 — 搜索框 + 置顶区域 + 卡片列表 + 底部状态栏
struct HistoryPopover: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // 顶部搜索栏
            SearchBarView(text: $viewModel.searchText)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()
                .foregroundColor(.adaptiveDivider)

            // 卡片列表
            if viewModel.filteredEntries.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clipboard")
                        .font(.system(size: 40))
                        .foregroundColor(.adaptivePrimaryLight)
                    Text("暂无剪贴板记录")
                        .font(.system(size: 14))
                        .foregroundColor(.adaptiveTextSecondary)
                    Text("复制文字或图片后会自动出现在这里")
                        .font(.system(size: 12))
                        .foregroundColor(.adaptiveTextTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        // 置顶区域
                        let pinned = viewModel.filteredEntries.filter { $0.isPinned }
                        if !pinned.isEmpty {
                            PinnedSection(count: pinned.count)
                        }

                        // 所有卡片（置顶的已在排序中自然排前面）
                        ForEach(viewModel.filteredEntries) { entry in
                            ClipboardCardView(
                                entry: entry,
                                isUnlocked: viewModel.isUnlocked(entry),
                                onPaste: { viewModel.pasteEntry(entry) },
                                onTogglePin: { viewModel.togglePin(entry) },
                                onDelete: { viewModel.deleteEntry(entry) }
                            )
                            .padding(.horizontal, 10)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .trailing))
                            ))
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.filteredEntries.map(\.id))
                    }
                    .padding(.vertical, 8)
                }
            }

            Divider()
                .foregroundColor(.adaptiveDivider)

            // 底部状态栏
            HStack {
                Text("共 \(viewModel.filteredEntries.count) 条记录")
                    .font(.system(size: 11))
                    .foregroundColor(.adaptiveTextSecondary)

                Spacer()

                if viewModel.entries.count > 0 {
                    Button("清除") { viewModel.requestClearAll() }
                        .font(.system(size: 11))
                        .foregroundColor(.adaptiveDestructive)
                        .buttonStyle(.plain)
                }

                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundColor(.adaptiveTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("打开设置")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
        .onAppear {
            viewModel.startAutoRefresh()
        }
        .alert("确认清除", isPresented: $viewModel.showClearAllConfirm) {
            Button("取消", role: .cancel) { viewModel.cancelClearAll() }
            Button("全部清除", role: .destructive) { viewModel.confirmClearAll() }
        } message: {
            Text("将删除所有剪贴板记录，此操作无法撤销。")
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
            viewModel.relockAll()  // 关闭面板时重新锁定所有敏感内容
        }
    }
}

// MARK: - ViewModel

final class HistoryViewModel: ObservableObject {
    @Published var entries: [ClipboardEntry] = []
    @Published var searchText: String = ""

    private var refreshTimer: Timer?
    private var popoverCloseObserver: AnyCancellable?
    /// 本次已解锁的敏感条目 ID
    private var unlockedIds: Set<String> = []
    /// 已解密的内容缓存（key = entry.id）
    private var decryptedCache: [String: String] = [:]

    /// 检查条目是否已临时解锁
    func isUnlocked(_ entry: ClipboardEntry) -> Bool {
        !entry.isSensitive || unlockedIds.contains(entry.id)
    }

    /// 根据搜索文本过滤后的条目列表
    var filteredEntries: [ClipboardEntry] {
        let filtered = searchText.isEmpty
            ? entries
            : entries.filter {
                ($0.textContent ?? "").localizedCaseInsensitiveContains(searchText)
            }
        return ClipboardEntry.sortedByPinAndTime(filtered)
    }

    /// 启动自动刷新（每秒从数据库重新加载，不触发动画）
    func startAutoRefresh() {
        loadEntries()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.loadEntries(animated: false)
        }
        // 监听面板关闭通知，自动重新锁定
        popoverCloseObserver = NotificationCenter.default
            .publisher(for: .popoverDidClose)
            .sink { [weak self] _ in
                self?.relockAll()
            }
    }

    /// 停止自动刷新
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        popoverCloseObserver?.cancel()
        popoverCloseObserver = nil
    }

    /// 关闭面板时重新锁定所有敏感内容
    func relockAll() {
        unlockedIds.removeAll()
        decryptedCache.removeAll()
        loadEntries()
    }

    // MARK: - 一键清除

    @Published var showClearAllConfirm = false

    func requestClearAll() {
        showClearAllConfirm = true
    }

    func confirmClearAll() {
        try? DatabaseManager.shared.deleteAll()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            loadEntries()
        }
        showClearAllConfirm = false
    }

    func cancelClearAll() {
        showClearAllConfirm = false
    }

    /// 从数据库加载所有记录，并恢复已解密的内容
    func loadEntries(animated: Bool = true) {
        let block = {
            do {
                self.entries = try DatabaseManager.shared.fetchAll()
                // 恢复已解锁条目的解密内容
                for i in self.entries.indices {
                    if let cached = self.decryptedCache[self.entries[i].id] {
                        self.entries[i].textContent = cached
                    }
                }
            } catch {
                print("❌ 加载记录失败: \(error)")
                self.entries = []
            }
        }
        if animated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                block()
            }
        } else {
            block()
        }
    }

    /// 点击条目：敏感内容先解锁并解密显示，已解锁或非敏感内容直接粘贴
    func pasteEntry(_ entry: ClipboardEntry) {
        if entry.isSensitive && !unlockedIds.contains(entry.id) {
            // 敏感且未解锁 → 先验证 + 解密
            PrivacyManager.shared.authenticate { [weak self] success in
                guard let self = self, success else { return }
                // 解锁同一黑名单 App 的所有记录
                let bundle = entry.sourceBundle
                for i in self.entries.indices where self.entries[i].sourceBundle == bundle && self.entries[i].isSensitive {
                    let id = self.entries[i].id
                    self.unlockedIds.insert(id)
                    if let encrypted = self.entries[i].encryptedData,
                       let decrypted = PrivacyManager.shared.decrypt(encrypted) {
                        self.decryptedCache[id] = decrypted
                        self.entries[i].textContent = decrypted
                    }
                }
            }
        } else {
            // 已解锁或非敏感 → 直接粘贴
            doPaste(entry)
        }
    }

    private func doPaste(_ entry: ClipboardEntry) {
        // 粘贴时忽略本次剪贴板变化，避免生成重复记录
        ClipboardMonitor.shared.ignoreNextChange()

        // 更新时间戳，使该条目排到最前面
        try? DatabaseManager.shared.updateTimestamp(id: entry.id)
        loadEntries()  // 刷新列表并动画移动

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch entry.contentType {
        case "text":
            let text: String
            if entry.isSensitive, let encrypted = entry.encryptedData {
                // 解密后写入剪贴板
                text = PrivacyManager.shared.decrypt(encrypted) ?? ""
            } else {
                text = entry.textContent ?? ""
            }
            pasteboard.setString(text, forType: .string)

        case "image":
            if let path = entry.imagePath,
               let image = NSImage(contentsOfFile: path) {
                pasteboard.writeObjects([image])
            }

        default:
            break
        }

        print("📋 已粘贴: \(entry.contentType)")
    }

    /// 切换置顶状态
    func togglePin(_ entry: ClipboardEntry) {
        do {
            try DatabaseManager.shared.togglePin(id: entry.id)
            loadEntries()  // 内置动画
        } catch {
            print("❌ 切换置顶失败: \(error)")
        }
    }

    /// 删除条目
    func deleteEntry(_ entry: ClipboardEntry) {
        do {
            try DatabaseManager.shared.delete(id: entry.id)
            loadEntries()  // 内置动画
        } catch {
            print("❌ 删除失败: \(error)")
        }
    }

    /// 打开设置窗口
    func openSettings() {
        // 触发设置窗口打开
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

// MARK: - 置顶区域标识

struct PinnedSection: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "pin.fill")
                .font(.system(size: 10))
                .foregroundColor(.adaptivePrimary)
            Text("已置顶 (\(count))")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.adaptivePrimary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Color.adaptivePinBackground)
    }
}
