<p align="center">
  <img src="assets/brand/banner-zh.png" alt="字幕求索">
</p>

<p align="center">
  <a href="README.md">English</a> | 简体中文 | <a href="README.zh-Hant.md">繁體中文</a>
</p>

## 项目简介

字幕求索是一个以搜索字幕、摘录字幕和队列播放字幕为核心的语言学习工具，兼具导出 Anki 卡片、Deep Link、长截图等诸多实用功能。

## 构建指南

### 环境要求

- **操作系统**：macOS 13 (Ventura) 或更高版本。
- **硬件架构**：仅支持 Apple Silicon 芯片(M 系列芯片)，不支持 Intel 芯片(x86_64)。
- **开发工具**：Xcode 16+ 或 Xcode Command Line Tools。
- **依赖环境**：macOS 系统自带的 `python3`（构建脚本仅在内部临时创建虚拟环境用于驱动 Meson/Ninja，不污染全局环境）。

### 编译与运行

#### 1. 准备工作

在开始构建前，需要安装苹果命令行开发者工具（如已安装可跳过）：

```bash
xcode-select --install
```

#### 2. 构建媒体运行时（仅首次需要）

字幕求索依赖专有的自包含媒体运行时（集成 FFmpeg、libass 及其必要补丁）。在项目根目录下执行一次构建脚本：

```bash
./scripts/build_macos_media_runtime.sh
```

#### 3. 本地开发与运行

进入原生应用目录，通过 SwiftPM 直接启动：

```bash
cd apps/macos-native
swift run CueSeeker
```

#### 4. 打包独立应用

如需打包发布版独立应用（`.app`），在根目录运行打包脚本：

```bash
./scripts/package_macos_app.sh
```

打包产物位于 `.build/distribution/CueSeeker.app`。

## 致谢

- **字幕组和汉化组**：因为有大家的努力，这个项目才有了构建的可能和维护的意义。
- **哔哩哔哩 *It's MyGO!!!!!* & *Ave Mujica* 二创社区**：我喜欢 *It's MyGO!!!!!*，还有大家。
- **暗喻幻想**：谢谢你带给我的美好回忆，我仍然被困在 2024 年的那个秋天。
- **我的家人**：感谢开发旅程中的鼓励与支持。

## 第三方依赖

字幕求索的运行与视觉呈现依赖以下优秀的开源项目：

### 媒体与音视频处理

底层的媒体解封装、软解兜底与字幕渲染基于定制编译的动态库链条（完全禁用 GPL/Nonfree 组件，遵循 LGPL / BSD 协议）：

- **[FFmpeg](https://ffmpeg.org/) (8.1.2)**：音视频解封装与解码核心（LGPL v2.1+）。
- **[libass](https://github.com/libass/libass) (0.17.4)**：原生 ASS 样式字幕渲染引擎（ISC）。
- **[dav1d](https://code.videolan.org/videolan/dav1d) (1.5.4)**：AV1 视频封面提取软解（BSD-2-Clause）。
- **[LAME](https://lame.sourceforge.io/) (3.100)**：用于 Anki 导出的音频 MP3 编码器（LGPL v2.0+）。
- **[FreeType](https://freetype.org/)** / **[HarfBuzz](https://harfbuzz.github.io/)** / **[FriBidi](https://github.com/fribidi/fribidi)** / **[libunibreak](https://github.com/adah1972/libunibreak)**：字体栅格化、文本塑形、双向排版与文本分词底层依赖。

### 界面与视觉资产

- **[Phosphor Icons](https://phosphoricons.com/)**：应用的界面图标均来自 Phosphor 矢量图标库原稿（MIT License），内置于应用资源包中。

## 开源协议

本项目自身采用 **[MIT License](LICENSE)** 开源。

打包分发版中的第三方媒体库各自保留其开源许可声明（涵盖 LGPL、BSD、ISC 等），完整的第三方授权文件请参见应用包内的 `CueSeeker.app/Contents/Resources/ThirdPartyLicenses/` 目录。