import AppKit

struct WorkbenchTag: Equatable {
    let key: String
    let label: String
    let colorID: WorkbenchTagColorID

    init(key: String, label: String? = nil, colorID: WorkbenchTagColorID = .blue) {
        self.key = key
        self.label = label ?? key
        self.colorID = colorID
    }
}

enum WorkbenchTagColorID: String, Equatable {
    case `default`
    case gray
    case brown
    case orange
    case yellow
    case green
    case blue
    case purple
    case pink
    case red

    var appKitForegroundColor: NSColor {
        switch self {
        case .default:
            return .labelColor
        case .gray:
            return .secondaryLabelColor
        case .brown:
            return NSColor(red: 0.435, green: 0.286, blue: 0.204, alpha: 1)
        case .orange:
            return NSColor(red: 0.639, green: 0.271, blue: 0.063, alpha: 1)
        case .yellow:
            return NSColor(red: 0.518, green: 0.365, blue: 0.035, alpha: 1)
        case .green:
            return NSColor(red: 0.133, green: 0.392, blue: 0.220, alpha: 1)
        case .blue:
            return NSColor(red: 0.078, green: 0.322, blue: 0.647, alpha: 1)
        case .purple:
            return NSColor(red: 0.369, green: 0.235, blue: 0.647, alpha: 1)
        case .pink:
            return NSColor(red: 0.529, green: 0.122, blue: 0.337, alpha: 1)
        case .red:
            return NSColor(red: 0.624, green: 0.180, blue: 0.173, alpha: 1)
        }
    }

    var appKitFillColor: NSColor {
        switch self {
        case .default:
            return NSColor.labelColor.withAlphaComponent(0.08)
        case .gray:
            return NSColor.labelColor.withAlphaComponent(0.08)
        case .brown:
            return NSColor(red: 0.925, green: 0.867, blue: 0.820, alpha: 1)
        case .orange:
            return NSColor(red: 0.984, green: 0.863, blue: 0.753, alpha: 1)
        case .yellow:
            return NSColor(red: 0.961, green: 0.875, blue: 0.651, alpha: 1)
        case .green:
            return NSColor(red: 0.820, green: 0.902, blue: 0.839, alpha: 1)
        case .blue:
            return NSColor(red: 0.855, green: 0.925, blue: 1.0, alpha: 1)
        case .purple:
            return NSColor(red: 0.882, green: 0.820, blue: 0.965, alpha: 1)
        case .pink:
            return NSColor(red: 0.969, green: 0.855, blue: 0.929, alpha: 1)
        case .red:
            return NSColor(red: 0.976, green: 0.812, blue: 0.788, alpha: 1)
        }
    }
}
