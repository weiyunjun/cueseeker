### 版本
main
### 当前问题
同一视频之间seek时，Swift层已经表达了正确意图：同视频走seek，不同视频走open。但native层把seek实现成reopen，这等于底层破坏了上层抽象。
### 需求描述
native层也需要：同视频走seek，不同视频走open。