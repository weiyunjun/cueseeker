### 版本
main
### 需求描述
1. 清理目前数据库中所有Speaker表头的数据。
2. 将"/Users/weiyunjun/Documents/mygo/mygo_ep01_Dial_JP_speakers.txt"~"/Users/weiyunjun/Documents/mygo/mygo_ep13_Dial_JP_speakers.txt"中的speaker数据，添加到数据库中MyGO对应集数的Name为Dial_JP的对应的cues的Speaker中。
3. 将/Users/weiyunjun/Documents/mygo/mygo_ecapa_main_speaker_matches.txt
，疑似speaker列的数据也添加到数据库中MyGO对应集数的Name为Dial_JP的对应的cues的Speaker中，但是要加一个疑似的前缀，例如高松灯会变成疑似高松灯。
4. 这样在Test Search 2界面的表格中，就可以筛选对应Speaker的对象。
5. 还需要在Settings - Play中新增一个swith选项：开启speaker。开启后字幕就会在开头显示：Speaker: 。例如，长崎素世: 。本质就是修改字幕的文字。对于有疑似标签的，就是：当前speaker,疑似speaker。例如，长崎素世,疑似高松灯: 。这里主要通过注入script的方式实现。