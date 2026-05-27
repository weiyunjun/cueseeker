### 版本
feature/playback-quick-search
### 当前问题
1. 目前的Quick Search界面，AI chunk后，没办法直观看到chunk在原句中的位置
2. chunk结果下面的，当前字幕的最后一行的句子（以下简称句子）+ /chunks也容易让人产生疑惑
### 需求描述
1. 句子 + /chunks，修改排版。仍然在一个box中，改为上下布局，上面是句子，下面改名为/chunk。从写死的文本的/chunks，改为可以按下后执行AI chunk指令的/chunk按钮。当选中到句子行时，默认选中第一个按钮。
2. 新增/copy按钮，放在/chunk按钮后面。按下/copy可以复制句子（注意这里的实现，和播发器UI那里的复制当前字幕会不一样，只复制上面显示的句子）。
3. 当已经有AI chunk缓存时，/chunk名称变为/rechunk。
4. /chunk，/rechunk，/copy按钮的样式，复用/back和/forward按钮。
5. 句子行的位置不变（没有AI chunk缓存时在搜索框下面，有AI chunk缓存时在chunk结果下面）
6. 当选中chunk时，应该在下方的句子行对应的部分也有选中态。遵循尽量复用UI的原则，对应的部分的选中态在复用chunk结果的选中态基础上，通过调整尽量少的参数，达到弱一些但是风格一致的选中效果。
7. /copy按钮执行后，应该有动画反馈，复用播发器UI那里的复制当前字幕按钮的动画反馈。
