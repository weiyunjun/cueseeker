### 版本
main
### bug描述
1. 之前的一次修复，6月8日，a92e175e，为了解决编译问题，将/private/tmp/cueseeker-ffmpeg-8.1-patched的链接改成了homebrew的ffmpeg路径。
2. 这导致了，参数还在代码里，但实际运行时回退到了不支持该自定义参数的 Homebrew FFmpeg，所以参数失效。代码主要作用是跳过mkv内封字幕及附件。
3. 该bug除了错误的修复方式之外，还错误引用了6月3日的单子，docs/human/requirements/20260603-Bug-Avoid Embedded MKV Attachment Playback Open Stall.md。这是流程问题，不应该跨天执行一个单子。
4. 修复方案应该基于不会破坏任何已有的构建参数，并且任何改动不可以基于已经过时的需求单。这一点需要写进工程规范中。
