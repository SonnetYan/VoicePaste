# 需求文档

## 简介

VoicePaste 是一个 macOS menu bar 应用，用户按住右 Option 键录音，松开后通过 AI 将语音转为润色后的文字，自动写入剪贴板并粘贴到当前光标位置。目标用户为开发者自用，技术栈为 Swift + SwiftUI，使用本地 whisper.cpp 进行语音转文字（离线，无需 API key），使用可配置的 LLM API（如智谱 GLM、DeepSeek、OpenAI 等）进行文本润色。项目使用 Swift Package Manager (SPM) 构建，不使用 Xcode 项目文件。

## 术语表

- **VoicePaste_App**: macOS menu bar 应用主体，负责协调录音、转写、润色、粘贴的完整流程
- **Audio_Recorder**: 音频录制组件，使用 AVAudioEngine 进行麦克风录音
- **Whisper_Service**: 语音转文字服务，调用本地 whisper.cpp（whisper-cli）将音频转为文字，完全离线运行
- **LLM_Service**: 文本润色服务，调用可配置的 LLM API（如智谱 GLM、DeepSeek、OpenAI 等）对转写文字进行润色
- **Clipboard_Manager**: 剪贴板管理组件，负责将文字写入系统剪贴板并模拟粘贴
- **Hotkey_Manager**: 全局快捷键管理组件，负责注册和监听全局快捷键
- **Config_Manager**: 配置管理组件，负责读写 `~/.config/voicepaste/config.json` 配置文件
- **StatusBar_Controller**: Menu bar 图标和状态管理组件，负责显示应用状态和下拉菜单
- **Settings_View**: 设置界面，提供 API key 配置、快捷键自定义、开机自启动等选项
- **录音状态**: 用户按住快捷键期间，应用正在录制音频的状态
- **处理状态**: 录音结束后，应用正在调用 API 进行转写和润色的状态

## 需求

### 需求 1：Menu Bar 应用基础架构

**用户故事：** 作为开发者，我希望 VoicePaste 作为 menu bar 应用运行，以便它不占用 Dock 空间且随时可用。

#### 验收标准

1. THE VoicePaste_App SHALL 以 SwiftUI lifecycle 运行，且不在 Dock 中显示图标
2. THE StatusBar_Controller SHALL 在 macOS menu bar 中显示一个麦克风图标
3. THE VoicePaste_App SHALL 使用 Swift Package Manager (SPM) 构建，通过 `swift build` 命令编译
4. THE VoicePaste_App SHALL 使用 Swift 5.9+ 和 macOS 系统框架，不引入第三方依赖库

### 需求 2：全局快捷键与录音

**用户故事：** 作为开发者，我希望按住全局快捷键录音、松开后停止录音，以便快速进行语音输入。

#### 验收标准

1. THE Hotkey_Manager SHALL 注册 `Option + Space` 作为默认全局快捷键
2. WHEN 用户按下全局快捷键, THE Audio_Recorder SHALL 使用 AVAudioEngine 开始录制麦克风音频
3. WHEN 用户松开全局快捷键, THE Audio_Recorder SHALL 停止录音并将音频保存为 WAV 格式文件至 `/tmp/voicepaste_recording.wav`
4. WHILE Audio_Recorder 处于录音状态, THE StatusBar_Controller SHALL 将 menu bar 图标显示为红色
5. WHEN Audio_Recorder 停止录音, THE StatusBar_Controller SHALL 将 menu bar 图标恢复为白色
6. WHEN 录音完成, THE Audio_Recorder SHALL 生成文件大小大于 0 字节的有效 WAV 音频文件

### 需求 3：语音转文字 (STT)

**用户故事：** 作为开发者，我希望录音结束后自动将语音转为文字，以便获得语音内容的文本形式。

#### 验收标准

1. WHEN 录音完成, THE Whisper_Service SHALL 读取 WAV 音频文件并调用本地 whisper.cpp（whisper-cli）进行转写，优先使用 ggml-base 模型
2. WHEN whisper-cli 返回成功输出, THE Whisper_Service SHALL 提取转写文本并传递给下游处理流程
3. THE Whisper_Service SHALL 使用本地模型，不需要 API key，完全离线运行
4. WHEN Whisper_Service 执行失败（whisper-cli 不存在、模型文件缺失、进程异常退出）, THE Whisper_Service SHALL 返回描述性错误信息而不导致应用崩溃
5. THE Whisper_Service SHALL 正确转写中文和英文语音内容

### 需求 4：配置文件管理

**用户故事：** 作为开发者，我希望通过配置文件管理 API key 和其他设置，以便安全且灵活地配置应用。

#### 验收标准

1. THE Config_Manager SHALL 从 `~/.config/voicepaste/config.json` 读取配置信息
2. THE Config_Manager SHALL 支持读取以下配置字段：`llm_provider`（润色服务提供商名称）和 `llm_api_key`（润色服务 API key），`openai_api_key` 为可选字段（本地 Whisper 不需要）
3. IF 配置文件不存在或格式无效, THEN THE Config_Manager SHALL 返回明确的错误提示信息
4. WHEN 用户通过 Settings_View 修改配置, THE Config_Manager SHALL 将更新后的配置写入配置文件
5. THE Config_Manager SHALL 对配置文件中的 JSON 内容进行序列化和反序列化处理

### 需求 5：AI 文本润色

**用户故事：** 作为开发者，我希望转写的文字经过 AI 润色，以便获得清晰流畅的书面文字。

#### 验收标准

1. WHEN Whisper_Service 返回转写文本, THE LLM_Service SHALL 调用配置中指定的 LLM API 进行润色（默认支持 DeepSeek、OpenAI 等兼容 OpenAI Chat Completions 格式的 API）
2. THE LLM_Service SHALL 使用指定的 system prompt，指示 AI 保持原文语言、去除口语填充词、修正语法错误、保持原意
3. WHEN LLM API 返回成功响应, THE LLM_Service SHALL 提取润色后的文本并传递给下游处理流程
4. THE LLM_Service SHALL 从 Config_Manager 获取 LLM API key 和提供商配置，不在代码中硬编码任何 API key
5. WHEN LLM_Service 的网络请求超时或失败, THE LLM_Service SHALL 返回描述性错误信息而不导致应用崩溃
6. THE LLM_Service SHALL 保持输入语言与输出语言一致（中文输入输出中文，英文输入输出英文）
7. THE LLM_Service SHALL 支持通过配置文件切换不同的 LLM 提供商和模型，无需修改代码

### 需求 6：剪贴板写入与自动粘贴

**用户故事：** 作为开发者，我希望润色后的文字自动写入剪贴板并粘贴到当前光标位置，以便无缝地将语音转化为文字输入。

#### 验收标准

1. WHEN LLM_Service 返回润色文本, THE Clipboard_Manager SHALL 将文本写入 macOS 系统剪贴板 (NSPasteboard)
2. WHEN 文本成功写入剪贴板, THE Clipboard_Manager SHALL 使用 CGEvent 模拟 `Cmd+V` 按键将文本粘贴到当前光标位置
3. THE VoicePaste_App SHALL 请求 macOS 辅助功能权限 (Accessibility) 以支持模拟按键操作
4. WHILE VoicePaste_App 处于处理状态（API 调用中）, THE StatusBar_Controller SHALL 将 menu bar 图标显示为橙色
5. WHEN 处理完成且文本成功粘贴, THE StatusBar_Controller SHALL 将 menu bar 图标短暂显示为绿色后恢复白色

### 需求 7：Menu Bar 下拉菜单

**用户故事：** 作为开发者，我希望通过 menu bar 图标访问常用功能，以便快速查看结果和管理应用。

#### 验收标准

1. WHEN 用户点击 menu bar 图标, THE StatusBar_Controller SHALL 显示下拉菜单
2. THE StatusBar_Controller SHALL 在下拉菜单中显示上一次的润色结果文本
3. WHEN 用户点击润色结果文本, THE Clipboard_Manager SHALL 将该文本复制到系统剪贴板
4. THE StatusBar_Controller SHALL 在下拉菜单中提供"设置"入口和"退出"按钮
5. WHEN 用户点击"退出"按钮, THE VoicePaste_App SHALL 正常终止运行

### 需求 8：设置界面

**用户故事：** 作为开发者，我希望通过设置界面配置应用参数，以便自定义应用行为。

#### 验收标准

1. WHEN 用户点击下拉菜单中的"设置", THE Settings_View SHALL 显示设置窗口
2. THE Settings_View SHALL 提供 LLM 润色服务 API key 的输入字段，以及 LLM 提供商选择
3. WHEN 用户在 Settings_View 中保存 API key, THE Config_Manager SHALL 将新的 API key 持久化到配置文件，后续 API 调用使用新 key
4. THE Settings_View SHALL 提供快捷键自定义功能
5. THE Settings_View SHALL 提供开机自启动开关
6. WHEN 用户启用开机自启动, THE VoicePaste_App SHALL 在 macOS 登录时自动启动

### 需求 9：声音与通知反馈

**用户故事：** 作为开发者，我希望应用提供声音和通知反馈，以便了解当前操作状态。

#### 验收标准

1. WHEN Audio_Recorder 开始录音, THE VoicePaste_App SHALL 播放一声短促的"嘀"提示音
2. WHEN 整个处理流程完成（润色文本已粘贴）, THE VoicePaste_App SHALL 播放一声短促的"嘟"提示音
3. WHEN Whisper_Service 或 LLM_Service 发生错误, THE VoicePaste_App SHALL 通过 macOS 系统通知 (UserNotifications) 向用户显示错误信息

### 需求 10：完整处理流水线

**用户故事：** 作为开发者，我希望从按下快捷键到文字粘贴的整个流程自动完成，以便获得流畅的语音输入体验。

#### 验收标准

1. WHEN 用户松开全局快捷键, THE VoicePaste_App SHALL 自动依次执行：录音保存 → Whisper 转写 → LLM 润色 → 剪贴板写入 → 自动粘贴
2. WHILE 处理流水线执行中, THE StatusBar_Controller SHALL 按以下顺序更新图标颜色：红色（录音）→ 橙色（API 处理）→ 绿色闪烁（完成）→ 白色（空闲）
3. IF 处理流水线中任一步骤失败, THEN THE VoicePaste_App SHALL 停止后续步骤并通过通知告知用户错误原因
4. THE VoicePaste_App SHALL 对所有网络请求设置合理的超时时间并包含错误处理逻辑
