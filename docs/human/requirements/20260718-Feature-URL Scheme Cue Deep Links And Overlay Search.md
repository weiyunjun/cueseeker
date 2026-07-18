# 版本
main

# 需求描述
1. URL Scheme，当前的搜索关键词功能（cueseeker://search?q={keyword}），点击后会打开搜索页或者直接播放（有结果且在设置中开启开关）。调整为：1. 有结果且在设置中开启开关，直接播放。2. 有结果且未在设置中开启开关且不在播放中，打开Search界面。3. 有结果且未在设置中开启开关且在播放播放中，打开Overlay Search界面。4. 无结果且在播放中，打开Overlay Search界面。5. 无结果且不在播放中，打开Search界面。
2. 修改后的URL Scheme的搜索关键词功能，仍然会正常触发搜索，相关状态同步规则也适用。
3. Settings - Play的Auto Switch to Next Search Result or Shiori Cues，分拆为2个功能：Only Play Cues in Playlist和Auto Switch to Next Cues in Playlist。前者勾选后会只播放Playlist上的内容，播放完毕就停住，可以手动切换到前一个或后一个结果。后者会在走完Auto Switch Gap的时间后播放下一个Playlist上的结果。前者默认开启，后者默认关闭。Search和Shiori，以及接下来的播放指定句子，处于播放状态时，都被视为一个Playlist。
4. URL Scheme，新增播放指定句子功能，通过CueID构建。链接格式为cueseeker://cue?id={CueID}。点击链接后会直接播放这一句。
5. URL Scheme的播放指定句子功能，被视为进入一个只有该句子的Playlist（这意味着在Overlay Playlist中也要有所体现）。
6.  URL Scheme的播放指定句子功能的Return Context处理：退出Playback后应该回到Search界面。先这么处理，因为暂时没有更好的办法了。
7. 新增复制当前字幕为markdown链接的功能，绑定快捷键X，只对Overlay界面且存在焦点字幕时有效，对Overlay Search界面无效。例如，字幕内容是xxx，那么复制的链接是[xxx](cueseeker://cue?id={CueID})。复制成功后提示参考C键的普通复制成功后提示，文字改为：Subtitle(markdown format) Copied。
8. 复制当前字幕为markdown链接，这个版本先不做自适应处理，这意味着，不论粘贴在什么软件中，结果都是[xxx](cueseeker://cue?id={CueID})。

# 注意事项
1. 这里需要用打包出来的版本测试。目前已存在/Applications/CueSeeker.app，这里将旧包打包为CueSeeker-20260712.app.zip，放到其他文件夹。然后新包用CueSeeker.app，响应URL Scheme请求。