enum SubtitleTableRowAction: Hashable, Sendable {
    case play
    case openSubtitleFolder
    case context
    case copyCueText
    case copyCueGroupText
    case copyTimeRange
    case moveToList
    case duplicateToList
    case removeShiori

    var title: String {
        switch self {
        case .play:
            return "Play"
        case .openSubtitleFolder:
            return "Open Subtitle Folder"
        case .context:
            return "Context"
        case .copyCueText:
            return "Copy Cue Text"
        case .copyCueGroupText:
            return "Copy Cue Group Text"
        case .copyTimeRange:
            return "Copy Time Range"
        case .moveToList:
            return "Move to ..."
        case .duplicateToList:
            return "Duplicate to ..."
        case .removeShiori:
            return "Remove Shiori"
        }
    }

    var systemImage: String {
        switch self {
        case .play:
            return "play.fill"
        case .openSubtitleFolder:
            return "folder"
        case .context:
            return "doc.text"
        case .copyCueText, .copyCueGroupText, .copyTimeRange:
            return "copy"
        case .moveToList:
            return "arrow.right"
        case .duplicateToList:
            return "copy"
        case .removeShiori:
            return "bookmark.slash"
        }
    }

    var opensDestinationSubmenu: Bool {
        self == .moveToList || self == .duplicateToList
    }
}

struct SubtitleTableRowActionDestination: Equatable, Sendable, Identifiable {
    let id: Int64
    let title: String
}

enum SubtitleTableRowActionMenuElement: Equatable, Sendable {
    case action(SubtitleTableRowAction)
    case divider
}

struct SubtitleTableRowActionMenuModel: Equatable, Sendable {
    let elements: [SubtitleTableRowActionMenuElement]

    init(style: SubtitleTableRowActionMenuStyle, showsCueGroup: Bool) {
        var elements: [SubtitleTableRowActionMenuElement] = [
            .action(.play),
            .action(.openSubtitleFolder),
            .action(.context),
            .divider,
            .action(.copyCueText),
        ]
        if showsCueGroup {
            elements.append(.action(.copyCueGroupText))
        }
        elements.append(.action(.copyTimeRange))
        if style == .shiori {
            elements.append(.divider)
            elements.append(.action(.moveToList))
            elements.append(.action(.duplicateToList))
            elements.append(.divider)
            elements.append(.action(.removeShiori))
        }
        self.elements = elements
    }

    var actions: [SubtitleTableRowAction] {
        elements.compactMap { element in
            guard case .action(let action) = element else { return nil }
            return action
        }
    }
}
