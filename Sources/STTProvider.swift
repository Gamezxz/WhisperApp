import Foundation

/// Cloud Speech-to-Text providers — supports multiple providers
/// - elevenlabs: ElevenLabs Scribe (multipart, header xi-api-key, language ISO 639-3)
/// - openAI: OpenAI / Groq / custom (multipart, Bearer auth, language ISO 639-1)
struct STTProvider: Identifiable, Hashable {
    enum Style: String { case elevenlabs, openAI }

    let id: String
    let name: String
    let defaultEndpoint: String
    let defaultModel: String
    let envKey: String
    let style: Style
    let isCustom: Bool

    init(id: String, name: String, defaultEndpoint: String, defaultModel: String,
         envKey: String, style: Style, isCustom: Bool = false) {
        self.id = id; self.name = name
        self.defaultEndpoint = defaultEndpoint; self.defaultModel = defaultModel
        self.envKey = envKey; self.style = style; self.isCustom = isCustom
    }
}

enum STTRegistry {
    static let all: [STTProvider] = [
        STTProvider(id: "elevenlabs", name: "ElevenLabs Scribe",
                    defaultEndpoint: "https://api.elevenlabs.io/v1/speech-to-text",
                    defaultModel: "scribe_v1",
                    envKey: "ELEVENLABS_API_KEY", style: .elevenlabs),
        STTProvider(id: "openai", name: "OpenAI",
                    defaultEndpoint: "https://api.openai.com/v1/audio/transcriptions",
                    defaultModel: "gpt-4o-transcribe",
                    envKey: "OPENAI_API_KEY", style: .openAI),
        STTProvider(id: "groq", name: "Groq (Whisper)",
                    defaultEndpoint: "https://api.groq.com/openai/v1/audio/transcriptions",
                    defaultModel: "whisper-large-v3-turbo",
                    envKey: "GROQ_API_KEY", style: .openAI),
        STTProvider(id: "stt_custom", name: "Custom (OpenAI-compatible)",
                    defaultEndpoint: "",
                    defaultModel: "",
                    envKey: "STT_API_KEY", style: .openAI, isCustom: true),
    ]

    static func provider(id: String) -> STTProvider {
        all.first { $0.id == id } ?? all[0]
    }
}

/// Manages STT provider settings: selected provider + key/model/endpoint per provider (mirrors LLMSettings)
enum STTSettings {
    private static let defaults = UserDefaults.standard
    private static let providerKey = "stt.provider"

    static var providerID: String {
        get { defaults.string(forKey: providerKey) ?? "elevenlabs" }
        set { defaults.set(newValue, forKey: providerKey) }
    }

    static var current: STTProvider { STTRegistry.provider(id: providerID) }

    // MARK: key (file → env)
    private static func keyPath(_ p: STTProvider) -> String { KeyStore.dir + "/stt_\(p.id).key" }

    static func key(for p: STTProvider) -> String? {
        if let k = try? String(contentsOfFile: keyPath(p), encoding: .utf8) {
            let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        // backward-compat: ElevenLabs was previously stored at ~/.whisperapp/elevenlabs.key
        if p.id == "elevenlabs", let k = KeyStore.elevenLabsKey() { return k }
        return ShellEnv.value(p.envKey)
    }

    static func savedKeyFile(for p: STTProvider) -> String {
        // Key saved to file by user (shown in form — not pulling from env for display)
        if let k = try? String(contentsOfFile: keyPath(p), encoding: .utf8) {
            return k.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if p.id == "elevenlabs",
           let k = try? String(contentsOfFile: KeyStore.elevenPath, encoding: .utf8) {
            return k.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    static func saveKey(_ key: String, for p: STTProvider) {
        try? FileManager.default.createDirectory(atPath: KeyStore.dir, withIntermediateDirectories: true)
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        // ElevenLabs: also save to original file for backward-compat
        if p.id == "elevenlabs" { KeyStore.saveElevenLabsKey(t) }
        let path = keyPath(p)
        try? t.write(toFile: path, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }

    // MARK: model
    static func model(for p: STTProvider) -> String {
        let custom = defaults.string(forKey: "stt.model.\(p.id)")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let m = custom, !m.isEmpty { return m }
        return p.defaultModel
    }
    static func saveModel(_ m: String, for p: STTProvider) {
        defaults.set(m.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "stt.model.\(p.id)")
    }
    static func savedModel(for p: STTProvider) -> String {
        defaults.string(forKey: "stt.model.\(p.id)") ?? ""
    }

    // MARK: endpoint
    static func endpointString(for p: STTProvider) -> String {
        let custom = defaults.string(forKey: "stt.endpoint.\(p.id)")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let e = custom, !e.isEmpty { return e }
        return p.defaultEndpoint
    }
    static func endpoint(for p: STTProvider) -> URL? { URL(string: endpointString(for: p)) }
    static func saveEndpoint(_ e: String, for p: STTProvider) {
        defaults.set(e.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "stt.endpoint.\(p.id)")
    }
    static func savedEndpoint(for p: STTProvider) -> String {
        defaults.string(forKey: "stt.endpoint.\(p.id)") ?? ""
    }

    static func isConfigured(_ p: STTProvider) -> Bool {
        key(for: p) != nil && !endpointString(for: p).isEmpty
    }
}
