<p align="center">
  <img src="assets/brand/banner-zh.png" alt="字幕求索">
</p>

<p align="center">
  <a href="README.md">English</a> | <a href="README.zh-Hans.md">简体中文</a> | 繁體中文
</p>

## 專案簡介

字幕求索是一個以搜尋字幕、摘錄字幕和佇列播放字幕為核心的語言學習工具，兼具匯出 Anki 卡片、Deep Link、長截圖等諸多實用功能。

## 建置指南

### 環境需求

- **作業系統**：macOS 13 (Ventura) 或更高版本。
- **硬體架構**：僅支援 Apple Silicon 晶片（M 系列晶片），不支援 Intel 晶片（x86_64）。
- **開發工具**：Xcode 16+ 或 Xcode Command Line Tools。
- **相依環境**：macOS 系統內建的 `python3`（建置指令碼僅在內部暫時建立虛擬環境用於驅動 Meson/Ninja，不污染全域環境）。

### 編譯與執行

#### 1. 準備工作

在開始建置前，需要安裝 Apple 命令列開發者工具（如已安裝可略過）：

```bash
xcode-select --install
```

#### 2. 建置媒體執行階段（僅首次需要）

字幕求索依賴專有的自包含媒體執行階段（整合 FFmpeg、libass 及其必要修補程式）。在專案根目錄下執行一次建置指令碼：

```bash
./scripts/build_macos_media_runtime.sh
```

#### 3. 本地開發與執行

進入原生應用程式目錄，透過 SwiftPM 直接啟動：

```bash
cd apps/macos-native
swift run CueSeeker
```

#### 4. 打包獨立應用程式

如需打包發布版獨立應用程式（`.app`），在根目錄執行打包指令碼：

```bash
./scripts/package_macos_app.sh
```

打包產物位於 `.build/distribution/CueSeeker.app`。

## 致謝

- **字幕組與漢化組**：因為有大家的努力，這個專案才有了建置的可能和維護的意義。
- **嗶哩嗶哩 *It's MyGO!!!!!* & *Ave Mujica* 二創社群**：我喜歡 *It's MyGO!!!!!*，還有大家。
- **暗喻幻想**：謝謝你帶給我的美好回憶，我仍然被困在 2024 年的那個秋天。
- **我的家人**：感謝開發旅程中的鼓勵與支持。

## 第三方相依套件

字幕求索的執行與視覺呈現依賴以下優秀的開源專案：

### 媒體與影音處理

底層的媒體解封裝、軟體解碼後備與字幕渲染基於客製化編譯的動態程式庫鏈條（完全停用 GPL/Nonfree 元件，遵循 LGPL / BSD 協議）：

- **[FFmpeg](https://ffmpeg.org/) (8.1.2)**：影音解封裝與解碼核心（LGPL v2.1+）。
- **[libass](https://github.com/libass/libass) (0.17.4)**：原生 ASS 樣式字幕渲染引擎（ISC）。
- **[dav1d](https://code.videolan.org/videolan/dav1d) (1.5.4)**：AV1 影片封面擷取軟體解碼（BSD-2-Clause）。
- **[LAME](https://lame.sourceforge.io/) (3.100)**：用於 Anki 匯出的音訊 MP3 編碼器（LGPL v2.0+）。
- **[FreeType](https://freetype.org/)** / **[HarfBuzz](https://harfbuzz.github.io/)** / **[FriBidi](https://github.com/fribidi/fribidi)** / **[libunibreak](https://github.com/adah1972/libunibreak)**：字型光柵化、文字塑形、雙向排版與文字斷詞底層相依項目。

### 介面與視覺資產

- **[Phosphor Icons](https://phosphoricons.com/)**：應用程式的介面圖示均來自 Phosphor 向量圖示庫原稿（MIT License），內建於應用程式資源套件中。

## 開源授權

本專案自身採用 **[MIT License](LICENSE)** 開源。

打包發布版中的第三方媒體程式庫各自保留其開源授權聲明（涵蓋 LGPL、BSD、ISC 等），完整的第三方授權文件請參見應用程式套件內的 `CueSeeker.app/Contents/Resources/ThirdPartyLicenses/` 目錄。