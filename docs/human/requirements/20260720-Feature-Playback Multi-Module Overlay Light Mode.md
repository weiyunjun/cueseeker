# 版本
main

# 需求描述
1. 视频的Overlay界面，适配Light Mode，响应Settings - Appearance - Appearance Mode的持久化设置。
2. UI改动见# UI文档改动。

# UI文档改动

### 1. Subtitle Focus 颜色 Token

修改前

```md
#### Subtitle Focus

- `--color-subtitle-focus-overlay-bg`: Light `#242426`; Dark `#242426`
- `--color-subtitle-focus-cue-selected`: Light `rgba(255,255,255,0.94)`; Dark `rgba(255,255,255,0.94)`
- `--color-subtitle-focus-cue-group-selected`: Light `rgba(255,255,255,0.62)`; Dark `rgba(255,255,255,0.62)`
- `--color-subtitle-focus-cue-unselected`: Light `rgba(255,255,255,0.34)`; Dark `rgba(255,255,255,0.34)`
```

修改后

```md
#### Subtitle Focus

- `--color-subtitle-focus-overlay-bg`: Light `#F6F7F9`; Dark `#242426`
- `--color-subtitle-focus-cue-selected`: Light `#111827`; Dark `rgba(255,255,255,0.94)`
- `--color-subtitle-focus-cue-group-selected`: Light `#475467`; Dark `rgba(255,255,255,0.62)`
- `--color-subtitle-focus-cue-unselected`: Light `#858B95`; Dark `rgba(255,255,255,0.34)`
- `--color-playback-module-sidebar-selected`: Light `#111827`; Dark `rgba(255,255,255,0.94)`
- `--color-playback-module-sidebar-unselected`: Light `#667085`; Dark `rgba(255,255,255,0.34)`
- `--color-playback-playlist-sequence`: Light `#667085`; Dark `rgba(255,255,255,0.34)`
```

### 2. Playback Search Box Appearance

修改前

```md
- 使用固定 Dark Appearance。
```

修改后

```md
- 跟随 CueSeeker 当前有效 Appearance。
- Light Appearance 使用 Light Token；Dark Appearance 使用 Dark Token。
```

### 3. Playback Module Sidebar Item 颜色

修改前

```md
- Selected 的文字和图标使用 `--color-subtitle-focus-cue-selected`。
- Unselected 的文字和图标使用 `--color-subtitle-focus-cue-unselected`。
```

修改后

```md
- Selected 的文字和图标使用 `--color-playback-module-sidebar-selected`。
- Unselected 的文字和图标使用 `--color-playback-module-sidebar-unselected`。
```

### 4. Playlist Sequence Number 颜色

修改前

```md
  - 使用 `--color-subtitle-focus-cue-unselected`
```

修改后

```md
  - 使用 `--color-playback-playlist-sequence`
```

### 5. Playback Multi-Module Overlay Appearance

修改前

```md
- Light 和 Dark Appearance 均使用固定 Dark Appearance。
```

修改后

```md
- 跟随 CueSeeker 当前有效 Appearance。
- Appearance Mode 为 Auto 时，跟随当前 macOS 系统 Appearance。
- Appearance Mode 为 Light 或 Dark 时，使用对应的强制 Appearance。
- Overlay 显示期间 Appearance 发生变化时，更新当前可见 Module、Native Reel 和 Scrollbar 的颜色。
- Appearance 更新不重建 Overlay Session，不改变当前 Module、选择位置或滚动位置。
```
