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
    case gray
    case blue

    func redesignForegroundColor() -> NSColor {
        switch self {
        case .gray:
            return WorkbenchRedesignColors.NS.textSecondary
        case .blue:
            return WorkbenchRedesignColors.NS.chipLanguageText
        }
    }

    func redesignFillColor() -> NSColor {
        switch self {
        case .gray:
            return WorkbenchRedesignColors.NS.bgHover
        case .blue:
            return WorkbenchRedesignColors.NS.chipLanguageBg
        }
    }
}
