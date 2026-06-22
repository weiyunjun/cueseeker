### 版本
main
### bug描述
[P2] 封面 downsample 缓存可能在重建封面后显示旧图。
缓存 key 只有 path|maxPixelSize。但封面文件路径由视频路径 hash 决定，重建时会复用同一路径。如果 reindex 重新导出了封面，UI 仍可能命中旧 NSCache，直到缓存淘汰或重启。建议把文件 mtime、cover generated_at 或内容版本纳入 key，或在 cover refresh 后失效缓存。