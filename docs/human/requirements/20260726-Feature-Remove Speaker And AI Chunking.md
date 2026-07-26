# 版本
main

# 需求描述
删除历史功能，Speaker和AI Chunking，具体包括：
1. 数据库迁移删除 Speaker 表和 AI Cache 表。
2. 删除 Speaker 与 AI Chunking 的全部功能链路。
3. 主动清除 DeepSeek Keychain 凭据及相关 UserDefaults。
4.不影响 Cue、Language、Shiori Tag、字幕播放和其他搜索筛选能力。

# UI文档改动

## 1. 删除 Speaker 颜色 Token

修改前

```markdown
#### Status

- `--color-chip-speaker-bg`: Light `#DDD6FE`; Dark `#31294C`
- `--color-chip-speaker-text`: Light `#5B21B6`; Dark `#D8B4FE`
- `--color-chip-language-bg`: Light `#DBEAFE`; Dark `#172A4A`
- `--color-chip-language-text`: Light `#0040FF`; Dark `#93C5FD`
```

修改后

```markdown
#### Status

- `--color-chip-language-bg`: Light `#DBEAFE`; Dark `#172A4A`
- `--color-chip-language-text`: Light `#0040FF`; Dark `#93C5FD`
```

## 2. 删除 Chip / Tag 中的 Speaker 用途

修改前

```markdown
#### Chip / Tag

- 用途：显示 Speaker、Language 或 Shiori Tag，并在所属界面允许时提供标签操作。
- Token：`--radius-chip`、`--padding-chip-x`、`--padding-chip-y`、`--font-family-base`、`--font-size-caption`。
- Speaker 使用 `--color-chip-speaker-bg`、`--color-chip-speaker-text`。
- Language 使用 `--color-chip-language-bg`、`--color-chip-language-text`。
- Shiori Tag 使用 `--color-bg-hover`、`--color-text-secondary`。
```

修改后

```markdown
#### Chip / Tag

- 用途：显示 Language 或 Shiori Tag，并在所属界面允许时提供标签操作。
- Token：`--radius-chip`、`--padding-chip-x`、`--padding-chip-y`、`--font-family-base`、`--font-size-caption`。
- Language 使用 `--color-chip-language-bg`、`--color-chip-language-text`。
- Shiori Tag 使用 `--color-bg-hover`、`--color-text-secondary`。
```
