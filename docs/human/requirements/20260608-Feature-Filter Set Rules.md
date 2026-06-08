### 版本
main
### 数据类型
1. 筛选功能参考Notion。首先需要确定表头的数据类型：Display，字符串。Cues，字符串。Language，字符串构成的集合。还有暂时不会用到的数字类型。
2. operator和数据类型有直接关联。字符串可以调用：is, is not, contains, does not contain, is empty, is not empty。字符串构成的集合可以调用：contains, does not contain, is empty, is not empty。数字可以调用：equals, does not equal, greater than, greater than or equal to, less than, less than or equal to, is empty, is not empty。
3. 对于字符串，is, is not, contains, does not contain，输入的内容会类型转换为字符串然后判断。对于is empty, is not empty，不可以输入内容，只需要做bool判断即可。
4. 对于字符串构成的集合，contains, does not contain，输入的内容会类型转换为字符串然后判断。对于is empty, is not empty，不可以输入内容，只需要做bool判断即可。
5. 对于数字，equals, does not equal, greater than, greater than or equal to, less than, less than or equal to，只允许正整数，如果输入其它内容，会直接拦截不显示在输入框中且不会提示。对于is empty, is not empty，不可以输入内容，只需要做bool判断即可。
### 界面交互
6. 需要输入内容的输入框（即is empty, is not empty外的输入框），允许留空。空的需要输入内容的Filter也会计入界面的xx Filters的计数中，且会跳过这条Filter的逻辑的判断。
7. Filter如果包含有意义的修改，切表格部分变化了，会即时刷新。有意义的修改指的是，选择需要输入内容的operator且修改了输入的值，新建或选择了不需要输入内容的operator。即时刷新会默认回到顶部。
8. 点击Save Filter Set后，会保存，名字根据当前已存在的Filter Set数量决定。例如在保存之前，有3个，那么它的默认名字就是Filter Set 4。这里UI上也要刷新显示它的名字。
9. Reset的功能是关闭当前筛选，也会清除未保存的Filter Set。
10. 编辑Filter Set的界面，不再显示New Filter Set的标题。
### 逻辑判断
11. Filter Set中，第二个Filter是And，后续都只能是And。第二个Filter是Or，后续都只能是Or。这是基于逻辑的考量。允许修改第二个Filter的And或Or，但是一旦修改，下面的Filter的And或Or也要随之修改。
12. Filter Set中，第三个Filter开始，就不能是下拉选择框了，而是和where一个样式类型，表明它不可以直接修改。
13. #不再作为筛选的条件，只作为视图序号，防止循环判断。但是#列仍然保留，且会根据界面变化而变化。
### 具体实现
14. 基于实际业务考虑，筛选功能，需要做数据库级过滤，而不是简单的UI过滤。确保大量结果的情况下，结果正确。
### 其它
15. 这个版本，初始化不要提供任何预设的Filter Set。
16. 这个版本，先不做改名功能。