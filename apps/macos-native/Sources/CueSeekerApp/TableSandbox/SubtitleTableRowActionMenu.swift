enum SubtitleTableRowAction: Hashable, Sendable {
    case play
    case openSubtitleFolder
    case copyCueText
    case copyDeepLink
    case copyCueGroupText
    case copyTimeRange
    case moveToList
    case duplicateToList
    case removeShiori

    var title: String {
        switch self {
        case .play:
            return L("row_menu.play")
        case .openSubtitleFolder:
            return L("row_menu.open_subtitle_folder")
        case .copyCueText:
            return L("row_menu.copy_cue_text")
        case .copyDeepLink:
            return L("row_menu.copy_deep_link")
        case .copyCueGroupText:
            return L("row_menu.copy_cue_group_text")
        case .copyTimeRange:
            return L("row_menu.copy_time_range")
        case .moveToList:
            return L("row_menu.move_to")
        case .duplicateToList:
            return L("row_menu.duplicate_to")
        case .removeShiori:
            return L("row_menu.remove_shiori")
        }
    }

    var systemImage: String {
        switch self {
        case .play:
            return "play.fill"
        case .openSubtitleFolder:
            return "folder"
        case .copyCueText, .copyCueGroupText, .copyTimeRange:
            return "doc.on.doc"
        case .copyDeepLink:
            return "link"
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
            .divider,
            .action(.copyCueText),
            .action(.copyDeepLink),
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

    func action(at position: Int) -> SubtitleTableRowAction? {
        guard elements.indices.contains(position),
              case .action(let action) = elements[position]
        else {
            return nil
        }
        return action
    }

    func isEnabled(
        _ action: SubtitleTableRowAction,
        disabledActions: Set<SubtitleTableRowAction>,
        canOpenFolder: Bool,
        hasDestinations: Bool
    ) -> Bool {
        !disabledActions.contains(action)
            && (action != .openSubtitleFolder || canOpenFolder)
            && (!action.opensDestinationSubmenu || hasDestinations)
    }

    /// Element positions the highlight may land on. Dividers and disabled
    /// actions are absent, so keyboard navigation skips them.
    func selectablePositions(
        disabledActions: Set<SubtitleTableRowAction>,
        canOpenFolder: Bool,
        hasDestinations: Bool
    ) -> [Int] {
        elements.indices.filter { position in
            guard let action = action(at: position) else {
                return false
            }
            return isEnabled(
                action,
                disabledActions: disabledActions,
                canOpenFolder: canOpenFolder,
                hasDestinations: hasDestinations
            )
        }
    }
}
