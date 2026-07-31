# 版本
main

# 需求描述
1. 添加手柄适配，详见/docs/human/design/Controller.md。
2. 这个需求单只覆盖索尼DS5手柄的适配，更多手柄适配后续再做。
3. 需要支持索尼DS5手柄的蓝牙连接和USB有线连接。

# 修改步骤

1. 建立与手柄品牌无关的通用输入接口，并接入 DS5 按键映射。
2. 接入手柄连接、断开、输入转发及方向连续输入生命周期。
3. 将手柄输入接入现有视频播放、Playback Overlay 和 Command Panel 交互路径。
4. 统一 Collage 的 Copy、Export 动作，使鼠标和手柄复用相同实现。
5. 补充 macOS App Bundle 的 Extended Gamepad 声明和打包验证。
6. 完成自动测试，并分别使用蓝牙和 USB 连接 DS5 进行完整实机验收。