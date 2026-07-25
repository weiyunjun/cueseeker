# 版本
main

# 需求描述

## 需求关系
本需求仅在 SRT 播放与导出渲染方面，取代：
`docs/human/requirements/20260724-Engineering-Database Identity Indexing And Persistent Data Safety.md`
中“### SRT 到 ASS / libass 的渲染原则”及其相关渲染规则。
原需求中的 SRT Cue 身份、CueID、数据库去重、索引和持久数据规则继续有效。
若两个需求在 SRT 渲染行为上存在冲突，以本需求为准。

## 数据、索引与渲染边界
源 SRT、数据库索引数据和屏幕渲染结果属于三个独立层次。
数据库、搜索、收藏及其他面向 CueID 的功能继续使用既有索引和去重结果。
屏幕渲染必须直接依据源 SRT 中的物理字幕块建立 Playback Presentation，不得因数据库去重而丢失物理 Cue。
当前索引阶段继续直接解析 SRT，不得引入 SRT→ASS 或 libass 依赖。
播放解析中的容错、行内样式和物理 Cue 保留规则不得改变索引结果、CueID、SubtitleID 或持久化关系。
ASS 的多事件、Layer、定位、碰撞和特效行为不构成 SRT 的渲染约束。
ASS 继续忠实执行源脚本。

## 1. 背景
此前实现将 SRT 转换为临时 ASS Script，再交给 libass 渲染。
该方案无法可靠复现 IINA 的默认文本字幕视觉效果，并产生了与预期不符的字体大小、边距、字幕位置和缩放行为。
该方案还增加了启动预热、性能负担、格式转换误差，以及播放、窗口缩放、Screenshot 和 Collage 之间显示不一致的风险。
SRT 是结构简单的时间文本格式，不需要通过生成 ASS Script 才能完成基础播放。
本需求取消 SRT 接入 libass 的尝试，建立独立、轻量、可测试且结果可复现的 SRT 原生直接渲染管线。

## 2. 目标
SRT 不再转换为 ASS，不再提交给 libass。
SRT 由 CueSeeker 使用 CoreText/CoreGraphics 直接完成文本排版、描边、碰撞布局和绘制。
ASS 字幕继续使用现有 libass 渲染管线，其脚本样式、字体附件、定位和碰撞行为不得受到影响。
播放画面、Current Frame Screenshot、Subtitle Screenshot 和 Collage 必须复用同一套 SRT 文本解析、样式计算、布局和绘制实现。
同一个 SRT 文件、时间点、视频画布尺寸和样式配置必须得到确定性的相同结果。
布局结果不得因连续播放、向前 Seek、向后 Seek、播放控制栏状态或截图入口不同而发生变化。
第一版 SRT 固定为底部居中，不新增用户设置界面。

## 3. 非目标
本需求不改变 SRT CueID、SubtitleID、数据库 Schema、索引去重和 Shiori 继承规则。
本需求不为 SRT 实现完整 ASS 类型排版能力。
本需求不允许 SRT 内的非标准定位信息覆盖 CueSeeker 默认字幕位置。
本需求不新增字幕字体、位置、大小、颜色或碰撞设置界面。
本需求不实现根据播放控制栏状态动态移动字幕的功能。
后续可以通过独立需求增加避让播放控制栏的用户选项，但该选项不属于本需求范围。
本需求不修改 ASS 文件的渲染行为。
本需求不允许为了复用 libass 而生成任何临时 ASS Script。

## 4. SRT 播放管线
SRT 播放管线固定为：
读取并解码 SRT 文件。
解析为独立的 SRT Playback Cue。
保存每个源字幕块稳定的 Source Ordinal。
解析允许的行内文字格式。
建立时间查询结构和重叠关系。
根据当前时间取得全部 Active Cues。
根据视频画布、默认样式和碰撞规则生成布局结果。
使用 CoreText/CoreGraphics 直接绘制。
渲染管线中不得调用 `SRTASSConverter`、`SFXASSRendererSession` 或其他 libass 接口。
渲染管线不得生成临时 ASS Script、ASS Style 或 ASS Dialogue。
SRT 文件读取、完整播放解析和时间索引建立不得阻塞主线程。
旧加载任务必须在字幕切换、视频切换或播放请求被替代时取消，并禁止回写新的播放会话。
播放渲染必须保留源 SRT 的全部物理 Cue，不得使用数据库去重结果代替源播放数据。

## 5. IINA 默认 SRT 样式参考与 CueSeeker 覆盖规则
第一版默认样式参考 IINA Text Subtitles 默认设置：
Font：`sans-serif`
Size：`55`
Bold：Off
Italic：Off
Text Color：White，`#FFFFFFFF`
Background：Transparent
Border Size：`3`
Border Color：Black，`#000000FF`
Shadow Offset：`0`
Blur：`0`
Font Spacing：`0`
Horizontal Align：Center
Vertical Align：Bottom
Margin X：`25`
Margin Y：`22`
Vertical Position：`100%`
Display Subtitles in Letterboxes While in Full Screen：On（仅记录 IINA 参考值）
Scale Subtitles with Window Size：On（仅记录 IINA 参考值）
CueSeeker Effective Letterbox Behavior：Off
除 Letterbox 画布规则外，其余样式值作为 SRT Renderer 的视觉参考，不生成 ASS Style。
IINA/mpv 的 `Size 55` 是高度为 720 的逻辑字幕画布中的 scaled pixel 参考值，不等同于 CoreText 的 `55 pt`。
CueSeeker 必须通过高度为 720 的真实画面与 IINA 默认样式对齐，确定并固定一个 CoreText Base Font Size。
CueSeeker 的字幕尺寸始终根据视频实际画布高度缩放，不根据包含黑边的播放器窗口高度缩放。
`sans-serif` 是逻辑字体族，由 macOS 字体系统解析。
当前字体缺少字符时必须进行字体回退，不得显示缺失字形方框。
默认字体不加粗、不倾斜。
允许的 SRT 行内标签可以对局部文字覆盖粗体、斜体、下划线或颜色。
文字使用自然字体行高，不增加额外行距。
同一 Cue 内多行文字的基线距离由字体自然排版指标决定，不得增加额外逻辑行距。
描边必须使用 CoreGraphics 对实际字形执行 Stroke 后再执行 Fill，不得使用 `kCTStrokeWidth` 的字体百分比语义，不得使用多个偏移文本副本模拟描边。

## 6. 样式缩放规则
IINA/mpv 的字体参考值按高度为 720 的逻辑字幕画布解释，不直接对应 CoreText Point。
CueSeeker 使用视频实际画布高度计算缩放系数：
`Scale = Video Canvas Height / 720`
实际字体大小定义为：
`Font Size = CoreText Base Font Size × Scale`
实际描边大小定义为：
`Border Size = 3 × Scale`
CoreGraphics 文字描边线宽定义为：
`Stroke Line Width = 2 × Border Size`
实际水平边距定义为：
`Margin X = 25 × Scale`
实际垂直边距定义为：
`Margin Y = 22 × Scale`
不同重叠 Cue 不增加额外空白：
`Cue Gap = 0`
例如视频画布高度为 360 时：
`Font Size = CoreText Base Font Size × 0.5`
`Border Size = 1.5`
`Stroke Line Width = 3`
`Margin X = 12.5`
`Margin Y = 11`
`Cue Gap = 0`
例如视频画布高度为 720 时：
`Font Size = CoreText Base Font Size`
`Border Size = 3`
`Stroke Line Width = 6`
`Margin X = 25`
`Margin Y = 22`
`Cue Gap = 0`
例如视频画布高度为 1080 时：
`Font Size = CoreText Base Font Size × 1.5`
`Border Size = 4.5`
`Stroke Line Width = 9`
`Margin X = 37.5`
`Margin Y = 33`
`Cue Gap = 0`
Retina Backing Scale 只影响栅格精度，不得再次放大字幕的视觉尺寸。
播放器窗口尺寸变化时允许重新计算布局。
同一视频画布尺寸下不得因显示刷新、播放控制栏状态或窗口外部尺寸变化产生尺寸漂移。

## 7. 字幕画布与默认位置
无论普通窗口、全屏、窗口缩放或 Letterbox，字幕画布始终等于视频实际 Presentation Rect。
字幕的文字、描边和完整视觉边界均不得进入 Letterbox 黑边或视频画面外区域。
播放器窗口尺寸发生变化时，必须先计算视频实际 Presentation Rect，再根据其高度计算字幕缩放和布局。
Current Frame Screenshot、Subtitle Screenshot 和 Collage 使用输出视频帧自身的完整尺寸作为同等语义的字幕画布。
默认字幕水平居中。
最下方 Cue 的完整视觉边界底部位于视频画布底边上方 `Margin Y`。
文本最大可用宽度为视频画布宽度减去左右两侧的 `Margin X`。
`Vertical Position 100%` 表示使用上述默认底部位置，不表示将文字基线直接放在视频画布最底端。
播放控制栏不属于字幕布局输入。
播放控制栏出现、隐藏、改变透明度或响应鼠标移动时，不得引起字幕重新排版、缩放或上下移动。
播放控制栏显示期间允许暂时覆盖字幕。
该覆盖属于播放器 UI 的视觉叠加，不属于字幕碰撞或空间不足。
Current Frame Screenshot、Subtitle Screenshot 和 Collage 不读取播放控制栏状态。
截图和导出必须按照视频画布、时间点、源 Playback Cues 和字幕样式计算字幕 Placement。
后续可以通过独立设置增加避让播放控制栏的可选行为，但不属于本需求范围。

## 8. 坐标系统
SRT 布局统一使用左上角为原点、X 向右、Y 向下的逻辑坐标系统。
AppKit、CoreGraphics、视频帧和导出图片之间的坐标转换只能在最终绘制适配层执行一次。
播放 Overlay 与截图导出不得分别实现独立的 Y 轴翻转逻辑。
相同视频画布尺寸下，播放和截图得到的字幕边界必须一致。
字幕绘制结果必须裁剪在视频画布范围内。
不得出现垂直翻转、重复翻转或因不同坐标原点产生的字幕位置偏移。

## 9. Cue 时间语义
Cue 的有效时间区间采用半开区间：
`Start <= Current Time < End`
一条 Cue 的 End 与另一条 Cue 的 Start 完全相同时，旧 Cue 必须先结束，新 Cue 再开始，不视为时间交叉。
`End <= Start` 的 Cue 不参与播放渲染。
持续时间大于零但小于 200ms 的 Cue 仍可参与播放渲染。
索引阶段是否排除该 Cue，继续遵守现有索引规则。
SRT 序号不参与播放排序、碰撞排序或 Cue 身份判断。
字幕块在源文件中的物理位置必须保存为稳定的 Source Ordinal。
时间顺序混乱的 SRT 文件允许播放。
时间查询使用实际 Start 和 End。
开始时间完全相同的 Cue 使用 Source Ordinal 确定布局顺序。

## 10. 源物理 Cue 保留
播放渲染不得对源 SRT 中的物理字幕块进行去重。
即使多个字幕块的 Start、End、解析后的显示文本和行内样式完全相同，只要它们在源文件中是独立字幕块，就必须分别建立 Playback Cue，并全部参与布局和绘制。
完全相同的多个物理 Cue 使用各自在源文件中的 Source Ordinal 确定稳定顺序。
数据库记录、CueID、索引和面向 CueID 的界面继续遵守既有去重规则。
数据库和索引去重结果不得反向影响播放 Presentation。
播放层不得使用数据库中的逻辑 Cue 数量推断源文件中的物理 Cue 数量。

## 11. 多条同时字幕与碰撞布局
所有 Active Cues 必须同时参与布局，不得拼接成一个字符串。
默认字幕从视频画布底部向上堆叠。
开始时间较早的 Cue 优先靠近底部。
开始时间相同时，Source Ordinal 较小的 Cue 优先靠近底部。
碰撞检测必须使用排版后的完整视觉边界。
完整视觉边界包括显式换行、自动换行、字体回退、填充、描边、行内样式和 Speaker 前缀。
两个不同重叠 Cue 不增加额外间距：
`Cue Gap = 0`
两个不同 Cue 的完整视觉边界允许相接，但不得相交。
Margin Y 只用于字幕与视频画布底边之间的距离，不得用于不同 Cue 之间。
Cue Gap 不应用于同一 Cue 内部的多行文字。
即使两个 Cue 的时间、文本和样式完全相同，只要它们是不同源物理块，也必须形成两个独立布局结果。
不得通过修改时间戳、合并不同文本、合并物理 Cue、减小字体或隐藏旧 Cue 来解决正常碰撞。
空间不足时的处理遵守本需求“空间不足”章节。

## 12. 交叉时间戳
例如：
Cue A：
`00:00:00,000 --> 00:00:05,000`
Cue B：
`00:00:02,000 --> 00:00:07,000`
00:00:00 至 00:00:02 期间，只显示 Cue A，位于底部默认位置。
00:00:02 至 00:00:05 期间，Cue A 保持原位置。
Cue B 放在 Cue A 上方，两个 Cue 的完整视觉边界允许相接但不得相交。
00:00:05 至 00:00:07 期间，Cue B 保持其原有位置，不因 Cue A 消失而突然下跳。
同一个 Cue 在其有效期间不得改变位置。
只有视频画布尺寸、字幕样式或播放源发生变化时，才允许重新计算该 Cue 的位置。
播放控制栏出现或隐藏不属于允许重新计算 Cue 位置的条件。
Seek 到任意时间点时，布局结果必须与从头连续播放到该时间点一致。
Current Frame Screenshot、Subtitle Screenshot 和 Collage 在同一时间点必须得到相同的 Placement。
实现可以预计算稳定 Placement，也可以从相关重叠时间组件重建。
布局不得依赖无法重现的播放历史状态。

## 13. 空间不足
布局器必须优先从默认底部位置向上寻找无碰撞位置。
单条 Cue 的自然高度超过视频画布时，保持底部锚点并裁剪超出视频画布顶部的部分，不缩小字体。
多条 Cue 发生空间不足时，已经成功布局的 Cue 保持显示。
后续 Cue 如果无法完整放入视频画布，不得覆盖已有 Cue。
无法完整容纳的后续 Cue 在当前画面中不绘制，并记录诊断信息。
空间不足不得导致已有 Cue 改变位置。
空间不足不得导致崩溃、无限循环、负尺寸或画布外内存访问。
播放控制栏覆盖字幕不属于字幕空间不足，不得触发 Cue 隐藏或重新布局。

## 14. 换行规则
必须保留 SRT 文本中的显式换行。
自动换行必须在扣除 Margin X 后的最大宽度内进行。
自动换行遵守 Unicode 行分割规则。
没有合法换行点的超长文本可以按 Grapheme Cluster 强制换行。
不得拆分组合字符、Emoji 序列或代理字符。
同一 Cue 内多行文字使用字体自然行高，不增加额外 Cue Gap。
不同 Cue 的文本不得因为视觉上相邻而合并为同一段落。

## 15. SRT 行内格式
第一版支持以下常见格式：
`<b>...</b>`
`<i>...</i>`
`<u>...</u>`
`<font color="...">...</font>`
常见 HTML 实体，包括：
`&amp;`
`&lt;`
`&gt;`
`&quot;`
`&#...;`
格式标签允许合理嵌套。
格式错误或未闭合时，必须尽可能保留可见文字，不得导致整条 Cue 消失。
结构完整但不支持的 HTML 风格标签可以移除标签本身并保留内部文本。
无法识别为标签的 `<`、`>` 或大括号内容按普通文字显示。
SRT 中出现的非标准 ASS 定位控制符、坐标扩展或时间行坐标参数不得改变字幕位置。
已识别为非标准定位控制符的内容不得原样显示为字幕文字。
行内格式只影响所属物理 Cue，不得改变物理 Cue 数量、时间范围或 Source Ordinal。

## 16. 文件兼容与播放容错
必须支持 UTF-8，有无 BOM 均可。
必须支持带 BOM 的 UTF-16 LE 和 UTF-16 BE。
必须支持 `CRLF`、`LF` 和 `CR` 换行。
时间戳毫秒分隔符同时接受逗号和点。
允许缺少数字序号的字幕块。
允许序号重复、跳号或乱序。
序号始终不参与播放排序。
播放解析遇到单个结构损坏的字幕块时，应跳过该字幕块并记录诊断，不得导致整份字幕停止播放。
播放解析对损坏块的容错不得改变索引解析的严格性。
整个文件无法解码或不存在任何有效 Playback Cue 时，通过现有播放错误反馈报告。
播放失败时不得回退到 SRT→ASS 或 libass。
播放解析必须保留有效源字幕块的物理顺序和 Source Ordinal。
播放解析不得因为时间、文本或样式相同而删除物理字幕块。

## 17. Speaker 显示
开启 `Show Speaker in Subtitles` 时，Speaker 前缀必须在 SRT Playback Cue 文本模型中生成，再进入排版。
SRT Speaker 显示不得通过生成或修改 ASS Script 实现。
Speaker 前缀参与自动换行、尺寸测量和碰撞检测。
Speaker 前缀属于所属物理 Cue，不得导致不同物理 Cue 合并。
关闭 Speaker 显示后必须恢复原始 SRT 文本。
切换 Speaker 显示不得修改字幕源文件。
ASS Speaker 显示继续使用现有 ASS 处理路径。

## 18. 时间查询与性能
不得在每次播放刷新时遍历全部 SRT Cue。
Active Cue 查询复杂度目标为：
`O(log n + k)`
其中 `k` 为当前 Active Cue 数量。
完整文件读取、播放解析、行内格式解析和时间索引建立必须在后台执行。
不得每一视频帧重新读取 SRT 文件。
不得每一视频帧重新解析完整 SRT 文件。
不得每一视频帧重新排版未变化的字幕。
只有跨越 Cue Start、Cue End、Seek、字幕切换、Speaker 设置变化、视频画布尺寸变化或字幕样式变化时，才需要更新布局或绘制结果。
播放控制栏出现、隐藏、改变透明度或响应鼠标移动不得触发字幕布局更新。
大 SRT 文件不得明显阻塞打开视频、Seek、搜索结果切换和播放刷新。
字幕切换或播放请求替换时，旧解析和布局任务必须取消。
旧任务的结果不得回写新的播放会话。

## 19. 播放与导出共用实现
SRT 播放 Overlay、Current Frame Screenshot、Subtitle Screenshot 和 Collage 必须调用同一个 SRT Layout 与 Drawing Core。
不同入口只允许提供视频画布尺寸、目标时间点和目标 Graphics Context。
不得在 Screenshot Exporter 中重新实现字体大小、描边、位置、换行、碰撞、Cue Gap 或 Y 轴转换。
导出时必须使用导出时间点的全部源 Active Playback Cues。
导出不得只使用触发导出的单条数据库 Cue。
同一时间存在多个物理 Cue 时，截图必须包含所有能够在视频画布内完成布局的物理 Cue。
带字幕截图包含完整的帧内字幕。
不带字幕截图完全不包含字幕。
截图和导出不读取播放控制栏状态。
播放控制栏是否正在显示不得改变截图字幕的位置或内容。
ASS 现有 libass 截图路径保持不变。

## 20. ASS 隔离
ASS 文件继续由 `SourceFaithfulASSSubtitleOverlayView` 和 libass 渲染。
SRT 不得进入 `SourceFaithfulASSSubtitleOverlayView` 的 ASS Session 创建流程。
SRT 不得创建 `SFXASSRendererSession`。
SRT 不得调用 libass。
SRT 不得生成临时 ASS Script、Style 或 Dialogue。
SRT 的窗口缩放不得触发 ASS Script 重建。
移除 SRT 转换逻辑不得影响 ASS 分段加载、字体别名、附件字体、Style、Speaker Rewrite 或截图输出。
ASS 与 SRT 使用相互独立的渲染入口。
两条路径可以共享播放器时间和视频画布信息，但不得共享格式专用的解析、布局或渲染状态。

## 21. 建议实现边界
索引解析继续保持现有行为。
不得因本需求放宽或改变数据库入库、CueID、去重及身份继承规则。
播放可以建立独立的 SRT Playback Parser 和 Playback Cue 模型。
播放解析也可以复用无状态的分块、换行标准化和时间码解析能力。
播放解析中的损坏块容错、行内样式、物理 Cue 保留和显示文本处理不得改变索引解析结果。
播放解析与索引解析不得通过共享可变状态、隐式去重开关或同一结果缓存相互影响。
新增一个共享的 SRT Renderer，统一负责默认样式、文字格式、测量、碰撞布局、Cue Gap 和 CoreGraphics 绘制。
新增独立的 SRT Overlay View，只负责承载 Renderer 输出和响应视频画布变化。
Playback 容器根据字幕格式选择 ASS Overlay 或 SRT Overlay。
ASS Overlay 与 SRT Overlay 不得相互调用。
Subtitle Screenshot Exporter 在 SRT 分支直接调用共享 SRT Renderer。
删除 `SRTASSConverter` 及其只服务于 SRT→ASS 的测试。
现有字幕数据库和索引模型不因本需求增加新的持久化字段或缓存表。
不得为了保持 Cue 位置而向数据库写入 Playback Placement。
稳定 Placement 属于播放期间可重建的 Presentation 数据。

## 22. 自动化测试
解析测试必须覆盖 BOM、不同换行、无序号、乱序时间、重复序号、逗号和点毫秒、损坏块、行内标签、HTML 实体及非标准坐标参数。
播放解析容错测试必须证明单个损坏块可以被跳过，同时不会放宽数据库索引的严格性或改变 CueID。
时间测试必须覆盖半开区间、End 等于下一条 Start、完全同时、部分交叉、多层交叉和零长度 Cue。
物理 Cue 测试必须证明两个时间、文本和样式完全相同的源字幕块会产生两个独立 Playback Cue 和两个布局结果。
布局测试必须覆盖单行、多行、自动换行、超长单词、CJK、Emoji、RTL、字体回退、Speaker 前缀和空间不足。
Cue Gap 测试必须证明视频画布高度为 360、720、1080 时，不同重叠 Cue 的额外间距均为 0，完整视觉边界允许相接但不得相交。
稳定性测试必须证明同一时间点通过连续播放、向前 Seek、向后 Seek和截图导出得到相同 Placement。
交叉时间戳测试必须证明仍处于有效期内的 Cue 不会在另一条 Cue 结束后下跳。
缩放测试必须验证视频画布高度为 360、720 和 1080 时，字体大小分别为 CoreText Base Font Size 的 0.5、1 和 1.5 倍，并验证描边和 Margin 数值。
画布测试必须证明普通窗口、全屏、窗口缩放及 Letterbox 下，字幕完整视觉边界始终包含在视频实际 Presentation Rect 内。
控制栏测试必须证明播放控制栏出现、隐藏或改变透明度不会改变字幕 Placement。
控制栏测试允许控制栏暂时覆盖字幕，不得将该覆盖识别为字幕碰撞或空间不足。
坐标测试必须验证播放与截图不存在垂直翻转、重复翻转或上下位置偏移。
播放与导出一致性测试必须证明相同视频画布、时间点和源 Playback Cues 得到相同字幕布局。
集成测试必须证明 SRT 播放不会创建 `SFXASSRendererSession`，不会调用 libass，也不会生成临时 ASS Script。
ASS 回归测试必须证明 ASS 渲染、字体、Style、截图和分段加载行为不变。
性能测试必须证明大 SRT 文件解析不阻塞主线程。
性能测试必须证明 Active Cue 查询不随字幕总数线性增长。

## 23. 视觉验收
使用相同视频、相同 SRT、相同视频画布尺寸，与 IINA 默认 Text Subtitles 设置进行并排比较。
视觉验收必须包含真实日语视频和真实日语 SRT。
合成黑色背景只能用于验证绘制、透明度和坐标，不得单独作为最终视觉验收。
IINA 的字体、字号、颜色、描边、水平边距、垂直边距和缩放规则作为视觉参考。
CueSeeker 不采用 IINA 的全屏 Letterbox 字幕画布行为。
高度为 720 时，CoreText Base Font Size、描边、水平边距、底部边距和整体位置必须与 IINA 默认样式完成视觉对齐，不得把 IINA `Size 55` 直接解释为 CoreText `55 pt`。
高度为 1080 时，字体、描边、水平边距和底部边距必须在 720 校准结果上按 1.5 倍缩放。
普通窗口、全屏、窗口缩放、退出全屏及 Letterbox 下，字幕不得出现明显位置跳变、尺寸错误或裁剪方向错误。
字幕的文字、描边和完整视觉边界不得进入视频实际 Presentation Rect 以外的黑边区域。
视频实际 Presentation Rect 相同时，不同播放器窗口尺寸必须得到相同的字幕尺寸和 Placement。
两条完全同时字幕必须同时显示并向上堆叠，完整视觉边界允许相接但不得相交。