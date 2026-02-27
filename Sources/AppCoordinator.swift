import AppKit

class AppCoordinator {
    let statusBarController: StatusBarController
    let hotkeyManager: HotkeyManager
    let audioRecorder: AudioRecorder
    let whisperService: WhisperService
    let llmService: LLMService

    var lastPolishedText: String?
    private var appState: AppState = .idle

    init() {
        statusBarController = StatusBarController()
        hotkeyManager = HotkeyManager()
        audioRecorder = AudioRecorder()
        whisperService = WhisperService()
        llmService = LLMService()

        hotkeyManager.onKeyDown = { [weak self] in
            self?.handleKeyDown()
        }
        hotkeyManager.onKeyUp = { [weak self] in
            self?.handleKeyUp()
        }

        hotkeyManager.register()
    }

    func handleKeyDown() {
        guard appState == .idle else { return }
        appState = .recording
        statusBarController.setState(.recording)

        do {
            try audioRecorder.startRecording()
        } catch {
            print("[VoicePaste] Error starting recording: \(error.localizedDescription)")
            appState = .idle
            statusBarController.setState(.idle)
        }
    }

    func handleKeyUp() {
        guard appState == .recording else { return }

        let audioURL: URL
        do {
            audioURL = try audioRecorder.stopRecording()
        } catch {
            print("[VoicePaste] Error stopping recording: \(error.localizedDescription)")
            appState = .idle
            statusBarController.setState(.idle)
            return
        }

        // Start async pipeline
        appState = .processing
        statusBarController.setState(.processing)

        Task {
            await runPipeline(audioURL: audioURL)
        }
    }

    private func runPipeline(audioURL: URL) async {
        do {
            // Step 1: Whisper STT
            print("[VoicePaste] Transcribing audio...")
            let t0 = CFAbsoluteTimeGetCurrent()
            let transcription = try await whisperService.transcribe(audioURL: audioURL)
            let t1 = CFAbsoluteTimeGetCurrent()
            print("[VoicePaste] === Whisper 原始转写 (\(String(format: "%.1f", t1 - t0))s) ===")
            print(transcription)
            print("[VoicePaste] ========================")

            // Step 2: LLM polish
            print("[VoicePaste] Polishing text with LLM...")
            let polished = try await llmService.polish(text: transcription)
            let t2 = CFAbsoluteTimeGetCurrent()
            print("[VoicePaste] === LLM 润色结果 (\(String(format: "%.1f", t2 - t1))s) ===")
            print(polished)
            print("[VoicePaste] ========================")
            print("[VoicePaste] Total pipeline: \(String(format: "%.1f", t2 - t0))s")
            lastPolishedText = polished

            // Phase 4+ will add: clipboard + paste

            statusBarController.setState(.done)
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
            appState = .idle
            statusBarController.setState(.idle)

        } catch {
            print("[VoicePaste] Pipeline error: \(error.localizedDescription)")
            appState = .idle
            statusBarController.setState(.idle)
        }
    }
}
