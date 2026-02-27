import Foundation

class WhisperService {
    private let whisperCLI = "/opt/homebrew/bin/whisper-cli"
    private let modelPath: String

    init() {
        modelPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/whisper-cpp/models/ggml-base.bin")
            .path
    }

    func transcribe(audioURL: URL) async throws -> String {
        // Verify whisper-cli exists
        guard FileManager.default.fileExists(atPath: whisperCLI) else {
            throw VoicePasteError.whisperAPIError(statusCode: 0, message: "whisper-cli not found. Install with: brew install whisper-cpp")
        }

        // Verify model exists
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw VoicePasteError.whisperAPIError(statusCode: 0, message: "Whisper model not found at \(modelPath)")
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do {
                    let result = try self.runWhisper(audioPath: audioURL.path)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runWhisper(audioPath: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperCLI)
        process.arguments = [
            "-m", modelPath,
            "-l", "auto",
            "-f", audioPath,
            "--no-timestamps",
            "--no-prints"       // suppress model loading info, only output text
        ]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw VoicePasteError.whisperAPIError(statusCode: Int(process.terminationStatus), message: errorOutput)
        }

        if output.isEmpty {
            throw VoicePasteError.whisperResponseParseError("Whisper returned empty output")
        }

        return output
    }
}
