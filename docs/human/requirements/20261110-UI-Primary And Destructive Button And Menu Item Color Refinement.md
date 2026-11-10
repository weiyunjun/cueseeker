# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`

# 需求描述

1. **`C-03.1 Button / Primary` 明暗模式悬停与按下底色统一（`UI Tokens.md`）**：
   - 将主按钮在 Light Mode 下的 Hover 与 Pressed 底色由混入黑色改为与 Dark Mode 一致的混入纯白（`#FFFFFF`）提亮规则：
     - `--color-primary-button-bg-hover`：Light 与 Dark 统一为 `macOS accent color blended with 12% #FFFFFF`。
     - `--color-primary-button-bg-pressed`：Light 与 Dark 统一为 `macOS accent color blended with 22% #FFFFFF`。

2. **`C-03.1 Button / Destructive` 与 `C-04.3 Menu Item / Destructive Menu Item` 危险底色及边框配色优化（`UI Tokens.md` & `UI Components - Controls.md`）**：
   - **Dark Mode 危险悬停与按下底色改为半透明亮红叠加**：
     - `--color-danger-bg-hover`：Light 保持 `#FEF3F2`；Dark 由 `#3A1717` 改为 `rgba(252,165,165,0.16)`。
     - `--color-danger-bg-pressed`：Light 保持 `#FEE4E2`；Dark 由 `#4C1D1D` 改为 `rgba(252,165,165,0.24)`。
     - 清理移除未使用的 `--color-danger-bg-selected`。
   - **危险按钮（`C-03.1 Button / Destructive`）边框改为柔和半透明红框**：
     - 新增 `--color-danger-border`：`Light rgba(180,35,24,0.32); Dark rgba(252,165,165,0.35)`，用于 `Button / Destructive` 的 Default 状态边框（替代原 `--color-border-control`）。
     - 新增 `--color-danger-border-hover`：`Light rgba(180,35,24,0.50); Dark rgba(252,165,165,0.55)`，用于 `Button / Destructive` 的 Hover 与 Pressed 状态边框（替代原 `--color-border-control-hover`）。
     - Disabled 状态边框保持 `--color-border-disabled` 不变。

# 验收标准

1. **主按钮（Primary Button）**：在 Light Mode 与 Dark Mode 下，主按钮的默认、悬停（混入 `12%` `#FFFFFF`）、按下（混入 `22%` `#FFFFFF`）三态颜色表现完全一致，Light Mode 下悬停与按下时通透提亮、不再变暗发脏。
2. **危险按钮（Destructive Button）**：
   - 在 Light Mode 与 Dark Mode 下，默认态边框呈现柔和半透明红框（`--color-danger-border`），悬停与按下时边框加深为 `--color-danger-border-hover`。
   - 在 Dark Mode 下，悬停与按下底色呈现半透明亮红叠加（`rgba(252,165,165,0.16)` / `rgba(252,165,165,0.24)`），比底层表面更亮。
3. **危险菜单项（Destructive Menu Item）**：在 Dark Mode 弹出菜单（`#36363B`）中悬停危险菜单项时，底色呈现半透明亮红叠加（`rgba(252,165,165,0.16)`），视觉亮度高于菜单底色，不再出现暗红塌陷。