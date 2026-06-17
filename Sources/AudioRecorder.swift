import AVFoundation
import Foundation

class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordedFileURL: URL?
    @Published var level: Float = 0   // 0...1 real-time audio level for waveform

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var converter: AVAudioConverter?
    private var tempFileURL: URL?

    // Whisper requires 16kHz mono
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    func startRecording() {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        // Use actual hardware format (never guess — tap would get silent buffers otherwise)
        let inputFormat = inputNode.inputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            print("❌ Invalid input format (sampleRate = 0) — microphone permission may not be granted")
            return
        }

        // converter: hardware format → 16kHz mono Int16
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            print("❌ Cannot create AVAudioConverter: \(inputFormat) → \(targetFormat)")
            return
        }
        self.converter = converter

        // Create temporary WAV file (write directly in 16kHz mono Int16 format)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_\(UUID().uuidString)")
            .appendingPathExtension("wav")
        tempFileURL = tempURL

        do {
            audioFile = try AVAudioFile(
                forWriting: tempURL,
                settings: targetFormat.settings,
                commonFormat: .pcmFormatInt16,
                interleaved: false
            )
        } catch {
            print("❌ Failed to create audio file: \(error)")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        do {
            try engine.start()
            audioEngine = engine
            isRecording = true
            print("✅ Recording started → \(tempURL.lastPathComponent) [in: \(inputFormat.sampleRate)Hz \(inputFormat.channelCount)ch]")
        } catch {
            print("❌ Failed to start engine: \(error)")
        }
    }

    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        converter = nil
        audioFile = nil
        isRecording = false
        DispatchQueue.main.async { self.level = 0 }

        if let url = tempFileURL {
            print("✅ Recording stopped → \(url.path)")
            DispatchQueue.main.async {
                self.recordedFileURL = url
            }
        }
        tempFileURL = nil
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        // Calculate audio level (RMS) for waveform display
        if let ch = buffer.floatChannelData {
            let n = Int(buffer.frameLength)
            if n > 0 {
                var sum: Float = 0
                let p = ch[0]
                for i in 0..<n { sum += p[i] * p[i] }
                let rms = (sum / Float(n)).squareRoot()
                let lvl = min(1, rms * 8)   // scale for visibility
                DispatchQueue.main.async { self.level = lvl }
            }
        }

        guard let converter = converter, let file = audioFile else { return }

        // Calculate output frame count based on sample rate ratio
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let outBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outFrameCapacity
        ) else { return }

        var fedInput = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if fedInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            fedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        var error: NSError?
        let status = converter.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)

        if status == .error {
            print("❌ Convert error: \(error?.localizedDescription ?? "unknown")")
            return
        }
        guard outBuffer.frameLength > 0 else { return }

        do {
            try file.write(from: outBuffer)
        } catch {
            print("❌ Write buffer error: \(error)")
        }
    }
}
