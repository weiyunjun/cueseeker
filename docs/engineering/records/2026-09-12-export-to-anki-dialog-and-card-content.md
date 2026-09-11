# Export to Anki dialog and card content

Human-owned documents:

- `docs/human/requirements/20260912-Feature-Export To Anki Dialog And Card Content.md`
- `docs/human/design/UI Design System.md`, `docs/human/design/UI Application Rules.md` and `docs/human/design/Icon Registry.md` (to be updated by the owner after acceptance)

## Why

Export to Anki went straight to the system save panel and every card was the same: audio and a screenshot on the front, the Cue Text on the back. The owner wants a dialog first that chooses the Cue Text's side and what else goes on the card, remembers those choices, and names the package and its folder without a save panel; the cards gain the Cue Group's other lines, the Display Title with the Time Range, and icons that open the Deep Link, the subtitle file and the video file.

## What changed

- Both entries — the Search and Shiori Selection Action Overlay's Export to Anki, and `A` — open the Export to Anki dialog instead of the save panel. It sits in the in-window dialog layer like the other dialogs: `--width-dialog-large`, narrowed to the window; between the title and the buttons it scrolls in a short window, with an overlay scrollbar that takes no width, as the Shiori List Editor does. It does not hold the red light or Quit, opens with no focus, Return is Export, and Esc and the close button are Cancel.
- The dialog is built only from existing components and tokens: the Dialog header and close button, the Segmented Control for Cue Text Side (Front, Back), Checkbox glyphs with a Body label for Required (Cue Text and Audio, Checked + Disabled) and Optional (the seven items, in the requirement's order), the Text Field for File Name, the Rename Current Name's type for the Location path with an Icon Button (`folder`), and Button / Neutral and Button / Primary. Group titles are Text Field labels `--spacing-2` above their content, groups `--spacing-4` apart; the checkboxes run in two equal columns `--spacing-3` apart in rows and `--spacing-4` between columns, the glyph `--spacing-2` from its label. The folder button reaches past the content's edge by the slack its glyph leaves in its box, so the glyph's ink lands on the content edge; the slack is derived from the icon button and control icon sizes, the documented line width and the glyph's geometry. The code gains `--width-dialog-large`, which the design document already defines.
- Defaults: Back, Optional only Screenshot, the existing default file name, and Downloads. Cue Text Side, the Optional items and the Location folder are kept in the shared preferences (`ankiExportCueTextSide`, `ankiExportOptionalItems`, `ankiExportFolderPath`) as soon as they change, shared by Search and Shiori; a kept folder that no longer exists falls back to Downloads. The file name is generated afresh on every open.
- The folder button opens the system folder panel as a sheet, and the dialog layer's veil steps aside for it as it does for the other file panels. Export checks the name with Rename's rules and messages (the unchanged rule cannot apply to a new file), adds `.apkg` when the name lacks it, and, when the file already exists, shows the system warning with the requirement's copy: Replace on the right in red, Cancel on the left; Return presses neither. Cancel returns to the dialog, Replace queues the export. The export then runs through the existing task queue with the dialog's choices carried in memory beside the cues; the task record is unchanged.
- Cards: the Cue Text's side shows Cue Text, then the Cue Group's other lines (the table row's additional Cue texts, so a single-language subtitle has none), then the Display Title and Time Range joined by two non-breaking spaces, then the Deep Link, subtitle and video icons joined the same way; the other side shows the audio and, when checked, the screenshot. An unchecked or empty item is left out and an empty line is not drawn. The icons are the App's `link-simple`, `subtitles` and `video` assets; their links are `cueseeker://cue?id=` and `file://` URLs, which Anki desktop hands to the system. Without Screenshot no screenshot is extracted at all. The answer face repeats the question face, as before; deck, audio, screenshot and note ids are generated as before.
- Each side has its own note type: the Back one keeps the existing id and name, the Front one is `CueSeeker Media Recall (Cue Text Front)`. Their templates are named `Cue Text Back` and `Cue Text Front` and their ids are 100,000 apart, because Anki takes an incoming note type for an existing one with the same id — or the next id up — whenever field and template names match, which would have put one side's cards into the other side's templates.
- Removed with the save panel: the save panel itself, and `exportShioriGroupToAnki`, which had no caller since July and fed only that path.
- Comments that listed the dialogs, or said a file panel is the only sheet, now include the new dialog and its warning.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Export/AnkiExportDialog.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/Export/AnkiPackageExporter.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+AnkiExport.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskQueueStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchShioriTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogLayer.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/InterfaceLayerRegistry.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`
- `apps/macos-native/Tests/CueSeekerAppTests/AnkiPackageExporterTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/TaskQueueStoreTests.swift`

## Verification

Unit tests, added to `AnkiPackageExporterTests`: the item takes the table row's Display Title, Time Range, other Cue Group lines, CueID and subtitle path; the three detail lines follow the checked items in order, escape their text, join with two spaces and link to the Deep Link and the percent-encoded files; unchecked and empty items leave nothing behind; the two sides' templates swap the faces and keep the text lines in order; the two note types differ in name, template name and id; the choices survive a new `SettingsStore` on the same defaults; the session adds `.apkg`, applies the name rules, and reports every change of the choices. `TaskQueueStoreTests` pass the choices through. The export and queue tests pass.

`swift test`: 1185 tests, run twice. The failures differ between the runs — native playback timeline, audio and presentation, the auto-pause boundary, the refresh-scope count, library folder removal, the shared preferences migration and the two Debug E2E scene-geometry cases — and each of them passed when run alone. `shioriTableStartsAtTopAfterPanelRemount` and `showCueGroupInvalidationIsScopedToMountedShiori` fail when run alone too, as the records since August note for the tree before them. None of them exports.

In the App, with the owner's copy closed: Debug E2E controller, main window 1445×821 at 2×, with the existing `click`, `keyPress`, `setWidth` and `capture` commands; no E2E facility was added. Coordinates were read off this session's captures. Light, then dark through the `-appAppearanceMode` launch argument; for the export run the Location came from an `-ankiExportFolderPath` launch argument pointing at a scratch folder, so nothing was written to the owner's Downloads.

- Shiori list with four bilingual Cues, Select Mode, all selected: the overlay's Export to Anki and `A` both open the dialog; no field has focus; Back, Required greyed and checked, Optional only Screenshot, the default file name, Downloads.
- Measured in pixels: the dialog is 600 × 593; the title's text box starts 24 from the left and its cap line 24 from the top; the close glyph's ink 24 from the right and the top; the Export button 24 from the right and the bottom; the folder glyph's ink 24 from the right; the Segmented Control 32 tall and 126 wide at the left inset; the File Name field 24 in from both sides; the second checkbox column's glyph at 310, as two columns of `(600 − 48 − 16) / 2` put it.
- Checking Deep Link and choosing Front wrote them to the preferences at once; setting them back wrote them back. A blank name showed `Enter a name` under a red field and the dialog stayed. Esc closed it with the dialog motion and left Select Mode on. Cmd+Q with the dialog open quit the App.
- Dark: the long scratch path is cut in the middle. With every item checked and the name `x` over an existing `x.apkg`: the warning showed the requirement's copy with Cancel on the left and a red Replace on the right, the red light unavailable while it was up; Return did nothing; Cancel returned to the dialog with the file untouched. `setWidth` 480: the dialog is 432 wide, both columns fit. Replace: the dialog closed, the task badge showed 1, and the package was written.
- The package holds four audio files and four screenshots; its note type is `CueSeeker Media Recall` with audio and image on the question face and Text, CueGroup, Source and Links on the answer face. Each note's fields read, for example, `大丈夫月の光が起こしてくれますわ` / `毋庸担心 月霞自会为我们将她唤醒` / `Ave Mujica - 01&nbsp;&nbsp;00:30 - 00:34` / three links to `cueseeker://cue?id=8873973` and the `file://` URLs of the `.scjp.ass` subtitle and the `.mkv` video, two non-breaking spaces apart, each an inline icon drawn in `currentColor`. The answer face rendered through WebKit showed those lines in that order below the screenshot. The task showed in Completed with the scratch folder and 4 cards.
- Left as found: the test's task record was deleted through the Task panel, the two preference keys the test created were removed, and the Sidebar, which the 480 width had collapsed, was shown again from the App.

## Known limits

- The Debug E2E controller can set the window's width but not its height, so the dialog scrolling in a short window was not driven; at the default window it is 593 tall and needs a window about 641 tall to show whole.
- The system folder panel, importing a package into Anki and clicking a card's icons there are system and third-party interfaces the controller does not reach; they stay manual acceptance steps. A card's icons work in Anki desktop only, as the requirement allows.
- The design documents do not yet describe this dialog's layout, a labelled Checkbox's hit area (the glyph and its label), the dialog in the layer list, or the three icons' use on the card.
