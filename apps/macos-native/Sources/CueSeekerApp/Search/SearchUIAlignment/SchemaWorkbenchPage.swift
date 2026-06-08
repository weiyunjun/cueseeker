import SwiftUI

struct SchemaWorkbenchPage: View {
    @State private var searchDraft: String
    @State private var visibleColumnIDs: Set<String>
    @State private var activeFilterSetID: String?
    @State private var filterRules: [SchemaWorkbenchFilterRule]
    @State private var filterSets: [SchemaWorkbenchFilterSet]

    init() {
        _searchDraft = State(initialValue: "")
        _visibleColumnIDs = State(initialValue: SchemaWorkbenchSearchDefaults.initialVisibleColumnIDs)
        _activeFilterSetID = State(initialValue: SchemaWorkbenchSearchDefaults.defaultFilterSetID)
        _filterRules = State(initialValue: SchemaWorkbenchSearchDefaults.defaultFilterRules)
        _filterSets = State(initialValue: SchemaWorkbenchSearchDefaults.filterSets)
    }

    var body: some View {
        SchemaWorkbenchSearchShell(
            searchDraft: $searchDraft,
            visibleColumnIDs: $visibleColumnIDs,
            activeFilterSetID: $activeFilterSetID,
            filterRules: $filterRules,
            filterSets: $filterSets,
            columns: SchemaWorkbenchSearchDefaults.columns,
        ) { visibleColumns in
            WorkbenchDataTable(
                columns: visibleColumns,
                rows: Self.tableRows
            )
        }
    }

    private static let tableRows: [WorkbenchTableRow] = [
        tableRow(
            1,
            display: "Ave Mujica - 01",
            cues: "母親担心 月曜日会为我们的她做醒\n大丈夫月の光迎えにしてくれますわ",
            speaker: "丰川祥子"
        ),
        tableRow(
            2,
            display: "Ave Mujica - 01",
            cues: "没问题的 波を跳踊的侍轻视我\n大丈夫あなたの言葉こそ航標よ",
            speaker: "若叶睦"
        ),
        tableRow(
            3,
            display: "Ave Mujica - 01",
            cues: "枠　言渡迷　没问题吧\n枠　言渡迷　大丈夫",
            speaker: "高松灯"
        ),
        tableRow(
            4,
            display: "Ave Mujica - 01",
            cues: "当然没问题\n大丈夫に決まっているでしょう",
            speaker: "千早爱音"
        ),
        tableRow(
            5,
            display: "Ave Mujica - 02",
            cues: "小初 你没事吧\nういちゃん　大丈夫",
            speaker: "长崎素世"
        ),
        tableRow(
            6,
            display: "Ave Mujica - 02",
            cues: "我没事\n私は大丈夫だよ",
            speaker: "丰川祥子"
        ),
        tableRow(
            7,
            display: "Ave Mujica - 03",
            cues: "应该没问题吧\n大丈夫かなぁ",
            speaker: "若叶睦"
        ),
        tableRow(
            8,
            display: "Ave Mujica - 03",
            cues: "所以已经没事了\nだから　もう大丈夫",
            speaker: "高松灯"
        ),
        tableRow(
            9,
            display: "Ave Mujica - 04",
            cues: "没有害怕也没关系对吧\nギターなんてなくても大丈夫だったでしょう",
            speaker: "千早爱音"
        ),
        tableRow(
            10,
            display: "Ave Mujica - 05",
            cues: "小睦别看很心 虽然美不会有事吧\n睦ちゃんすごい叫んでたけど　大丈夫かな",
            speaker: "长崎素世"
        ),
        tableRow(
            11,
            display: "Ave Mujica - 05",
            cues: "灯灯 你还好吗\nともらん　大丈夫",
            speaker: "丰川祥子"
        ),
        tableRow(
            12,
            display: "Ave Mujica - 06",
            cues: "没事的 我会从一切恐怖的东西那里保护你\n大丈夫　怖いことからは全部　私が守ってあげる",
            speaker: "若叶睦"
        ),
    ]

    private static func tableRow(
        _ rowNumber: Int,
        display: String,
        cues: String,
        speaker: String
    ) -> WorkbenchTableRow {
        WorkbenchTableRow(
            id: "mock-\(rowNumber)",
            cells: [
                "rowNumber": .rowNumber(rowNumber),
                "display": .text(display),
                "cues": .text(cues),
                "language": .multiSelect([
                    WorkbenchMultiSelectOption(title: "中文", style: .pink),
                    WorkbenchMultiSelectOption(title: "日本語", style: .blue),
                ]),
                "speaker": .text(speaker),
            ]
        )
    }
}
