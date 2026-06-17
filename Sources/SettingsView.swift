import SwiftUI

struct SettingsView: View {
    // Hotkey
    @State private var hotkeyConfig = HotkeyManager.shared.currentConfig
    @State private var isRecordingHotkey = false

    // STT (multi-provider — transcription)
    @State private var sttProviderID = STTSettings.providerID
    @State private var sttKey = ""
    @State private var sttModel = ""
    @State private var sttEndpoint = ""
    @State private var sttMsg = ""
    private var sttProvider: STTProvider { STTRegistry.provider(id: sttProviderID) }

    // LLM (multi-provider — text correction)
    @State private var providerID = LLMSettings.providerID
    @State private var llmKey = ""
    @State private var llmModel = ""
    @State private var llmEndpoint = ""
    @State private var llmMsg = ""
    private var provider: LLMProvider { LLMRegistry.provider(id: providerID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("WhisperApp Settings")
                    .font(.title3).bold()

                // ── Hotkey ──
                VStack(alignment: .leading, spacing: 8) {
                    Label("Global Hotkey", systemImage: "keyboard")
                        .font(.subheadline).bold()

                    HStack(spacing: 12) {
                        Text("Shortcut:").font(.caption)
                        HotkeyRecorderView(hotkey: $hotkeyConfig, isRecording: $isRecordingHotkey)
                            .frame(width: 180, height: 30)
                        Button(isRecordingHotkey ? "Listening…" : "Change") {
                            isRecordingHotkey.toggle()
                        }
                        .disabled(isRecordingHotkey)
                        Button("Reset") {
                            hotkeyConfig = .default
                            HotkeyManager.shared.updateConfig(hotkeyConfig)
                        }
                    }

                    Toggle("Hold to talk (press & hold to record, release to stop)", isOn: $hotkeyConfig.isHoldMode)
                        .font(.caption)
                        .onChange(of: hotkeyConfig.isHoldMode) { _ in
                            HotkeyManager.shared.updateConfig(hotkeyConfig)
                        }

                    Text("Toggle mode: press to start, press again to stop · Hold mode: press and hold to record")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .onChange(of: hotkeyConfig.keyCode) { _ in HotkeyManager.shared.updateConfig(hotkeyConfig) }
                .onChange(of: hotkeyConfig.modifiers) { _ in HotkeyManager.shared.updateConfig(hotkeyConfig) }

                Divider()

                // ── STT (transcription) ──
                VStack(alignment: .leading, spacing: 8) {
                    Label("Cloud STT (choose provider)", systemImage: "waveform")
                        .font(.subheadline).bold()

                    Picker("Provider", selection: $sttProviderID) {
                        ForEach(STTRegistry.all) { p in Text(p.name).tag(p.id) }
                    }
                    .onChange(of: sttProviderID) { _ in loadSTT() }

                    Text("API Key").font(.caption).foregroundColor(.secondary)
                    SecureField("\(sttProvider.name) API key…", text: $sttKey)
                        .textFieldStyle(.roundedBorder)

                    Text("Model").font(.caption).foregroundColor(.secondary)
                    TextField(sttProvider.defaultModel.isEmpty ? "Model name…" : sttProvider.defaultModel,
                              text: $sttModel)
                        .textFieldStyle(.roundedBorder)

                    Text("Endpoint").font(.caption).foregroundColor(.secondary)
                    TextField(sttProvider.defaultEndpoint.isEmpty ? "https://…" : sttProvider.defaultEndpoint,
                              text: $sttEndpoint)
                        .textFieldStyle(.roundedBorder).font(.caption)

                    HStack {
                        Button("Save") { saveSTT() }.buttonStyle(.borderedProminent)
                        Button("Test") { testSTT() }
                        if !sttMsg.isEmpty { Text(sttMsg).font(.caption) }
                    }
                    Text("Leave Model/Endpoint blank to use defaults · Set env var (\(sttProvider.envKey)) in ~/.zshrc to skip entering a key")
                        .font(.caption2).foregroundColor(.secondary)
                }

                Divider()

                // ── LLM (text correction) ──
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI Correction (choose provider)", systemImage: "sparkles")
                        .font(.subheadline).bold()

                    Picker("Provider", selection: $providerID) {
                        ForEach(LLMRegistry.all) { p in Text(p.name).tag(p.id) }
                    }
                    .onChange(of: providerID) { _ in loadLLM() }

                    Text("API Key").font(.caption).foregroundColor(.secondary)
                    SecureField("\(provider.name) API key…", text: $llmKey)
                        .textFieldStyle(.roundedBorder)

                    Text("Model").font(.caption).foregroundColor(.secondary)
                    TextField(provider.defaultModel.isEmpty ? "Model name…" : provider.defaultModel,
                              text: $llmModel)
                        .textFieldStyle(.roundedBorder)

                    Text("Endpoint").font(.caption).foregroundColor(.secondary)
                    TextField(provider.defaultEndpoint.isEmpty ? "https://…" : provider.defaultEndpoint,
                              text: $llmEndpoint)
                        .textFieldStyle(.roundedBorder).font(.caption)

                    HStack {
                        Button("Save") { saveLLM() }.buttonStyle(.borderedProminent)
                        Button("Test") { testLLM() }
                        if !llmMsg.isEmpty { Text(llmMsg).font(.caption) }
                    }
                    Text("Leave Model/Endpoint blank to use defaults · Set env var (\(provider.envKey)) in ~/.zshrc to skip entering a key")
                        .font(.caption2).foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .frame(width: 460, height: 760)
        .onAppear { loadSTT(); loadLLM() }
    }

    // MARK: STT
    private func loadSTT() {
        let p = sttProvider
        sttKey = STTSettings.savedKeyFile(for: p)
        sttModel = STTSettings.savedModel(for: p)
        sttEndpoint = STTSettings.savedEndpoint(for: p)
    }

    private func saveSTT() {
        let p = sttProvider
        STTSettings.providerID = sttProviderID
        if !sttKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            STTSettings.saveKey(sttKey, for: p)
        }
        STTSettings.saveModel(sttModel, for: p)
        STTSettings.saveEndpoint(sttEndpoint, for: p)
        sttMsg = "✅ Saved (\(p.name))"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { sttMsg = "" }
    }

    private func testSTT() {
        let p = sttProvider
        STTSettings.providerID = sttProviderID
        if !sttKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            STTSettings.saveKey(sttKey, for: p)
        }
        STTSettings.saveModel(sttModel, for: p)
        STTSettings.saveEndpoint(sttEndpoint, for: p)

        guard STTSettings.key(for: p) != nil else { sttMsg = "⚠️ Enter API key first"; return }
        guard !STTSettings.endpointString(for: p).isEmpty else { sttMsg = "⚠️ Enter endpoint first"; return }

        sttMsg = "⏳ Testing…"
        // Test without audio: GET request based on style (ElevenLabs = subscription, others = models list)
        let style = p.style
        if style == .elevenlabs, let url = URL(string: "https://api.elevenlabs.io/v1/user/subscription") {
            var req = URLRequest(url: url)
            req.setValue(STTSettings.key(for: p), forHTTPHeaderField: "xi-api-key")
            URLSession.shared.dataTask(with: req) { _, resp, _ in
                let ok = (resp as? HTTPURLResponse)?.statusCode == 200
                DispatchQueue.main.async { sttMsg = ok ? "✅ Key is valid" : "❌ Invalid key" }
            }.resume()
        } else {
            // OpenAI-style: GET {base}/models to check auth (base = endpoint minus /transcriptions)
            let base = STTSettings.endpointString(for: p)
                .replacingOccurrences(of: "/transcriptions", with: "/models")
            guard let url = URL(string: base) else { sttMsg = "❌ Invalid endpoint"; return }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(STTSettings.key(for: p)!)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: req) { _, resp, _ in
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                let ok = code == 200
                DispatchQueue.main.async { sttMsg = ok ? "✅ Key is valid" : "❌ Request failed (code \(code))" }
            }.resume()
        }
    }

    // MARK: LLM
    private func loadLLM() {
        let p = provider
        llmKey = (try? String(contentsOfFile: KeyStore.dir + "/llm_\(p.id).key", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        llmModel = UserDefaults.standard.string(forKey: "llm.model.\(p.id)") ?? ""
        llmEndpoint = UserDefaults.standard.string(forKey: "llm.endpoint.\(p.id)") ?? ""
    }

    private func saveLLM() {
        let p = provider
        LLMSettings.providerID = providerID
        if !llmKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            LLMSettings.saveKey(llmKey, for: p)
        }
        LLMSettings.saveModel(llmModel, for: p)
        LLMSettings.saveEndpoint(llmEndpoint, for: p)
        llmMsg = "✅ Saved (\(p.name))"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { llmMsg = "" }
    }

    private func testLLM() {
        let p = provider
        LLMSettings.providerID = providerID
        if !llmKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            LLMSettings.saveKey(llmKey, for: p)
        }
        LLMSettings.saveModel(llmModel, for: p)
        LLMSettings.saveEndpoint(llmEndpoint, for: p)

        guard LLMSettings.key(for: p) != nil else { llmMsg = "⚠️ Enter API key first"; return }
        guard !LLMSettings.endpointString(for: p).isEmpty else { llmMsg = "⚠️ Enter endpoint first"; return }

        llmMsg = "⏳ Testing…"
        let svc = TextCorrectionService()
        svc.correct(text: "Hello this is a test", language: "en") { result in
            DispatchQueue.main.async {
                llmMsg = (result != nil) ? "✅ Working" : "❌ Failed (check key/model/endpoint)"
            }
        }
    }
}
