# Shiori List 编辑表单与封面编辑修复

## 版本

main

## 实现基准

0e4442a

## 需求

### Shiori List Editor

1. `Description (optional)` 攐为 `Description`，字段仍为可选。
2. Description 光标颜色必须与其他输入框一致，使用统一设计 token。
3. 每个表单字段必须始终保留一行校验信息空间；有无错误时，标题、输入框及整体布局均不得位移。
4. 校验信息保持单行且简洁：
   - `Enter a list name.`
   - `List name must be 30 characters or fewer.`
   - `Description must be 100 characters or fewer.`
   - `A list with this name already exists.`
5. 减少共享 Text Area 高度，使左侧封面区域与右侧表单区域等高；错误态和裁剪态也不得破坏等高关系。
6. 删除独立的 `Choose Image` 按钮。
7. 鼠标悬停封面时显示灰色遮罩、Edit 图标及 `Choose Image`：
   - 遮罩覆盖完整封面并沿用封面圆角。
   - 图标位于文字上方。
   - 图标与文字组成的整体必须水平、垂直居中。
   - 点击封面执行原 `Choose Image` 功能。
   - 进入图片裁剪状态后不显示遮罩，不阻碍裁剪操作。
8. 编辑弹窗打开期间，底层 Library 和 Shiori 内容不得响应 hover、点击或其他指针交互。
9. 创建与编辑共用的表单组件应保持一致，不增加页面专用的硬编码或特殊实现。

### Library Edit Cover

1. 右键选择 `Change Cover` 后先打开 `Edit Cover`，不得直接打开 Finder。
2. `Edit Cover` 始终显示当前生效封面；没有实际封面时显示既有 fallback 图片，不显示空图片状态。
3. 封面使用与 Shiori List Editor 相同的 hover 遮罩、Edit 图标、`Choose Image` 文案及整体居中规则。
4. 点击封面后打开 Finder；选择有效图片后进入既有裁剪流程。
5. 未选择新图片时不得保存；取消编辑不得改变当前封面。

### Description / Text Area 检查

检查共享 Text Area 的光标、文本与占位符对齐、焦点与错误状态、IME 输入、滚动及可访问性关联。不得改变既有滚动条显隐规则；发现超出本需求的问题应先反馈，不擅自扩大修改范围。

## UI 约束

所有颜色、间距、高度、圆角和图标尺寸必须使用共享设计系统 token，不得硬编码或创建私有特例。UI 验收通过后，再将最终稳定规则更新至 `UI Design System.md`。

## 验收

1. 执行现有可运行的单元测试、集成测试、构建检查和 Debug E2E 流程。
2. 不为本需求新增右键或 hover 自动化能力。
3. 右键入口、真实鼠标 hover、遮罩居中及最终视觉效果由人工 E2E 验收。

## 覆盖关系

本需求覆盖既有需求中以下冲突内容：

- Shiori List 校验文案及 Description 标题。
- Text Area 高度保持不变的限制。
- `Change Cover` 先打开 Finder 的流程。