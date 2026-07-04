import SwiftUI

struct SettingsView: View {
    // Hotkey
    @State private var hotkeyConfig = HotkeyManager.shared.currentConfig
    @State private var isRecordingHotkey = false

    // Groq — single key used for both STT and AI correction
    @State private var groqKey = ""
    @State private var groqMsg = ""

    private var sttProvider: STTProvider { STTRegistry.provider(id: "groq") }
    private var llmProvider: LLMProvider { LLMRegistry.provider(id: "groq") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Whisper Settings")
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

                    Text("Toggle mode: double-tap to start, single tap to stop (modifier keys like Fn) · Hold mode: press and hold to record")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .onChange(of: hotkeyConfig.keyCode) { _ in HotkeyManager.shared.updateConfig(hotkeyConfig) }
                .onChange(of: hotkeyConfig.modifiers) { _ in HotkeyManager.shared.updateConfig(hotkeyConfig) }

                Divider()

                // ── Groq (STT + AI correction) ──
                VStack(alignment: .leading, spacing: 8) {
                    Label("Groq API Key", systemImage: "key.fill")
                        .font(.subheadline).bold()

                    Text("Used for both transcription (\(sttProvider.defaultModel)) and AI correction (\(llmProvider.defaultModel))")
                        .font(.caption).foregroundColor(.secondary)

                    SecureField("gsk_…", text: $groqKey)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Save") { saveKey() }.buttonStyle(.borderedProminent)
                        Button("Test") { testKey() }
                        if !groqMsg.isEmpty { Text(groqMsg).font(.caption) }
                    }

                    Text("Get a free key at console.groq.com · Or set GROQ_API_KEY in ~/.zshrc to skip entering a key")
                        .font(.caption2).foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .frame(width: 460, height: 420)
        .onAppear { loadKey() }
    }

    // MARK: Groq key (shared by STT + LLM)
    private func loadKey() {
        groqKey = STTSettings.savedKeyFile(for: sttProvider)
        if groqKey.isEmpty {
            groqKey = (try? String(contentsOfFile: KeyStore.dir + "/llm_groq.key", encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    private func applyKey() {
        STTSettings.providerID = "groq"
        LLMSettings.providerID = "groq"
        let t = groqKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty {
            STTSettings.saveKey(t, for: sttProvider)
            LLMSettings.saveKey(t, for: llmProvider)
        }
    }

    private func saveKey() {
        applyKey()
        groqMsg = "✅ Saved"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { groqMsg = "" }
    }

    private func testKey() {
        applyKey()
        guard STTSettings.key(for: sttProvider) != nil else { groqMsg = "⚠️ Enter API key first"; return }

        groqMsg = "⏳ Testing…"
        guard let url = URL(string: "https://api.groq.com/openai/v1/models") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(STTSettings.key(for: sttProvider)!)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { _, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async {
                groqMsg = code == 200 ? "✅ Key is valid" : "❌ Invalid key (code \(code))"
            }
        }.resume()
    }
}
