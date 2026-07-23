# 版本
main

# 需求描述
1. Shiori添加多列表支持。
2. 一级界面包括2部分：第一部分，在一排显示列表数量和字幕数量（N Lists · M Cues），以及右侧的新建列表按钮。字幕数量是按CueID去重的。点击新建列表，弹出新建列表界面：左侧是封面编辑界面（可以参考现在的更换封面的界面），右边上面是名称编辑，右边下面是描述编辑。
3. 一级界面，第二部分，显示若干列表卡片。卡片从上到下包括：封面图（右下角显示xx Cues，参考视频卡片），标题，描述。标题和描述都是固定大小，超过了就用...表示。
4. 右键列表卡片弹出的菜单，和右键视频卡片弹出的菜单类似，包括Edit List / Delete List。Edit List大部分复用新建列表界面，只是标题不同。Delete List，暂时不用给它特别的样式。
5. 弹出的二次确认界面参考删除Shiori的界面。
Title：Delete List
Message：The list “{List Name}” and its Shiori entries will be deleted. The original subtitle and video files will not be deleted.
Buttons：Cancel / Delete
6. 所有的列表，均允许删除，但只剩一个列表时，Delete List要disabled。
7. 保存为Shiori，暂时先保存到第一个列表。下一个需求再处理保存到不同列表。
8. 允许用户只填列表名称，不加封面或描述。
9. 默认封面使用现有Library Cover Placeholder的背景体系。中央放置Shiori/Bookmark图形。初始列表使用默认封面，列表名称是Default。
10. 列表名称没填且点击确认按钮，会拦截，文本框变红，文本框上方出现提示红色文字：Enter a list name.
11. 列表名称最多30个字符，列表描述最多100个字符。输入时不拦截，只在点击确认时拦截，文本框变红，文本框上方出现红色提示文字。列表名称的提示文字：List name must be 30 characters or fewer. You entered {Current Count}. 列表描述的提示文字：Description must be 100 characters or fewer. You entered {Current Count}.
12. 如果字符数符合要求，还需要检查列表名称是否重复，如果重复，点击确认时拦截，文本框上方出现红色提示文字：A list with this name already exists. Choose a different name.
13. 列表名称和列表描述，在没有输入的时候，需要分别有默认的提示文字。列表名称的Placeholder是Enter a list name，列表描述的Placeholder是Add a description (optional)。
14. 同一次确认中，名称和描述如果都不合法，应同时显示错误并聚焦第一个错误字段。
15. 新建列表界面和编辑列表界面，有任何编辑（成功上传图片，或者修改图片，或者2个文本框有任意输入内容），点击Cancel，弹出类似Remove Shiori的警告界面。
Title：Save Changes?
Message：You have unsaved changes. Do you want to save them before closing?
Buttons：Don’t Save / Cancel / Save

Don’t Save：放弃未保存修改并关闭新建列表或编辑列表界面。
Cancel：关闭警告界面，返回并继续编辑。
Save：关闭警告界面，执行与原确认按钮相同的校验和保存流程；校验失败时保留编辑界面并显示对应字段错误。
16. 自定义列表排序规则；建议按创建时间倒序。
左键点击列表卡片进入对应Shiori二级页面。
17. Shiori二级界面，顶栏文字是Shiori（即一级界面名称）。
18. Shiori二级界面，列表右键菜单，新增两项：Move to ...，Duplicate to ...。这2项分别表示将当前Shiori移动或复制到其他列表，前者移动成功后会从当前列表中删除该Shiori（一定要确定成功后再删除！因为有可能移动过去时选择的列表已经不存在了）。后者会在选中列表那里复制一份除ShioriID都一样的数据。注意，这2种情况，迁移过去，Tags和Time Added都会保留。
19. Move to ...，Duplicate to ...，这2个选项菜单，右边要有一个向右的chervon箭头，通过特定交互（Hover延迟打开、点击打开、键盘右箭头打开）后在菜单右侧又弹出一个菜单，菜单中是各种Shiori列表，按照默认顺序排列。注意，二级列表需要和一级列表无缝衔接，并且，一旦当鼠标hover到除了一级选项和二级菜单外的位置，二级菜单消失，如果点击一级菜单的其它选项，正常生效。如果点击其他位置，符合一级菜单消失的条件，一级菜单和二级菜单均消失（当然逻辑上讲二级菜单此时必然消失，不过保险起见这里规定的时候也加一层）。
20. Move to ...，Duplicate to ...，弹出的二级菜单，不显示当前Shiori列表（因为同一Shiori列表不允许2个CueID一样的Shiori）。如果只有当前一个列表，那么这2个选项都要disabled。