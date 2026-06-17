import Foundation

class WhisperService: ObservableObject {
    @Published var language = "auto"
    @Published var statusMessage = ""

    private let whisperPath = "/opt/homebrew/opt/whisper-cpp/bin/whisper-cli"

    private var modelPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let modelDir = "\(home)/.whisper-models"

        if let files = try? FileManager.default.contentsOfDirectory(atPath: modelDir) {
            let bins = files.filter { $0.hasSuffix(".bin") }
            // Pick the best model by accuracy priority if multiple exist
            let priority = ["large-v3", "large", "medium", "small", "base", "tiny"]
            for key in priority {
                if let match = bins.first(where: { $0.contains(key) }) {
                    return "\(modelDir)/\(match)"
                }
            }
            if let first = bins.first {
                return "\(modelDir)/\(first)"
            }
        }

        return "\(modelDir)/ggml-base.bin"
    }

    func transcribe(fileURL: URL, completion: @escaping (String?) -> Void) {
        // Check model file exists
        guard FileManager.default.fileExists(atPath: modelPath) else {
            DispatchQueue.main.async {
                self.statusMessage = "❌ Model not found: \(self.modelPath)"
            }
            completion(nil)
            return
        }

        DispatchQueue.main.async {
            self.statusMessage = "🔄 Transcribing..."
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)

        // Note: --print-colors is a boolean flag — passing "0" makes whisper treat it
        // as an input file ("error: input file not found '0'"). Skipping it entirely.
        let args = [
            "-m", modelPath,
            "-f", fileURL.path,
            "-nt",                 // no timestamps
            "-l", language         // supports "auto" natively (whisper defaults to en if omitted)
        ]

        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        process.terminationHandler = { _ in
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            if let stderr = String(data: stderrData, encoding: .utf8), !stderr.isEmpty {
                print("📋 whisper stderr: \(stderr.prefix(500))")
            }

            if let output = String(data: stdoutData, encoding: .utf8) {
                // Strip ANSI escape codes in case whisper outputs color
                let cleaned = output.replacingOccurrences(
                    of: "\u{1b}\\[[0-9;]*m",
                    with: "",
                    options: .regularExpression
                )
                let trimmed = cleaned
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty && !$0.hasPrefix("[") }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                print("📋 whisper output: '\(trimmed)'")

                DispatchQueue.main.async {
                    self.statusMessage = trimmed.isEmpty ? "⚠️ No audio detected" : "✅ Done"
                    completion(trimmed.isEmpty ? nil : trimmed)
                }
            } else {
                DispatchQueue.main.async {
                    self.statusMessage = "❌ Could not read output"
                    completion(nil)
                }
            }

            // Remove temp file
            try? FileManager.default.removeItem(at: fileURL)
        }

        do {
            try process.run()
        } catch {
            print("❌ Failed to run whisper: \(error)")
            DispatchQueue.main.async {
                self.statusMessage = "❌ Error: \(error.localizedDescription)"
            }
            completion(nil)
        }
    }
}
