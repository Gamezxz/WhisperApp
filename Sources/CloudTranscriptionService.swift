import Foundation

/// Transcribe audio via cloud STT — supports multiple providers (ElevenLabs Scribe / OpenAI / Groq / Custom)
/// via STTSettings — see STTProvider.swift
class CloudTranscriptionService {
    private var provider: STTProvider { STTSettings.current }

    var isAvailable: Bool { STTSettings.key(for: provider) != nil }

    /// Convert app language → language code based on provider style
    /// - elevenlabs uses ISO 639-3 (tha/eng)  ·  openAI uses ISO 639-1 (th/en)
    /// - "auto" → nil (let the provider auto-detect)
    private func langCode(_ language: String, style: STTProvider.Style) -> String? {
        switch (language, style) {
        case ("th", .elevenlabs): return "tha"
        case ("en", .elevenlabs): return "eng"
        case ("th", .openAI):     return "th"
        case ("en", .openAI):     return "en"
        default:                  return nil
        }
    }

    func transcribe(fileURL: URL, language: String, completion: @escaping (String?) -> Void) {
        let p = provider
        guard let key = STTSettings.key(for: p) else {
            print("❌ No key found for \(p.name) (configure in Settings or set env \(p.envKey))")
            completion(nil); return
        }
        guard let endpoint = STTSettings.endpoint(for: p) else {
            print("❌ Invalid endpoint for \(p.name)")
            completion(nil); return
        }
        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(nil); return
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 120

        // Auth header + field names vary by style
        switch p.style {
        case .elevenlabs:
            req.setValue(key, forHTTPHeaderField: "xi-api-key")
        case .openAI:
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Field names differ: ElevenLabs = model_id/language_code, OpenAI-style = model/language
        let modelField = (p.style == .elevenlabs) ? "model_id" : "model"
        let langField  = (p.style == .elevenlabs) ? "language_code" : "language"

        field(modelField, STTSettings.model(for: p))
        if let lang = langCode(language, style: p.style) {
            field(langField, lang)
        }

        // Audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error {
                print("❌ \(p.name) error: \(error.localizedDescription)")
                completion(nil); return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil); return
            }
            // Both styles return { "text": "..." }
            if let text = json["text"] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                completion(trimmed.isEmpty ? nil : trimmed)
            } else {
                print("❌ \(p.name) response: \(json)")
                completion(nil)
            }
        }.resume()
    }
}
