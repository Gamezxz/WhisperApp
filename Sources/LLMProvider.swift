import Foundation

/// LLM providers for text correction — supports multiple providers
/// Most providers use OpenAI-compatible API (chat/completions)
/// differing only in endpoint / model / key. Anthropic uses a separate style.
struct LLMProvider: Identifiable, Hashable {
    enum Style: String { case openAI, anthropic }

    let id: String
    let name: String
    let defaultEndpoint: String
    let defaultModel: String
    let envKey: String        // env var name to read key from zshrc
    let style: Style
    let isCustom: Bool

    init(id: String, name: String, defaultEndpoint: String, defaultModel: String,
         envKey: String, style: Style, isCustom: Bool = false) {
        self.id = id; self.name = name
        self.defaultEndpoint = defaultEndpoint; self.defaultModel = defaultModel
        self.envKey = envKey; self.style = style; self.isCustom = isCustom
    }
}

/// Supported provider presets — add more as needed
enum LLMRegistry {
    static let all: [LLMProvider] = [
        LLMProvider(id: "deepseek", name: "DeepSeek",
                    defaultEndpoint: "https://api.deepseek.com/chat/completions",
                    defaultModel: "deepseek-chat",
                    envKey: "DEEPSEEK_API_KEY", style: .openAI),
        LLMProvider(id: "openai", name: "OpenAI",
                    defaultEndpoint: "https://api.openai.com/v1/chat/completions",
                    defaultModel: "gpt-4o-mini",
                    envKey: "OPENAI_API_KEY", style: .openAI),
        LLMProvider(id: "groq", name: "Groq",
                    defaultEndpoint: "https://api.groq.com/openai/v1/chat/completions",
                    defaultModel: "llama-3.3-70b-versatile",
                    envKey: "GROQ_API_KEY", style: .openAI),
        LLMProvider(id: "openrouter", name: "OpenRouter",
                    defaultEndpoint: "https://openrouter.ai/api/v1/chat/completions",
                    defaultModel: "google/gemini-2.0-flash-001",
                    envKey: "OPENROUTER_API_KEY", style: .openAI),
        LLMProvider(id: "gemini", name: "Google Gemini",
                    defaultEndpoint: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
                    defaultModel: "gemini-2.0-flash",
                    envKey: "GEMINI_API_KEY", style: .openAI),
        LLMProvider(id: "anthropic", name: "Anthropic (Claude)",
                    defaultEndpoint: "https://api.anthropic.com/v1/messages",
                    defaultModel: "claude-haiku-4-5",
                    envKey: "ANTHROPIC_API_KEY", style: .anthropic),
        // Z.AI GLM via Anthropic-compatible endpoint (same as used with Claude Code)
        LLMProvider(id: "glm", name: "GLM (Z.AI)",
                    defaultEndpoint: "https://api.z.ai/api/anthropic/v1/messages",
                    defaultModel: "glm-5.2",
                    envKey: "ZAI_API_KEY", style: .anthropic),
        LLMProvider(id: "custom", name: "Custom (OpenAI-compatible)",
                    defaultEndpoint: "",
                    defaultModel: "",
                    envKey: "LLM_API_KEY", style: .openAI, isCustom: true),
    ]

    static func provider(id: String) -> LLMProvider {
        all.first { $0.id == id } ?? all[0]
    }
}

/// Manages provider settings: selected provider + key/model/endpoint per provider
/// - selected provider: UserDefaults
/// - key: file ~/.whisperapp/llm_<id>.key (chmod 600) → fallback to env var in zshrc
/// - model / endpoint: UserDefaults (if user overrides) → otherwise provider default
enum LLMSettings {
    private static let defaults = UserDefaults.standard
    private static let providerKey = "llm.provider"

    static var providerID: String {
        get { defaults.string(forKey: providerKey) ?? "deepseek" }
        set { defaults.set(newValue, forKey: providerKey) }
    }

    static var current: LLMProvider { LLMRegistry.provider(id: providerID) }

    // MARK: key (file → env)
    private static func keyPath(_ p: LLMProvider) -> String {
        KeyStore.dir + "/llm_\(p.id).key"
    }

    static func key(for p: LLMProvider) -> String? {
        if let k = try? String(contentsOfFile: keyPath(p), encoding: .utf8) {
            let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        // backward-compat: deepseek was previously stored at ~/.whisperapp/deepseek.key
        if p.id == "deepseek",
           let k = try? String(contentsOfFile: KeyStore.dir + "/deepseek.key", encoding: .utf8) {
            let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return ShellEnv.value(p.envKey)
    }

    static func saveKey(_ key: String, for p: LLMProvider) {
        try? FileManager.default.createDirectory(atPath: KeyStore.dir, withIntermediateDirectories: true)
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = keyPath(p)
        try? t.write(toFile: path, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }

    // MARK: model
    static func model(for p: LLMProvider) -> String {
        let custom = defaults.string(forKey: "llm.model.\(p.id)")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let m = custom, !m.isEmpty { return m }
        return p.defaultModel
    }

    static func saveModel(_ model: String, for p: LLMProvider) {
        defaults.set(model.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "llm.model.\(p.id)")
    }

    // MARK: endpoint
    static func endpoint(for p: LLMProvider) -> URL {
        let custom = defaults.string(forKey: "llm.endpoint.\(p.id)")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let e = custom, !e.isEmpty, let u = URL(string: e) { return u }

        // deepseek: still supports override from zshrc as before
        if p.id == "deepseek" { return KeyStore.deepseekEndpoint() }

        return URL(string: p.defaultEndpoint) ?? URL(string: "https://api.deepseek.com/chat/completions")!
    }

    static func saveEndpoint(_ endpoint: String, for p: LLMProvider) {
        defaults.set(endpoint.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "llm.endpoint.\(p.id)")
    }

    static func endpointString(for p: LLMProvider) -> String {
        let custom = defaults.string(forKey: "llm.endpoint.\(p.id)")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let e = custom, !e.isEmpty { return e }
        if p.id == "deepseek" { return KeyStore.deepseekEndpoint().absoluteString }
        return p.defaultEndpoint
    }

    static func isConfigured(_ p: LLMProvider) -> Bool {
        guard key(for: p) != nil else { return false }
        return !endpointString(for: p).isEmpty
    }
}
