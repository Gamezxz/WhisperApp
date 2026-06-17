import Foundation

/// Read env vars from login shell (source ~/.zshrc) — GUI apps launched via Finder
/// don't inherit env from terminal. Results are cached.
enum ShellEnv {
    private static var cache: [String: String] = [:]
    private static let lock = NSLock()

    static func value(_ name: String) -> String? {
        lock.lock(); let cached = cache[name]; lock.unlock()
        if let cached = cached { return cached.isEmpty ? nil : cached }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Use markers to prevent .zshrc banner output from polluting stdout
        task.arguments = ["-ic", "printf '<<%s>>' \"$\(name)\""]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        var result = ""
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let out = String(data: data, encoding: .utf8),
               let start = out.range(of: "<<"),
               let end = out.range(of: ">>", range: start.upperBound..<out.endIndex) {
                result = String(out[start.upperBound..<end.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("❌ ShellEnv(\(name)) error: \(error)")
        }

        lock.lock(); cache[name] = result; lock.unlock()
        return result.isEmpty ? nil : result
    }
}

/// Manages app API keys — ElevenLabs (user-entered/file), DeepSeek (from zshrc)
enum KeyStore {
    static var dir: String {
        FileManager.default.homeDirectoryForCurrentUser.path + "/.whisperapp"
    }
    static var elevenPath: String { dir + "/elevenlabs.key" }

    // MARK: ElevenLabs (user-entered → file → fallback zshrc)
    static func elevenLabsKey() -> String? {
        if let k = try? String(contentsOfFile: elevenPath, encoding: .utf8) {
            let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return ShellEnv.value("ELEVENLABS_API_KEY")
    }

    static func saveElevenLabsKey(_ key: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try? t.write(toFile: elevenPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: elevenPath)
    }

    // MARK: DeepSeek (reads both key and endpoint from zshrc)
    static func deepseekKey() -> String? {
        ShellEnv.value("DEEPSEEK_API_KEY")
            ?? (try? String(contentsOfFile: dir + "/deepseek.key", encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Endpoint from zshrc if set (supports both full endpoint and base url), otherwise default
    static func deepseekEndpoint() -> URL {
        for name in ["DEEPSEEK_ENDPOINT", "DEEPSEEK_API_ENDPOINT"] {
            if let v = ShellEnv.value(name), let u = URL(string: v) { return u }
        }
        for name in ["DEEPSEEK_API_BASE", "DEEPSEEK_BASE_URL"] {
            if var base = ShellEnv.value(name) {
                if base.hasSuffix("/") { base.removeLast() }
                if let u = URL(string: base + "/chat/completions") { return u }
            }
        }
        return URL(string: "https://api.deepseek.com/chat/completions")!
    }

    static func deepseekConfigured() -> Bool { deepseekKey() != nil }

    /// Called at app launch (background) to warm cache and avoid blocking main thread
    static func prewarm() {
        DispatchQueue.global(qos: .utility).async {
            _ = ShellEnv.value(LLMSettings.current.envKey)   // current LLM provider key
            _ = ShellEnv.value(STTSettings.current.envKey)   // current STT provider key
        }
    }
}
