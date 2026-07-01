import AppKit

/// Loads Notepad++ upstream toolbar bitmaps bundled under `UpstreamToolbar/`.
enum UpstreamToolbarBitmap {
    static func image(named resourceName: String) -> NSImage? {
        let url = Localization.resourceBundle.url(
            forResource: resourceName,
            withExtension: "bmp",
            subdirectory: "UpstreamToolbar"
        ) ?? Localization.resourceBundle.url(
            forResource: resourceName,
            withExtension: "bmp"
        )
        guard let url, let image = NSImage(contentsOf: url) else {
            return nil
        }
        let maskedImage = image.maskingToolbarBitmapBackground() ?? image
        maskedImage.isTemplate = false
        return maskedImage
    }
}

private extension NSImage {
    func maskingToolbarBitmapBackground() -> NSImage? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let maskColor = Self.dominantEdgeColor(in: pixels, width: width, height: height, bytesPerRow: bytesPerRow)

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                if pixels[offset] == maskColor.red,
                   pixels[offset + 1] == maskColor.green,
                   pixels[offset + 2] == maskColor.blue {
                    pixels[offset + 3] = 0
                } else if pixels[offset + 3] != 0 {
                    pixels[offset + 3] = 255
                }
            }
        }

        guard let maskedCGImage = context.makeImage() else {
            return nil
        }
        return NSImage(cgImage: maskedCGImage, size: size)
    }

    private static func dominantEdgeColor(
        in pixels: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int
    ) -> ToolbarBitmapColor {
        var counts: [ToolbarBitmapColor: Int] = [:]

        func record(x: Int, y: Int) {
            let offset = y * bytesPerRow + x * 4
            let color = ToolbarBitmapColor(
                red: pixels[offset],
                green: pixels[offset + 1],
                blue: pixels[offset + 2]
            )
            counts[color, default: 0] += 1
        }

        for x in 0..<width {
            record(x: x, y: 0)
            if height > 1 {
                record(x: x, y: height - 1)
            }
        }
        if height > 2 {
            for y in 1..<(height - 1) {
                record(x: 0, y: y)
                if width > 1 {
                    record(x: width - 1, y: y)
                }
            }
        }

        return counts.max { $0.value < $1.value }?.key ?? ToolbarBitmapColor(red: 0, green: 0, blue: 0)
    }
}

private struct ToolbarBitmapColor: Hashable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
}
