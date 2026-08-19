# 版本
main

# 需求描述
1. 本需求只调整 Edit List；New List 保持现有行为。
2. Edit List 默认 Footer 保持 `Cancel / Save`。
3. 存在未保存修改并点击 `Cancel` 时，不再弹出 Save Changes 确认界面；原 Footer 切换为 `Don’t Save / Cancel / Save`。
4. `Don’t Save` 和 `Cancel` 使用 Neutral Button，`Save` 使用 Primary Button。
5. `Don’t Save`：放弃修改并关闭 Edit List。
6. `Cancel`：取消关闭，保留修改并恢复默认 Footer。
7. `Save`：执行现有校验和保存流程；校验失败时保留编辑内容、显示错误并恢复默认 Footer。
8. 没有未保存修改时，点击 `Cancel` 直接关闭 Edit List。