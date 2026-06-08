### 版本
main
### 需求描述
1. 在Test Search 2中，取消必须输入搜索词才显示结果的限制，无搜索词时显示所有cues的结果，按照默认顺序排序。
2. Test Search 2页面的表格新增Speaker列，数据类型为字符串的集合
3. 数据库操作，写入测试数据，然后快速验证一下Speaker本身的有效性。
4. 点击筛选Speaker后的结果，也要可以进入筛选后结果的播放列表。
### 测试数据
路径：
/Users/weiyunjun/Documents/work/mygo_speaker_export/final
该路径下有13个txt文本，每个文本包含了序号	时间戳	speaker	字幕，一共4个表头。每个文本的每一行均可严格对应It's MyGO!!!!!的对应集数的字幕中的Dial_JP部分，注意这里只需要写入Dial_JP对应行填写Speaker，Dial_CN行不需要再写一遍。
It's MyGO!!!!!路径：
/Volumes/Seagate/影视/It's MyGO!!!!!