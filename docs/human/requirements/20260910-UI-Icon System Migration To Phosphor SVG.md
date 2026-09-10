# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Icon 尺寸与颜色 token、Checkbox）
- 验收后新建 `docs/human/design/Icon Registry.md`，记录图标名录、尺寸分档与制作规格。

# 需求描述

1. 现状：界面图标全部为 SF Symbols，图标名以字符串字面量散落在各处，设计文档只记录了 Checkbox 的三个符号。SF Symbols 受 Apple 许可限制，不能随 Windows 版本分发。
2. 改用 Phosphor 图标集（MIT）。SVG 母版入库作为唯一真源，界面只引用语义图标名，代码中不得再出现图形名字符串字面量。
3. 装配方式：SVG 直接作为资源文件由系统图像接口加载并按模板着色。已知风险：最低支持系统能否直读 SVG 尚未验证；若不支持，改用等效的 PDF 矢量资源，母版仍为 SVG。
4. 线宽按显示尺寸分两档，不逐个图标配置：12–18px 用 Light，24–32px 用 Regular。需要偏离该规则的图标单独列为例外。
5. Fill 字重属于状态变体，不参与尺寸分档。
6. 新增自制图标须与 Phosphor 规格一致：256×256 画布，Light 描边 12、Regular 描边 16，圆线端与圆拐角。
7. 本次只更换图形来源，不改变任何图标的语义、位置、尺寸与颜色 token。
8. 下表为初版映射，允许在实现与验收过程中逐个调整。表中未列出的图标沿用现有实现。

# 图标映射

| 现用 | Phosphor |
| --- | --- |
| chevron.left | caret-left |
| chevron.right | caret-right |
| chevron.down | caret-down |
| chevron.up.chevron.down | caret-up-down |
| sidebar.left | sidebar-simple |
| arrow.left | arrow-left |
| arrow.right | arrow-right |
| xmark | x |
| checkmark | check |
| magnifyingglass | magnifying-glass |
| line.3.horizontal.decrease | funnel |
| plus | plus |
| return | arrow-elbow-down-left |
| square.grid.2x2 | squares-four |
| folder | folder |
| bookmark | bookmark-simple |
| clock | clock |
| gearshape | gear |
| list.bullet.rectangle | list-checks |
| folder.badge.plus | folder-plus |
| arrow.clockwise | arrow-clockwise |
| minus.circle | minus-circle |
| rectangle.stack | stack |
| film | video |
| play.rectangle | video |
| captions.bubble | subtitles |
| captions.bubble.fill | subtitles |
| exclamationmark.triangle | warning |
| exclamationmark.circle | warning-circle |
| checkmark.circle | check-circle |
| circle | circle |
| play.circle | play-circle |
| clock.arrow.circlepath | clock-counter-clockwise |
| questionmark.circle | question |
| checkmark.circle.fill | check-circle（Fill） |
| minus.circle.fill | minus-circle（Fill） |
| pencil | pencil-simple |
| square.and.pencil | note-pencil |
| trash | trash |
| doc.on.doc | copy |
| square.and.arrow.up | export |
| link | link-simple |
| bookmark.fill | bookmark-simple（Fill） |
| bookmark.slash | bookmark-simple |
| play.fill | play（Fill） |
| pause.fill | pause（Fill） |
| backward.end.fill | skip-back（Fill） |
| forward.end.fill | skip-forward（Fill） |
| repeat | repeat |
| photo | image |
| speedometer | speedometer |
| viewfinder | corners-out |
| arrow.down.right.and.arrow.up.left | corners-in |
| speaker.slash.fill | speaker-x |
| speaker.wave.1.fill | speaker-low |
| speaker.wave.2.fill | speaker-high |
| speaker.wave.3.fill | speaker-high |
| textformat | text-aa |
| globe | globe |
| eye | eye |
| circle.lefthalf.filled | circle-half |
| externaldrive | hard-drives |
| hammer | hammer |
| arrow.down.doc | file-arrow-down |

# 验收

1. 全部界面图标由 Phosphor 资源渲染，代码中无图形名字符串字面量。
2. 明暗外观下着色正确，各尺寸边缘清晰，同屏图标线宽观感一致。
3. 播放控制条的字幕按钮靠选中背景区分开关，播放反馈浮层靠文案区分，两处图标一致。
4. 视觉人工验收，逐个图标由所有者确认后回填设计文档。不为本需求新增 E2E 能力。