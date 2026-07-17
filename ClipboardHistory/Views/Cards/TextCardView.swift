import SwiftUI

/// 纯文字内容卡片的可展开视图（用于详情展示）
struct TextCardView: View {
    let entry: ClipboardEntry

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // 来源图标
                if let icon = AppIconProvider.icon(for: entry.sourceBundle) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                }

                Text(entry.sourceApp)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.adaptivePrimary)

                Spacer()

                Text(entry.createdAt.relativeDisplay)
                    .font(.system(size: 11))
                    .foregroundColor(.adaptiveTextTertiary)
            }

            if entry.isSensitive {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.adaptiveDestructive)
                    Text("敏感内容 — 需要验证后查看")
                        .font(.system(size: 13))
                        .foregroundColor(.adaptiveDestructive)
                }
            } else {
                Text(entry.textContent ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(.adaptiveTextPrimary)
                    .lineLimit(isExpanded ? nil : 4)
                    .onTapGesture {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptiveCardBackground)
        )
    }
}
