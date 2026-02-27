# VoicePaste 开发进度

## 当前版本：v0.1（已推送至 GitHub）

### 已完成

**Phase 1 — 基础架构 + 录音**
- SPM 项目结构（Package.swift, main.swift, AppDelegate）
- StatusBarController：代码完成，但 menu bar 图标在 SPM 构建下不显示（已知问题，推迟到 Phase 5）
- HotkeyManager：右 Option 键按下/松开检测（CGEvent tap, listenOnly 模式）
- AudioRecorder：AVAudioEngine 录音，硬件采样率 mono float32 WAV
- AppCoordinator：连接所有组件，管理状态流转
- VoicePasteError：统一错误类型

**Phase 2 — 语音转文字**
- ConfigManager：读写 `~/.config/voicepaste/config.json`，snake_case JSON
- WhisperService：调用本地 whisper-cli，使用 ggml-base.bin 模型
  - 最初用 ggml-large-v3-turbo（1.5GB），转写 12 秒太慢
  - 换成 ggml-base（141MB），1-3 秒完成
  - 曾尝试 Apple SFSpeechRecognizer，但 SPM 构建缺少 Info.plist 导致 TCC 崩溃

**Phase 3 — LLM 润色**
- LLMService：支持智谱 GLM / DeepSeek / OpenAI，Chat Completions 兼容格式
- 配置文件使用智谱 GLM-4-Flash（免费）
- 润色 prompt：保持原文语言、去除填充词、修正语法、保持原意

### 已知问题

1. **Menu bar 图标不显示**：SPM 构建的可执行文件没有 app bundle 结构，NSStatusItem 图标不渲染。代码逻辑正确，需要打包成 .app 才能解决。
2. **中英混说准确度**：base 模型中英混说时可能不够准确，但 LLM 润色可以修正大部分问题。

### 技术变更记录

| 原计划 | 实际实现 | 原因 |
|--------|----------|------|
| Option+Space 快捷键 | 右 Option 键 | Option+Space 与 macOS 输入法切换冲突 |
| OpenAI Whisper API | 本地 whisper.cpp | 免费、离线、无需 API key |
| 16kHz 16-bit PCM 录音 | 硬件采样率 float32 | 实时格式转换导致 AVAudioFile.write 崩溃 |
| ggml-large-v3-turbo 模型 | ggml-base 模型 | large 模型 12 秒太慢，base 1-3 秒 |
| Anthropic Claude 润色 | 智谱 GLM-4-Flash | 用户有智谱 API key，GLM-4-Flash 免费 |

### 未完成

- [ ] Phase 4：剪贴板写入 + 自动粘贴（Cmd+V 模拟）
- [ ] Phase 5：Menu bar 下拉菜单、设置界面、声音反馈、错误通知
- [ ] 打包成 .app bundle（解决 menu bar 图标问题）
- [ ] 属性测试（可选）
