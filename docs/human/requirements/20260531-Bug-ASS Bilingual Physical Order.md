### 版本
feature/playback-quick-search
### bug截图
![图1](<assets/2026-05-31 at 21.51.56@2x.png>)
### bug描述
如图1所示，侧边栏的字幕中文和日语的上下位置顺序，与实际字幕的中文和日语的上下位置顺序，不一致。
字幕文件：/Volumes/Seagate/影视/进击的巨人/进击的巨人\ 第一季/_Kamigami__Shingeki_no_Kyojin_-_02__1920x1080_x264_AAC_Sub_GB_Big5_Jap__.ass
### 需求描述
做一个最简的“libass collision-lite 排序器”，保证这种场景下的推算的字幕位置顺序，可以和libass的位置顺序一致。
### 需求约束
1. 只处理index阶段的排序，将其视为后续调用的唯一数据源。
2. 不改搜索/侧边栏读取逻辑。
4. 修改不应该影响搜索性能。