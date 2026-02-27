import Foundation

class LLMService {
    // Provider defaults
    private static let providerDefaults: [String: (baseURL: String, model: String)] = [
        "zhipu":    ("https://open.bigmodel.cn/api/paas/v4/chat/completions", "glm-4-flash"),
        "deepseek": ("https://api.deepseek.com/v1/chat/completions", "deepseek-chat"),
        "openai":   ("https://api.openai.com/v1/chat/completions", "gpt-4o-mini"),
    ]

    private let systemPrompt = """
    你是一个文本润色助手。用户会给你一段语音转写的原始文本，请你：
    1. 保持原文的语言（中文部分输出中文，英文部分输出英文）
    2. 如果原文中英混说，忠实保留中英混用的风格
    3. 去除口语填充词（嗯、啊、那个、就是、like、you know 等）
    4. 修正明显的语法错误和语音识别错误
    5. 保持原意，不要添加或删除实质内容
    6. 不要添加任何解释或注释，只输出润色后的文本
    """

    func polish(text: String) async throws -> String {
        let config = try ConfigManager.shared.load()

        let provider = config.llmProvider.lowercased()
        guard let defaults = LLMService.providerDefaults[provider] else {
            throw VoicePasteError.llmAPIError(statusCode: 0, message: "Unsupported LLM provider: \(config.llmProvider). Supported: zhipu, deepseek, openai")
        }

        let baseURL = config.llmBaseURL ?? defaults.baseURL
        let model = config.llmModel ?? defaults.model
        let apiKey = config.llmApiKey

        guard let url = URL(string: baseURL) else {
            throw VoicePasteError.llmAPIError(statusCode: 0, message: "Invalid base URL: \(baseURL)")
        }

        // Build request body
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoicePasteError.llmAPIError(statusCode: 0, message: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VoicePasteError.llmAPIError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw VoicePasteError.llmResponseParseError("Cannot parse choices[0].message.content")
        }

        let result = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty {
            throw VoicePasteError.llmResponseParseError("LLM returned empty content")
        }

        return result
    }
}
