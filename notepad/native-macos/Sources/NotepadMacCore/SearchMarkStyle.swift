/// Search mark style indicators 1-5 as used by Notepad++.
///
/// Scintilla reserves indicators 0-7 for platform use;
/// Notepad++ uses indicators INDICATOR_CONTAINER (0)
/// and indicators 1-5 for find/style marks.
public enum SearchMarkStyle: Int, CaseIterable, Sendable {
    case style1 = 1
    case style2 = 2
    case style3 = 3
    case style4 = 4
    case style5 = 5

    public var displayName: String {
        switch self {
        case .style1: return "Style 1"
        case .style2: return "Style 2"
        case .style3: return "Style 3"
        case .style4: return "Style 4"
        case .style5: return "Style 5"
        }
    }

    /// Default highlight colour (RGB components 0-255).
    public var defaultColor: (red: Int, green: Int, blue: Int) {
        switch self {
        case .style1: return (255, 0, 0)       // red
        case .style2: return (0, 0, 255)       // blue
        case .style3: return (0, 128, 0)       // green
        case .style4: return (128, 0, 128)     // purple
        case .style5: return (255, 165, 0)     // orange
        }
    }
}
