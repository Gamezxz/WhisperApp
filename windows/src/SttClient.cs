using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading;
using System.Threading.Tasks;

namespace WhisperWin
{
    /// Cloud speech-to-text — multipart upload, mirrors CloudTranscriptionService.swift.
    /// OpenAI style: Bearer auth, fields model/language (ISO 639-1)
    /// ElevenLabs style: xi-api-key header, fields model_id/language_code (ISO 639-3)
    public static class SttClient
    {
        public static readonly HttpClient Http = CreateClient();

        private static HttpClient CreateClient()
        {
            var c = new HttpClient();
            c.Timeout = Timeout.InfiniteTimeSpan; // per-request timeouts via CancellationToken
            return c;
        }

        private static string LangCode(string language, SttStyle style)
        {
            if (language == "th") return style == SttStyle.ElevenLabs ? "tha" : "th";
            if (language == "en") return style == SttStyle.ElevenLabs ? "eng" : "en";
            return null; // auto → let the provider detect
        }

        /// Returns transcribed text, or throws with a readable message.
        public static async Task<string> TranscribeAsync(AppConfig cfg, string wavPath, string language)
        {
            var p = SttRegistry.Get(cfg.SttProvider);
            var key = cfg.SttKey(p);
            if (string.IsNullOrEmpty(key))
                throw new InvalidOperationException("ยังไม่ได้ตั้งค่า API key ของ " + p.Name);
            var endpoint = cfg.SttEndpoint(p);
            if (string.IsNullOrEmpty(endpoint))
                throw new InvalidOperationException("ยังไม่ได้ตั้งค่า endpoint ของ " + p.Name);

            byte[] audio = File.ReadAllBytes(wavPath);

            using (var form = new MultipartFormDataContent("Boundary-" + Guid.NewGuid().ToString("N")))
            using (var req = new HttpRequestMessage(HttpMethod.Post, endpoint))
            {
                string modelField = p.Style == SttStyle.ElevenLabs ? "model_id" : "model";
                string langField = p.Style == SttStyle.ElevenLabs ? "language_code" : "language";

                var model = cfg.SttModel(p);
                if (!string.IsNullOrEmpty(model))
                    form.Add(new StringContent(model), modelField);

                var lang = LangCode(language, p.Style);
                if (lang != null)
                    form.Add(new StringContent(lang), langField);

                var fileContent = new ByteArrayContent(audio);
                fileContent.Headers.ContentType = MediaTypeHeaderValue.Parse("audio/wav");
                form.Add(fileContent, "file", "audio.wav");

                if (p.Style == SttStyle.ElevenLabs)
                    req.Headers.TryAddWithoutValidation("xi-api-key", key);
                else
                    req.Headers.TryAddWithoutValidation("Authorization", "Bearer " + key);

                req.Content = form;

                using (var cts = new CancellationTokenSource(TimeSpan.FromSeconds(120)))
                using (var resp = await Http.SendAsync(req, cts.Token).ConfigureAwait(false))
                {
                    var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                    if (!resp.IsSuccessStatusCode)
                    {
                        Log.Error(p.Name + " HTTP " + (int)resp.StatusCode + ": " + Truncate(body, 500));
                        throw new InvalidOperationException(p.Name + " ตอบกลับ HTTP " + (int)resp.StatusCode);
                    }

                    var json = Json.ParseObject(body);
                    var text = Json.AsString(Json.Get(json, "text"));
                    if (text == null)
                    {
                        Log.Error(p.Name + " unexpected response: " + Truncate(body, 500));
                        throw new InvalidOperationException("อ่านผลลัพธ์จาก " + p.Name + " ไม่ได้");
                    }
                    return text.Trim();
                }
            }
        }

        public static string Truncate(string s, int n)
        {
            if (s == null) return "";
            return s.Length <= n ? s : s.Substring(0, n) + "…";
        }
    }
}
