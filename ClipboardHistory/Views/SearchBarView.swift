import SwiftUI

/// 搜索栏视图
struct SearchBarView: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            // 搜索图标
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.adaptiveTextSecondary)

            // 搜索输入框
            TextField("搜索剪贴板历史...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(.adaptiveTextPrimary)

            // 清空按钮
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.adaptiveTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptiveCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.adaptivePrimaryLight, lineWidth: 1)
                )
        )
    }
}
