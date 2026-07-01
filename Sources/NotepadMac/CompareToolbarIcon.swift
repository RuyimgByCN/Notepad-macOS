import AppKit

/// Loads Notepad-- toolbar icons bundled under `CompareIcons/`.
enum CompareToolbarIcon {
    static func image(named resourceName: String) -> NSImage? {
        let url = Localization.resourceBundle.url(
            forResource: resourceName,
            withExtension: "png",
            subdirectory: "CompareIcons"
        ) ?? Localization.resourceBundle.url(
            forResource: resourceName,
            withExtension: "png"
        )
        guard let url, let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = false
        return image
    }
}

