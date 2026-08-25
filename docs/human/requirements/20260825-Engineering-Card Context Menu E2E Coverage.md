# 版本

main

# 关联需求

- `docs/human/requirements/20260825-UI-Menu Modality And Layer Input Ownership.md`
- `docs/human/requirements/20260824-Engineering-Debug End-to-End In-App Mouse Pointer And Button Interaction.md`

# 需求描述

使 Workbench 卡片与封面右键菜单可被现有自动化端到端测试打开，并把菜单模态与
层级规则中依赖该菜单的验收项由人工验收改为自动验收。

# 需求要求

1. 卡片与封面的右键命中不再以指针悬停状态为前提，改为按目标自身矩形命中判定。
2. 现有 E2E 右键命令发送到卡片或封面坐标时必须打开对应菜单，不需要先发送鼠标移动。
3. 菜单的打开、关闭与菜单项选择结果必须能通过现有 inspect 或截图确认。
4. 不新增 E2E 命令，不新增测试设施，不改变现有坐标契约与截图规则。
5. 不改变卡片与封面的既有交互：左键、悬停视觉、光标形状、菜单内容与菜单行为保持不变。
6. 自动化端到端用例覆盖：卡片右键菜单打开；菜单打开期间整窗禁止滚动；下层无 hover
   或选中的视觉变化；被右键点中的卡片保持高亮；Esc 与菜单外点击关闭菜单。
7. `20260825-UI-Menu Modality And Layer Input Ownership.md` 验收第 10 条中
   「SwiftUI 卡片与菜单使用人工验收」相应作废。

# 验收标准

1. 直接对卡片或封面坐标发送右键命令即可打开菜单，无需前置鼠标移动。
2. 需求要求第 6 条的各项用例在自动化端到端流程中通过。
3. 现有 E2E 用例全部保持通过。
4. 人工确认卡片左键、悬停视觉与菜单外观无变化。