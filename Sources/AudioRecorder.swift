import AVFoundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private let outputURL = URL(fileURLWithPath: "/tmp/voicepaste_recording.wav")
    private(set) var isRecording = false

    func startRecording() throws {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        // Record in mono at hardware sample rate to avoid realtime conversion issues
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: hardwareFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw VoicePasteError.audioRecordingFailed("Failed to create recording format")
        }

        audioFile = try AVAudioFile(forWriting: outputURL, settings: recordingFormat.settings)

        // Use recording format for the tap so AVAudioEngine handles conversion internally
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self, let file = self.audioFile else { return }
            try? file.write(from: buffer)
        }

        try engine.start()
        audioEngine = engine
        isRecording = true
        print("[VoicePaste] Recording started...")
    }

    func stopRecording() throws -> URL {
        guard isRecording else {
            throw VoicePasteError.audioRecordingFailed("Not currently recording")
        }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        isRecording = false

        // Verify file exists and has content
        let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let size = attrs[.size] as? UInt64 ?? 0
        guard size > 0 else {
            throw VoicePasteError.audioRecordingFailed("Recording file is empty")
        }

        print("[VoicePaste] Recording stopped. Saved to \(outputURL.path) (\(size) bytes)")
        return outputURL
    }
}
