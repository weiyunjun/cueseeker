### 修改代码前准备工作
1. 搜索的性能测试。具体测试内容后续补充。
2. 理清非播放器UI相关代码。一共4类：可替换主界面壳：Workbench、顶栏、Library/Search/Shiori 页面切换。旧列表 UI：Search 卡片列表、Library folder/grid、Shiori 卡片列表。暂时保留的数据 store：LibraryStore、SearchStore、ShioriStore、AppCoordinator 相关动作。必须保护的播放器链路：Playback、CueSeekerPlayback、CNativePlayback、字幕渲染、播放控制。
### 初版改动
3. 初版职责：只做Library界面最小实现。极简列表功能，包括：序号，文件夹名称，视频文件名，字幕文件名。以及，点击视频文件名，播放视频功能。默认展示顺序，和当前保持一致，播放视频的处理，和当前保持一致。
4. 初版UI需要有：浅灰背景、列名明确、固定高度的表头。浅色的行之间的横线。紧凑行高：类似管理工具，不要卡片感。视频文件名像链接：可点击、有 hover 态，但不要额外操作列，长文件名省略。字幕文件名可读：长文件名省略，hover 或后续 overlay 再看全量。页面顶部简单标题： Library 。空状态/加载/错误状态沿用现有逻辑。
5. 初版UI不需要有：列之间的竖线。当前播放视频的标记。页面顶部的数量摘要。