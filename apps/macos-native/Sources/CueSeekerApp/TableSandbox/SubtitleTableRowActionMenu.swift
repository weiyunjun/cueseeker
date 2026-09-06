enum SubtitleTableRowAction: Hashable, Sendable {
    case play
    case openSubtitleFolder
    case saveToShiori
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
        case .saveToShiori:
            return L("row_menu.save_to_shiori")
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
        case .saveToShiori:
            return "arrow.right"
        case .copyCueText, .copyCueGroupText, .copyTimeRange:
            return "doc.on.doc"
        case .copyDeepLink:
            return "link"
        case .moveToList:
            return "arrow.right"
        case .duplicateToList:
            return "arrow.right"
        case .removeShiori:
            return "bookmark.slash"
        }
    }

    var opensDestinationSubmenu: Bool {
        self == .saveToShiori || self == .moveToList || self == .duplicateToList
    }

    var isDestructive: Bool {
        self == .removeShiori
    }
}

struct SubtitleTableRowActionDestination: Equatable, Sendable, Identifiable {
    let id: Int64
    let title: String
    /// The list this cue was saved to most recently, which `Save to Shiori`
    /// highlights when its menu opens.
    var isRecentSaveTarget = false
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
        ]
        if style == .search {
            elements.append(.action(.saveToShiori))
        }
        elements += [
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

    /// The destination submenu always offers New List, so a Shiori with no
    /// other list to move to still opens it.
    func isEnabled(
        _ action: SubtitleTableRowAction,
        disabledActions: Set<SubtitleTableRowAction>,
        canOpenFolder: Bool
    ) -> Bool {
        !disabledActions.contains(action)
            && (action != .openSubtitleFolder || canOpenFolder)
    }

    /// Element positions the highlight may land on. Dividers and disabled
    /// actions are absent, so keyboard navigation skips them.
    func selectablePositions(
        disabledActions: Set<SubtitleTableRowAction>,
        canOpenFolder: Bool
    ) -> [Int] {
        elements.indices.filter { position in
            guard let action = action(at: position) else {
                return false
            }
            return isEnabled(
                action,
                disabledActions: disabledActions,
                canOpenFolder: canOpenFolder
            )
        }
    }
}
