# 实现计划：VoicePaste

## 概述

按照 Phase 递进的方式实现 VoicePaste macOS menu bar 应用。每个 Phase 是一个独立可运行的 MVP，后续 Phase 在前一个基础上增量构建。使用 Swift Package Manager 构建，不引入第三方依赖。

## 任务

- [x] 1. 项目初始化与 Menu Bar 基础架构
  - [x] 1.1 创建 SPM 项目结构
    - 创建 `Package.swift`（macOS 13+, executableTarget, swift-tools-version 6.0 + v5 language mode）
    - 创建 `Sources/main.swift` 作为 App 入口（NSApplication 手动启动）
    - 使用 `NSApp.setActivationPolicy(.accessory)` 隐藏 Dock 图标
    - _Requirements: 1.1, 1.3, 1.4_
  - [~] 1.2 实现 StatusBarController 基础功能 ⚠️ **已知问题：menu bar 图标未显示，待排查**
    - 创建 `Sources/StatusBarController.swift`
    - 使用 `NSStatusBar.system.statusItem` 创建 menu bar 项
    - 显示 SF Symbols `mic.fill` / `mic.circle.fill` 麦克风图标
    - 实现 `AppState` 枚举和 `setState()` 方法，支持 idle/recording/processing/done 状态对应的颜色切换（白/红/橙/绿）
    - ⚠️ 代码已写好，但运行时 menu bar 图标不显示，可能与 SPM 构建的 app 缺少 Info.plist 或 bundle 结构有关，推迟到 Phase 5 一并解决
    - _Requirements: 1.2, 2.4, 2.5, 6.4, 6.5_
  - [ ]* 1.3 编写 StatusBar 状态颜色映射属性测试
    - **Property 3: 应用状态到图标颜色的映射一致性**
    - **Validates: Requirements 2.4, 2.5, 6.4, 6.5, 10.2**

- [x] 2. 全局快捷键与录音功能 (Phase 1)
  - [x] 2.1 实现 HotkeyManager ✅
    - 创建 `Sources/HotkeyManager.swift`
    - 使用 `CGEvent.tapCreate` 监听全局键盘事件（`.listenOnly` 模式）
    - ~~检测 Option + Space~~ → 改为检测右 Option 键（keyCode 61）单独按下/松开
    - 提供 `onKeyDown` 和 `onKeyUp` 回调
    - 包含 tap 超时自动恢复处理
    - _Requirements: 2.1_
  - [x] 2.2 实现 AudioRecorder ✅
    - 创建 `Sources/AudioRecorder.swift`
    - 使用 `AVAudioEngine` 的 `inputNode` 获取麦克风输入
    - 实现 `startRecording()` 和 `stopRecording() -> URL`
    - ~~录音格式：16kHz, 单声道, 16-bit PCM WAV~~ → 改为硬件采样率单声道 float32 WAV（避免实时转换崩溃）
    - 输出文件路径：`/tmp/voicepaste_recording.wav`
    - _Requirements: 2.2, 2.3, 2.6_
  - [x] 2.3 实现 AppCoordinator 基础流程并连接组件 ✅
    - 创建 `Sources/AppCoordinator.swift`
    - 连接 HotkeyManager 的按键事件到 AudioRecorder 的开始/停止录音
    - 连接状态变化到 StatusBarController 的图标颜色更新
    - 在 `main.swift` 中通过 AppDelegate 初始化 AppCoordinator
    - 额外创建了 `Sources/VoicePasteError.swift` 统一错误类型
    - _Requirements: 2.2, 2.3, 2.4, 2.5_

- [~] 3. Checkpoint - Phase 1 验证 ⚠️ **部分通过**
  - [x] `swift build` 编译通过
  - [ ] ~~运行后 menu bar 出现麦克风图标~~ ⚠️ 未显示，推迟解决
  - [ ] ~~按住快捷键图标变红，松开恢复白色~~ ⚠️ 图标未显示，无法验证
  - [x] 按住右 Option 录音，松开停止，功能正常
  - [x] `/tmp/voicepaste_recording.wav` 生成且大小 > 0
  - [x] `afplay` 播放录音内容正确

- [x] 4. 配置管理与 Whisper 语音转文字 (Phase 2)
  - [x] 4.1 实现 ConfigManager ✅
    - 创建 `Sources/ConfigManager.swift`
    - 实现 `AppConfig` Codable 结构体（openaiApiKey 改为可选, llmProvider, llmApiKey, llmModel, llmBaseURL, hotkeyModifiers, hotkeyKeyCode, launchAtLogin）
    - 实现 `load() throws -> AppConfig` 和 `save(_ config: AppConfig) throws`
    - 配置文件路径：`~/.config/voicepaste/config.json`
    - 使用 snake_case JSON 编码策略
    - 处理文件不存在和格式无效的错误情况
    - _Requirements: 4.1, 4.2, 4.3, 4.5_
  - [ ]* 4.2 编写 ConfigManager 属性测试
    - **Property 1: 配置文件序列化反序列化往返一致性**
    - **Validates: Requirements 4.1, 4.2, 4.5**
    - **Property 2: 无效配置文件错误处理**
    - **Validates: Requirements 4.3**
  - [x] 4.3 实现 WhisperService ✅ **重大变更：改用本地 whisper.cpp**
    - 创建 `Sources/WhisperService.swift`
    - ~~使用 `URLSession` 构建 multipart/form-data POST 请求~~ → 改为调用本地 `whisper-cli` 命令行工具
    - ~~endpoint: `https://api.openai.com/v1/audio/transcriptions`~~ → 本地执行，无需网络
    - ~~请求体：file (WAV 数据) + model ("whisper-1")~~ → 优先使用 `ggml-base.bin` 模型（141MB，速度快）
    - ~~解析 JSON 响应提取 `text` 字段~~ → 直接读取 stdout 输出
    - ~~设置 30 秒超时~~ → 本地执行
    - ~~从 ConfigManager 获取 API key~~ → 不需要 API key
    - 通过 `Process` 调用 `/opt/homebrew/bin/whisper-cli`
    - 模型路径：`~/.local/share/whisper-cpp/models/`（按 small > base > large 优先级选择）
    - 使用 `-l auto` 自动语言检测，`-t 8` 多线程，`-bs 1` greedy decoding 加速
    - _Requirements: 3.1, 3.2, 3.4, 3.5_
  - [ ]* 4.4 编写 WhisperService 属性测试
    - **Property 4: Whisper 输出解析正确性**（已调整为本地模式）
    - **Validates: Requirements 3.2**
    - **Property 5: Whisper 错误处理**（已调整为本地模式）
    - **Validates: Requirements 3.4**
  - [x] 4.5 将 WhisperService 集成到 AppCoordinator 流水线 ✅
    - 录音结束后调用 `WhisperService.transcribe(audioURL:)`
    - 将转写结果打印到控制台（含耗时统计）
    - 处理转写错误
    - 修复了 pipeline 完成后状态未恢复 idle 导致无法二次录音的 bug
    - _Requirements: 3.1, 3.2_

- [x] 5. Checkpoint - Phase 2 验证 ✅
  - [x] `swift build` 编译通过
  - [x] 录音后控制台输出转写文本（本地 Whisper，无需 API key）
  - [x] 可连续多次录音和转写
  - [x] 中文语音正确转写
  - [x] 英文语音正确转写

- [x] 6. LLM 文本润色 (Phase 3)
  - [x] 6.1 实现 LLMService ✅
    - 创建 `Sources/LLMService.swift`
    - 实现 OpenAI Chat Completions 兼容的请求构建（支持智谱 GLM、DeepSeek、OpenAI）
    - 根据 `llm_provider` 配置选择 base URL 和默认模型
    - 智谱默认：`https://open.bigmodel.cn/api/paas/v4/chat/completions`，模型 `glm-4-flash`
    - 内置润色 system prompt（保持原文语言、去除填充词、修正语法、保持原意）
    - 解析 `choices[0].message.content` 响应
    - 设置 30 秒超时
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_
  - [ ]* 6.2 编写 LLMService 属性测试
    - **Property 6: LLM API 响应解析正确性**
    - **Validates: Requirements 5.3**
    - **Property 7: LLM API 错误响应处理**
    - **Validates: Requirements 5.5**
    - **Property 8: LLM 提供商配置切换**
    - **Validates: Requirements 5.7**
  - [x] 6.3 将 LLMService 集成到 AppCoordinator 流水线 ✅
    - 转写完成后调用 `LLMService.polish(text:)`
    - 将原始转写和润色结果都打印到控制台（含耗时统计）
    - 处理润色错误
    - _Requirements: 5.1, 5.3_

- [x] 7. Checkpoint - Phase 3 验证 ✅
  - [x] 控制台能看到 Whisper 原始结果和 LLM 润色结果的对比
  - [x] 润色结果去除了口语填充词
  - [x] 每步耗时统计正常显示

- [ ] 8. 剪贴板与自动粘贴 (Phase 4)
  - [ ] 8.1 实现 ClipboardManager
    - 创建 `Sources/ClipboardManager.swift`
    - 实现 `copyToClipboard(_ text: String)` 使用 `NSPasteboard.general`
    - 实现 `simulatePaste()` 使用 `CGEvent` 模拟 Cmd+V
    - 实现 `pasteText(_ text: String)` 组合复制+粘贴
    - 粘贴前添加 ~100ms 延迟确保剪贴板就绪
    - _Requirements: 6.1, 6.2, 6.3_
  - [ ]* 8.2 编写 ClipboardManager 属性测试
    - **Property 9: 剪贴板写入往返一致性**
    - **Validates: Requirements 6.1**
  - [ ] 8.3 将 ClipboardManager 集成到 AppCoordinator 并完善状态流转
    - 润色完成后调用 `ClipboardManager.pasteText()`
    - 更新 StatusBarController 状态：recording→processing→done→idle
    - done 状态绿色闪烁 0.5 秒后恢复白色
    - 请求辅助功能权限
    - _Requirements: 6.1, 6.2, 6.4, 6.5, 10.1, 10.2_
  - [ ]* 8.4 编写流水线失败中断属性测试
    - **Property 10: 流水线失败中断后续步骤**
    - **Validates: Requirements 10.3**

- [ ] 9. Checkpoint - Phase 4 验证
  - 确保在 TextEdit 中按住快捷键说话后，润色文字自动粘贴到光标位置
  - 确保图标颜色变化符合预期（红→橙→绿闪→白）
  - 确保剪贴板内容与粘贴内容一致
  - 如有问题请告知用户

- [ ] 10. 设置界面与体验优化 (Phase 5)
  - [ ] 10.1 实现 Menu Bar 下拉菜单
    - 更新 `StatusBarController` 添加 `NSMenu` 下拉菜单
    - 显示上一次润色结果（可点击复制到剪贴板）
    - 添加"设置"菜单项和"退出"菜单项
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_
  - [ ] 10.2 实现 SettingsView
    - 创建 `Sources/SettingsView.swift`
    - 使用 SwiftUI Form 布局
    - LLM 提供商选择和 API key 输入（SecureField）
    - 快捷键自定义
    - 开机自启动开关（使用 SMAppService）
    - 保存时调用 ConfigManager.save()
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_
  - [ ] 10.3 实现声音反馈和错误通知
    - 创建 `Sources/SoundManager.swift`，使用系统音效（Tink/Glass）
    - 创建 `Sources/NotificationManager.swift`，使用 UNUserNotificationCenter
    - 录音开始播放"嘀"，处理完成播放"嘟"
    - API 错误时发送系统通知
    - 集成到 AppCoordinator 流水线
    - _Requirements: 9.1, 9.2, 9.3, 10.3_

- [ ] 11. 最终 Checkpoint - Phase 5 验证
  - 确保点击 menu bar 图标下拉菜单正常显示
  - 确保设置界面可以修改并保存 API key
  - 确保录音开始和完成时有声音反馈
  - 确保 API 调用失败时收到系统通知
  - 确保所有测试通过
  - 如有问题请告知用户

## 备注

- 标记 `*` 的任务为可选任务，可跳过以加速 MVP 开发
- 每个 Checkpoint 对应原始 startDoc.md 中的验证清单
- 属性测试验证通用正确性属性，单元测试验证具体示例和边界情况
- 项目严格遵循最小依赖原则，仅使用 macOS 系统框架
