import SwiftUI

/// 统一的卡片容器 — 根据内容类型分发到文字卡片或图片卡片
struct ClipboardCardView: View {
    let entry: ClipboardEntry
    let isUnlocked: Bool
    let onPaste: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void


    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 0) {
            // 卡片主体内容（可点击粘贴）
            Button(action: onPaste) {
                HStack(spacing: 10) {
                    // 来源 App 图标
                    if let icon = AppIconProvider.icon(forAppName: entry.sourceApp) ??
                                   AppIconProvider.icon(for: entry.sourceBundle) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .opacity(0.7)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // 来源 + 时间
                        HStack(spacing: 6) {
                            Text(entry.sourceApp)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.adaptiveTextSecondary)

                            Text(entry.createdAt.relativeDisplay)
                                .font(.system(size: 11))
                                .foregroundColor(.adaptiveTextTertiary)

                            if entry.isSensitive {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.adaptiveDestructive)
                            }
                        }

                        // 内容预览
                        contentPreview
                    }

                    Spacer(minLength: 4)
                }
                .padding(.leading, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            // 右侧操作按钮区
            HStack(spacing: 4) {
                // 置顶按钮
                Button(action: onTogglePin) {
                    Image(systemName: entry.isPinned ? "pin.slash" : "pin.fill")
                        .font(.system(size: 13))
                        .foregroundColor(
                            entry.isPinned
                                ? .adaptivePrimary
                                : .adaptiveButtonInactive
                        )
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(entry.isPinned ? "取消置顶" : "置顶")

                // 删除按钮
                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.adaptiveButtonInactive)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("删除")
            }
            .padding(.trailing, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(entry.isPinned
                    ? Color.adaptivePinBackground
                    : Color.adaptiveCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    entry.isPinned
                        ? Color.adaptivePinBorder
                        : Color.adaptiveBorder,
                    lineWidth: 0.5
                )
        )
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive, action: onDelete)
        } message: {
            Text("这条剪贴板记录将被永久删除。")
        }
    }

    // MARK: - 内容预览

    @ViewBuilder
    private var contentPreview: some View {
        switch entry.contentType {
        case "text":
            if entry.isSensitive && !isUnlocked {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.adaptiveDestructive)
                    Text("点击验证后查看内容")
                        .font(.system(size: 12))
                        .foregroundColor(.adaptiveDestructive)
                }
                .padding(.vertical, 4)
            } else {
                TextCardContent(text: entry.textContent ?? "")
            }
        case "image":
            if entry.isSensitive && !isUnlocked {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.adaptiveDestructive)
                    Text("点击验证后查看图片")
                        .font(.system(size: 12))
                        .foregroundColor(.adaptiveDestructive)
                }
                .padding(.vertical, 4)
            } else {
                ImageCardContent(imagePath: entry.imagePath, isSensitive: false)
            }
        default:
            Text("未知内容")
                .font(.system(size: 13))
                .foregroundColor(.adaptiveTextSecondary)
        }
    }
}

// MARK: - 文字卡片内容

struct TextCardContent: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(text.contains("🔒") ? .adaptiveDestructive : .adaptiveTextPrimary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - 图片卡片内容

struct ImageCardContent: View {
    let imagePath: String?
    let isSensitive: Bool

    var body: some View {
        if isSensitive {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.adaptiveDestructive)
                Text("敏感图片 — 点击验证后查看")
                    .font(.system(size: 12))
                    .foregroundColor(.adaptiveDestructive)
            }
            .padding(.vertical, 4)
        } else if let path = imagePath,
                  let nsImage = NSImage(contentsOfFile: path) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 80)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            HStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.system(size: 12))
                Text("图片（加载失败）")
                    .font(.system(size: 12))
            }
            .foregroundColor(.adaptiveTextTertiary)
            .padding(.vertical, 4)
        }
    }
}
