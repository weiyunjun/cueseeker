# 版本

main

# 关联设计

- `docs/human/design/data/Data.md`
- `docs/human/design/workbench/Library and File.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **扩充支持的视频文件后缀名与同名视频匹配优先级**：
   - 在原有 6 种视频后缀（`.mkv`、`.mp4`、`.webm`、`.flv`、`.avi`、`.mov`）基础上，新增支持 14 种视频后缀：`.ts`、`.m2ts`、`.mts`、`.m4v`、`.rmvb`、`.rm`、`.wmv`、`.mpg`、`.mpeg`、`.vob`、`.asf`、`.f4v`、`.ogv`、`.3gp`（共 20 种，不区分大小写）。
   - 当同一字幕文件在同目录下匹配到多个仅后缀名不同的同名视频文件时，匹配优先级顺序更新为：
     `.mkv > .mp4 > .webm > .flv > .avi > .mov > .ts > .m2ts > .mts > .m4v > .rmvb > .rm > .wmv > .mpg > .mpeg > .vob > .asf > .f4v > .ogv > .3gp`。
   - 本地文件夹及远程文件夹（WebDAV、SMB、FTP、NFS）在目录浏览与执行 Index 时均支持识别上述全部 20 种后缀的视频文件并与同目录字幕配对入库。

2. **补齐文件详情弹窗（`L-06.8 File Detail Dialog Layout`）的视频格式名称展示**：
   - 在 File 页面查看视频文件详情时，`Format` 字段对全部 20 种支持后缀展示对应的标准格式名称（格式为 `<标准格式名称> (.<小写后缀>)`，如 `Flash Video (.flv)`、`MPEG Transport Stream (.ts)`、`BDAV MPEG-2 Transport Stream (.m2ts)`、`AVCHD MPEG-2 Transport Stream (.mts)`、`MPEG-4 Video (.m4v)`、`RealMedia Variable Bitrate (.rmvb)`、`RealMedia (.rm)`、`Windows Media Video (.wmv)`、`MPEG Program Stream (.mpg)`、`MPEG Program Stream (.mpeg)`、`DVD Video Object (.vob)`、`Advanced Systems Format (.asf)`、`Flash MP4 Video (.f4v)`、`Ogg Video (.ogv)`、`3GPP Multimedia (.3gp)`）。

# 验收标准

1. 本地及远程文件夹中包含上述 20 种后缀（含大写或大小写混合后缀）的视频文件在目录浏览时均被识别为视频，执行 Index 后均能与同目录外挂字幕正常配对入库。
2. 同目录下存在多个同名不同后缀视频时，严格按上述 20 种后缀优先级顺序匹配唯一最高优先级视频。
3. 在 File 页面打开上述 20 种后缀视频的「文件详情」弹窗时，`Format` 字段均正确展示对应的完整标准格式名称。