# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/Toast Usage Registry.md`
- `docs/human/design/playback/Playback Core.md`
- `docs/human/design/playback/Controller.md`

# 需求描述

1. **打开新视频时的进度条初始化、播控状态与画面过渡**：
   - 从 Workbench 任意入口进入播放，或在播放页内切换到**另一部视频文件**时：
     - 顶部标题栏立即更新为目标视频信息；
     - 底部进度条立即归零（当前时间与总时长显示 `00:00 / 00:00`，滑块位于起点），处于 `No Duration` 状态（禁用拖拽与悬停时间预览胶囊）；
     - 底栏播放/暂停按钮立即重置为预期的播放状态；在视频完成初始加载前忽略播放/暂停切换操作，不弹出播放/暂停 HUD；
     - 舞台保留上一画面平滑过渡（不主动清空为黑屏），待新视频首帧画面就绪后同步更新画面、真实当前时间与总时长。

2. **同视频内跳转（Seek）的进度条即时跟随**：
   - 在已打开的同一视频内触发任意跳转（点击字幕台词、上/下一条切换到同视频台词、重播当前台词、快进/快退步进、拖拽进度条松手）时，总时长保持不变，进度条滑块与当前时间在触发瞬间立即跳至目标时间点，并在等待目标画面就绪期间保持在目标时间点，不回跳至旧时间。

3. **上/下一条导航反馈（HUD）零延迟响应与连续切换**：
   - 在 Search、Excerpt、Library 播放中触发上/下一条切换时，立即判定目标并弹出对应导航或边界 HUD，完整展示满 `1s`（进出场动画与展示时长不受远程字幕或远程视频连接耗时影响）。
   - 在视频加载中途连续触发切换时，每次操作均即时更新标题栏与 HUD，并取消未完成的旧加载、直接加载最新目标。

4. **播放舞台中央加载状态反馈（`C-09.5 Playback Feedback` + `C-09.4 Spinner`）**：
   - 新增 Token：
     - 尺寸 Token：`--size-playback-feedback-spinner: 23px`
     - 颜色 Token：
       - `--color-playback-feedback-spinner-track`: Light `rgba(255,255,255,0.24)`; Dark `rgba(255,255,255,0.24)`
       - `--color-playback-feedback-spinner-indicator`: Light `rgba(255,255,255,0.80)`; Dark `rgba(255,255,255,0.80)`
     - 动效 Token：`--delay-playback-loading-feedback: 300ms`
   - **触发阈值与中央单槽接力计时**：
     - 常规操作 HUD（如 `Next Video`、`Next Result`、快进快退等）优先级高于加载 Spinner；
     - 若当前无正在播放的操作 HUD，从等待画面开始按 `--delay-playback-loading-feedback`（`300ms`）计时，超时仍未就绪则显示加载 Spinner；
     - 若当前有正在播放的操作 HUD，优先完整展示操作 HUD，待操作 HUD 播放结束后若画面仍未就绪，再从此时开始按 `--delay-playback-loading-feedback`（`300ms`）计时，超时仍未就绪才显示加载 Spinner。
   - **视觉与动效表现**：
     - 在播放舞台中央（`L-07.4 Playback Feedback Overlay Layout`）显示无文字的 `C-09.5 Playback Feedback`，容器宽高均为 `--height-playback-feedback`（`52px`），圆角 `--radius-playback-feedback`（`16px`），背景 `--color-toast-bg`（叠加深色毛玻璃），边框 `1px --color-toast-border`，进出场动效遵循 Toast Motion；
     - 内部居中展示 `C-09.4 Spinner`，直径为 `--size-playback-feedback-spinner`（`23px`），线宽 `--width-spinner-stroke`（`2px`），静止底环取 `--color-playback-feedback-spinner-track`，四分之一旋转圆弧取 `--color-playback-feedback-spinner-indicator`，旋转周期 `--duration-spinner-motion`（`1s` `linear`）；
     - 当目标画面就绪或加载失败时，加载反馈立即消失。

# 验收标准

1. 从 Workbench 打开新视频（尤其是远程视频）或切换到另一部视频时，舞台不闪黑屏，顶部标题立即更新，底部进度条立即显示 `00:00 / 00:00` 且悬停不出现旧视频时间预览，加载期间按空格或点击舞台不弹出虚假的播放/暂停 HUD；首帧画面就绪后画面与真实进度同步呈现。
2. 在同一视频内点击台词、按 `A` / `D` 切同视频结果、按 `R` 重播或按 `←` / `→` 快进快退时，底部进度条滑块与当前时间立即跳到目标时间点并稳住，不会停留在旧时间等待解码。
3. 连接远程视频时按 `A` / `D` 切换上/下一条结果，中央 HUD 在按键瞬间立即弹出并完整流畅展示 1 秒，不会延迟半秒或动画未播完即被截断；连续快速按 `A` / `D` 时响应流畅不卡顿。
4. 本地或局域网视频常规打开、切换视频或跳转（无操作 HUD 时 300ms 内就绪，或有操作 HUD 时在 HUD 播放结束后 300ms 内就绪）均不出现 Spinner；慢速远程加载或慢速跳转超出上述阈值仍未出画面时，舞台中央平滑淡入 `52×52px` Toast 底板 + `23px` 亮白 Spinner，画面出现后立即消失。