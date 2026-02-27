import Foundation

enum VoicePasteError: LocalizedError {
    case configFileNotFound
    case configInvalidFormat(String)
    case configMissingField(String)
    case audioRecordingFailed(String)
    case whisperAPIError(statusCode: Int, message: String)
    case whisperResponseParseError(String)
    case whisperTimeout
    case llmAPIError(statusCode: Int, message: String)
    case llmResponseParseError(String)
    case llmTimeout
    case clipboardWriteFailed
    case accessibilityPermissionDenied
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .configFileNotFound:
            return "Config file not found at ~/.config/voicepaste/config.json"
        case .configInvalidFormat(let detail):
            return "Invalid config format: \(detail)"
        case .configMissingField(let field):
            return "Missing config field: \(field)"
        case .audioRecordingFailed(let detail):
            return "Recording failed: \(detail)"
        case .whisperAPIError(let code, let msg):
            return "Whisper API error (\(code)): \(msg)"
        case .whisperResponseParseError(let detail):
            return "Whisper response parse error: \(detail)"
        case .whisperTimeout:
            return "Whisper API request timed out"
        case .llmAPIError(let code, let msg):
            return "LLM API error (\(code)): \(msg)"
        case .llmResponseParseError(let detail):
            return "LLM response parse error: \(detail)"
        case .llmTimeout:
            return "LLM API request timed out"
        case .clipboardWriteFailed:
            return "Failed to write to clipboard"
        case .accessibilityPermissionDenied:
            return "Accessibility permission denied. Grant in System Settings → Privacy & Security → Accessibility."
        case .microphonePermissionDenied:
            return "Microphone permission denied. Grant in System Settings → Privacy & Security → Microphone."
        }
    }
}
