# VoicePaste

macOS menu bar 语音输入工具。按住右 Option 键说话，松开后自动转写 + LLM 润色，结果输出到终端。

## 功能

- 按住右 Option 键录音，松开停止
- 本地 whisper.cpp 语音转文字（离线，无需 API key）
- 智谱 GLM / DeepSeek / OpenAI 等 LLM 文本润色
- 纯 Swift，零第三方依赖

## 依赖

- macOS 13+
- Xcode Command Line Tools
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp)：`brew install whisper-cpp`
- Whisper 模型（放在 `~/.local/share/whisper-cpp/models/`）

下载模型：
```bash
mkdir -p ~/.local/share/whisper-cpp/models
# base 模型（141MB，速度快）
curl -L -o ~/.local/share/whisper-cpp/models/ggml-base.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
```

## 配置

创建 `~/.config/voicepaste/config.json`：

```json
{
  "llm_provider": "zhipu",
  "llm_api_key": "your-api-key-here"
}
```

支持的 `llm_provider`：`zhipu`、`deepseek`、`openai`

## 构建与运行

```bash
swift build
.build/debug/VoicePaste
```

## 权限

首次运行需要授予：
- 麦克风权限
- 辅助功能权限（System Settings → Privacy & Security → Accessibility）

## 当前状态

- [x] 全局快捷键（右 Option 键）
- [x] 录音（AVAudioEngine）
- [x] 本地 Whisper 转写
- [x] LLM 文本润色
- [ ] 剪贴板写入 + 自动粘贴
- [ ] Menu bar 下拉菜单
- [ ] 设置界面
- [ ] 声音反馈
