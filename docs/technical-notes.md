# VoicePaste 技术笔记

这份文档记录了开发过程中用到的关键技术点，方便学习和回顾。

## 1. SPM 构建 macOS GUI 应用

Swift Package Manager 通常用于命令行工具和库，但也可以构建 GUI 应用：

```swift
// Package.swift
// swift-tools-version: 6.0 — 使用最新工具链
// .swiftLanguageMode(.v5) — 避免 Swift 6 严格并发检查的编译错误
let package = Package(
    name: "VoicePaste",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "VoicePaste",
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
```

入口文件 `main.swift` 手动启动 NSApplication：
```swift
let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // 隐藏 Dock 图标，只在 menu bar 显示
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

**已知限制**：SPM 构建的可执行文件没有 app bundle 结构（没有 Info.plist），导致：
- menu bar 图标可能不显示
- `SFSpeechRecognizer` 等需要隐私声明的 API 会崩溃（TCC 权限问题）
- 解决方案：Phase 5 打包成 .app bundle

## 2. 全局快捷键：CGEvent Tap

macOS 监听全局键盘事件有两种方式：
- `NSEvent.addGlobalMonitorForEvents` — 简单但功能有限
- `CGEvent.tapCreate` — 更底层，可以拦截/修改事件

我们用 CGEvent tap 监听右 Option 键：

```swift
// 创建事件 tap，只监听 flagsChanged（修饰键变化）
let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,      // 只监听，不拦截
    eventsOfInterest: (1 << CGEventType.flagsChanged.rawValue),
    callback: hotkeyCallback,
    userInfo: Unmanaged.passUnretained(self).toOpaque()
)
```

**关键点**：
- 右 Option 键的 keyCode 是 61（左 Option 是 58）
- 通过 `event.getIntegerValueField(.keyboardEventKeycode)` 区分左右
- 需要辅助功能权限（System Settings → Privacy & Security → Accessibility）
- tap 可能被系统超时禁用，需要监听 `.tapDisabledByTimeout` 并重新启用

## 3. AVAudioEngine 录音

```swift
let engine = AVAudioEngine()
let inputNode = engine.inputNode
let hardwareFormat = inputNode.outputFormat(forBus: 0)

// 关键：用硬件采样率录制，不做实时格式转换
// 之前尝试录制 16kHz 16-bit PCM 导致 AVAudioFile.write 崩溃
let recordingFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: hardwareFormat.sampleRate,  // 通常 48000Hz
    channels: 1,
    interleaved: false
)

inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
    try? file.write(from: buffer)
}
```

**踩坑**：在 realtime audio callback 里做格式转换（AVAudioConverter）会导致崩溃。正确做法是用硬件原生格式录制，Whisper 能处理各种采样率。

## 4. 本地 whisper.cpp 语音转文字

通过 `Process` 调用命令行工具，比集成 C 库简单得多：

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/whisper-cli")
process.arguments = [
    "-m", modelPath,
    "-l", "auto",       // 自动语言检测
    "-t", "8",           // 线程数（= CPU 核心数）
    "-bs", "1",          // greedy decoding，比 beam search 快
    "-nf",               // 不做 temperature fallback，避免重复解码
    "-f", audioPath,
    "--no-timestamps",
    "--no-prints"        // 只输出转写文本
]
```

**模型选择**：
| 模型 | 大小 | 速度 | 准确度 |
|------|------|------|--------|
| ggml-base.bin | 141MB | 快（1-3秒） | 够用，LLM 可修正 |
| ggml-small.bin | ~500MB | 中等 | 较好 |
| ggml-large-v3-turbo.bin | 1.5GB | 慢（12秒+） | 最好 |

**加速技巧**：`-t 8`（多线程）+ `-bs 1`（greedy）+ `-nf`（无 fallback）

## 5. LLM API 调用（OpenAI Chat Completions 兼容格式）

智谱 GLM、DeepSeek、OpenAI 都兼容同一种 API 格式：

```swift
let body: [String: Any] = [
    "model": model,
    "messages": [
        ["role": "system", "content": systemPrompt],
        ["role": "user", "content": text]
    ]
]
// 只需要改 base URL 和 API key 就能切换提供商
```

**提供商配置**：
| 提供商 | Base URL | 默认模型 | 价格 |
|--------|----------|----------|------|
| 智谱 | `open.bigmodel.cn/api/paas/v4/chat/completions` | glm-4-flash | 免费 |
| DeepSeek | `api.deepseek.com/v1/chat/completions` | deepseek-chat | 便宜 |
| OpenAI | `api.openai.com/v1/chat/completions` | gpt-4o-mini | 较贵 |

## 6. Swift async/await 与 Process 的桥接

`Process`（命令行调用）是同步阻塞的，需要桥接到 async 世界：

```swift
func transcribe(audioURL: URL) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.runWhisper(audioPath: audioURL.path)
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

**注意**：`continuation.resume` 只能调用一次，多次调用会崩溃。

## 7. 配置文件管理

使用 `JSONEncoder`/`JSONDecoder` 的 snake_case 策略，Swift 属性用 camelCase，JSON 文件用 snake_case：

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
// Swift: llmApiKey ↔ JSON: llm_api_key
```

配置文件路径遵循 XDG 规范：`~/.config/voicepaste/config.json`
