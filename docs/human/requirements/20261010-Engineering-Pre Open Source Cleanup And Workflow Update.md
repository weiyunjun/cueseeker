# 需求单：开源前历史产物清理、.gitignore 补全与工程工作流调整

状态：待实施  
日期：2026-10-10  
责任人：weiyunjun  

## 1. 背景与目标

项目定于 2026-10-11 在 GitHub 进行低调开源。为保证开源代码仓库轻量、清晰、规范，避免历史编译中间体与暂未成熟的实验性代码污染代码库，需在开源前执行一次工程级清理与规范对齐。

## 2. 需求范围

### 2.1 工程规则调整（`docs/engineering/02_git_workflow.md`）
- **本地提交与远程推送解耦**：
  - 本地开发维持“单步原子提交”原则，每次代码改动与需求单挂钩并产生本地 Git Commit。
  - **禁止频繁向 GitHub 远程仓库推送**。推送到 GitHub 仅由项目所有者在特定里程碑节点、发布版本或明确阶段性验证完成后手动执行。
  - AI 助手严禁擅自执行 `git push` 命令。

### 2.2 `.gitignore` 规则补齐
- 新增 Rust 构建输出忽略：`target/`。
- 将原有的根目录 `/build/` 替换为通配全层级的 `**/build/`，确保包括 `archive/flutter/build/` 在内的各子模块构建输出均被忽略。
- 新增报告文件忽略：`*.report.txt`。

### 2.3 历史产物与非必要开源内容清理
- **移除已跟踪的编译产物**：
  - `target/`（Rust 编译缓存与对象文件，约 3,425 个文件）
  - `archive/flutter/build/`（Flutter 历史编译中间体，约 4,197 个文件，含 3 个 78MB 二进制大文件）
- **移除本地残留报告**：
  - 根目录 `Unnatural.EP10.zh-ja.MagicStar.report.txt`
- **移除未成熟的早期 Windows 实验代码**（后续待 macOS 完善后再全新设计）：
  - `apps/windows-native/`
  - `apps/windows-playback-backend/`
  - `apps/windows-playback-lab/`

## 3. 验收标准
1. `git status` 恢复完全 clean，无悬挂的未暂存修改或未跟踪文件。
2. 仓库当前 HEAD 彻底移除上述 7,600+ 个无用文件，代码树保持纯净的 macOS 原生与基础归档。
3. `docs/engineering/02_git_workflow.md` 已补充明确的 Remote Push 规则。
4. 本地再次产生 `target` 或各级 `build` 时，能被 `.gitignore` 自动静默忽略。