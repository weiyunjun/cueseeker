# 版本
main

# 需求描述
1. Command Panel的搜索，调整为完整集成Workbench Search的筛选条件，不做任何改变。
2. 一旦按回车进入搜索界面，哪怕不播放，然后退出到Workbench界面，再打开Workbench Search，也应该显示刚才的搜索结果。至于退出到Workbench界面时显示什么界面，还是维持之前的规则。
3. Deep Link搜索（URL Scheme搜索），不改变搜索的筛选条件。
4. 现在从Workbench Library或Workbench Recent Videos进入视频界面，Recent Videos没有刷新。这里也要一起修复。
5. 应用退出或主窗口关闭时，无论当前播放源是 Library、Search、Shiori 还是已经清空，都必须等待所有已排队的 Library 播放历史写入完成。退出同步只负责持久化，不触发无意义的界面刷新。
6. 保留现有定时进度保存、完成状态、共享 LibraryStore 所有权和播放源隔离规则。不得新增定时器、状态源、缓存、数据库查询路径或入口专属同步逻辑。