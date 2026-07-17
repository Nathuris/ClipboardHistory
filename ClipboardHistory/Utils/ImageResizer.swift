import AppKit
import Foundation

/// 图片缩略图生成工具
enum ImageResizer {

    /// 缩略图最大尺寸（宽或高不超过此值）
    static let maxThumbnailSize: CGFloat = 200

    /// 生成并保存缩略图
    /// - Parameters:
    ///   - image: 原始图片
    ///   - uuid: 对应条目的 UUID（用作文件名）
    static func saveThumbnail(_ image: NSImage, forUUID uuid: String) {
        guard let thumb = resize(image, toMax: maxThumbnailSize) else { return }

        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let thumbDir = appSupport
                .appendingPathComponent("ClipboardHistory")
                .appendingPathComponent("Thumbnails")

            try FileManager.default.createDirectory(
                at: thumbDir,
                withIntermediateDirectories: true
            )

            let thumbPath = thumbDir.appendingPathComponent("\(uuid)_thumb.png")

            if let tiff = thumb.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                try png.write(to: thumbPath)
            }
        } catch {
            print("❌ 保存缩略图失败: \(error)")
        }
    }

    /// 获取缩略图路径
    static func thumbnailPath(for uuid: String) -> String? {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            return appSupport
                .appendingPathComponent("ClipboardHistory")
                .appendingPathComponent("Thumbnails")
                .appendingPathComponent("\(uuid)_thumb.png")
                .path
        } catch {
            return nil
        }
    }

    /// 等比例缩放图片
    static func resize(_ image: NSImage, toMax maxSize: CGFloat) -> NSImage? {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        // 计算缩放比例
        let scale = min(
            maxSize / originalSize.width,
            maxSize / originalSize.height,
            1.0  // 不放大
        )

        guard scale < 1.0 else { return image }  // 无需缩放

        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()

        return resized
    }
}
