# 版本

main

# 需求

修改 `docs/engineering/02_git_workflow.md` 的 AI Assistant Interaction Rules，补充人类文档冲突处理规则。

1. `docs/human/` 是优先级最高的规则来源。

2. 同一篇人类文档内部出现自相矛盾时，AI 必须停下并报告冲突，不得自行选择一种解释。

3. 不同人类文档之间要求不一致时，若文档未特别说明，以修改日期较新的为准。修改日期以该文件最后一次 git 提交时间为准，不看文件名日期。