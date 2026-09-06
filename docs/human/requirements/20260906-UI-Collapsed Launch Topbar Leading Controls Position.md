# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
  - `App Topbar Layout`

# 需求描述

## 1. 问题

侧栏收起状态下启动 App，顶栏的 Sidebar Toggle 与 Back Action 整体左移，压住红绿灯。
启动后手动切换一次侧栏，位置才恢复正常。

## 2. 要求

1. 侧栏收起时，Sidebar Toggle 的左缘为：`--spacing-6` + 红绿灯簇实际宽度 +
   `--gap-app-topbar-toggle-after-window-controls`。
2. 该位置在 App 启动的第一帧即成立，不依赖用户先操作一次侧栏，也不依赖窗口缩放。
3. Back Action 继续紧随 Sidebar Toggle，二者间距不变。

## 3. 保持不变

1. 侧栏展开态与全屏态的顶栏排布不变。
2. 红绿灯自身的位置、尺寸与显示隐藏规则不变。
3. 播放页 Window Controls 与 Return Action 的位置不变。
4. 不新增、不修改任何 Token。

# 验收

1. 侧栏收起状态下启动：Sidebar Toggle 与 Back Action 的位置，与"展开状态启动后手动收起侧栏"完全一致，红绿灯不被遮挡。
2. 侧栏展开状态下启动：位置与现状一致。
3. 启动后反复切换侧栏：位置不跳动。
4. 进入播放页再返回：返回按钮与顶栏按钮位置均无变化。
5. 使用现有 Debug E2E 控制器的 `inspect` 读取按钮位置验收，不为本需求新增测试能力。