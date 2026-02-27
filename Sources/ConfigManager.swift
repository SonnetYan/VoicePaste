import Foundation

struct AppConfig: Codable {
    var openaiApiKey: String?      // optional — not needed for local Whisper
    var llmProvider: String        // "deepseek", "openai", "anthropic"
    var llmApiKey: String
    var llmModel: String?          // optional override
    var llmBaseURL: String?        // optional custom endpoint
    var hotkeyModifiers: UInt?
    var hotkeyKeyCode: UInt?
    var launchAtLogin: Bool?
}

class ConfigManager {
    static let shared = ConfigManager()

    var configFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/voicepaste/config.json")
    }

    func load() throws -> AppConfig {
        let url = configFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VoicePasteError.configFileNotFound
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw VoicePasteError.configInvalidFormat("Cannot read file: \(error.localizedDescription)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let config = try decoder.decode(AppConfig.self, from: data)
            // Validate required fields are not empty
            if config.llmApiKey.isEmpty {
                throw VoicePasteError.configMissingField("llm_api_key")
            }
            return config
        } catch let error as VoicePasteError {
            throw error
        } catch {
            throw VoicePasteError.configInvalidFormat(error.localizedDescription)
        }
    }

    func save(_ config: AppConfig) throws {
        let url = configFileURL
        let dir = url.deletingLastPathComponent()

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }
}
