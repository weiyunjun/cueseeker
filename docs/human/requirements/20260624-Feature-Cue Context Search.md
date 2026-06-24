# 版本
main

# 需求描述
1. 在Search界面和Shiori界面，hover到Cues时出现的...按钮，点击后的菜单中，新增Context功能。
2. 点击后，会跳转到一个筛选后的，定位到当前字幕所在的位置的Search界面中，该Search界面没有搜索关键词，只有一个筛选项：Display Title contains {Display Title of current cue}。
3. 逻辑上Display Title可能不严谨，但是这里先实现，看看体验怎么样。
4. 默认把目标字幕放在第一行。如果目标字幕的位置无法位于第一行，则要处于尽量靠前的位置。这里要提前计算好首屏展示内容，尽量快速渲染。
5. 定位上下文时，表格上方的xx rows立即显示exact的数字，表格只渲染首屏，和默认搜索一样。然后保证上下滚动时可以正常加载内容即可。