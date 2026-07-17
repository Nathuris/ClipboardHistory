import SwiftUI

/// 图片内容卡片（用于大图预览）
struct ImageCardView: View {
    let entry: ClipboardEntry

    @State private var showPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
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
                        .foregroundColor(.adaptiveDestructive)
                    Text("敏感图片 — 需要验证后查看")
                        .foregroundColor(.adaptiveDestructive)
                }
                .font(.system(size: 13))
            } else if let imagePath = entry.imagePath,
                      let nsImage = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onTapGesture {
                        showPreview = true
                    }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptiveCardBackground)
        )
        .sheet(isPresented: $showPreview) {
            // 图片大图预览
            if let imagePath = entry.imagePath,
               let nsImage = NSImage(contentsOfFile: imagePath) {
                VStack {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 600, maxHeight: 600)
                }
                .frame(width: 640, height: 640)
                .background(Color.adaptiveCardBackground)
            }
        }
    }
}
