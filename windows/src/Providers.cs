using System.Collections.Generic;
using System.Linq;

namespace WhisperWin
{
    public enum SttStyle { OpenAI, ElevenLabs }
    public enum LlmStyle { OpenAI, Anthropic }

    /// STT provider presets — mirrors STTProvider.swift
    public class SttProvider
    {
        public string Id;
        public string Name;
        public string DefaultEndpoint;
        public string DefaultModel;
        public string EnvKey;
        public SttStyle Style;
        public bool IsCustom;

        public override string ToString() { return Name; } // shown in settings combo box
    }

    /// LLM provider presets — mirrors LLMProvider.swift
    public class LlmProvider
    {
        public string Id;
        public string Name;
        public string DefaultEndpoint;
        public string DefaultModel;
        public string EnvKey;
        public LlmStyle Style;
        public bool IsCustom;

        public override string ToString() { return Name; } // shown in settings combo box
    }

    public static class SttRegistry
    {
        public static readonly List<SttProvider> All = new List<SttProvider>
        {
            new SttProvider { Id = "elevenlabs", Name = "ElevenLabs Scribe",
                DefaultEndpoint = "https://api.elevenlabs.io/v1/speech-to-text",
                DefaultModel = "scribe_v1", EnvKey = "ELEVENLABS_API_KEY", Style = SttStyle.ElevenLabs },
            new SttProvider { Id = "openai", Name = "OpenAI",
                DefaultEndpoint = "https://api.openai.com/v1/audio/transcriptions",
                DefaultModel = "gpt-4o-transcribe", EnvKey = "OPENAI_API_KEY", Style = SttStyle.OpenAI },
            new SttProvider { Id = "groq", Name = "Groq (Whisper)",
                DefaultEndpoint = "https://api.groq.com/openai/v1/audio/transcriptions",
                DefaultModel = "whisper-large-v3-turbo", EnvKey = "GROQ_API_KEY", Style = SttStyle.OpenAI },
            new SttProvider { Id = "stt_custom", Name = "Custom (OpenAI-compatible)",
                DefaultEndpoint = "", DefaultModel = "", EnvKey = "STT_API_KEY",
                Style = SttStyle.OpenAI, IsCustom = true },
        };

        public static SttProvider Get(string id)
        {
            return All.FirstOrDefault(p => p.Id == id) ?? All[0];
        }
    }

    public static class LlmRegistry
    {
        public static readonly List<LlmProvider> All = new List<LlmProvider>
        {
            new LlmProvider { Id = "deepseek", Name = "DeepSeek",
                DefaultEndpoint = "https://api.deepseek.com/chat/completions",
                DefaultModel = "deepseek-chat", EnvKey = "DEEPSEEK_API_KEY", Style = LlmStyle.OpenAI },
            new LlmProvider { Id = "openai", Name = "OpenAI",
                DefaultEndpoint = "https://api.openai.com/v1/chat/completions",
                DefaultModel = "gpt-4o-mini", EnvKey = "OPENAI_API_KEY", Style = LlmStyle.OpenAI },
            new LlmProvider { Id = "groq", Name = "Groq",
                DefaultEndpoint = "https://api.groq.com/openai/v1/chat/completions",
                DefaultModel = "llama-3.3-70b-versatile", EnvKey = "GROQ_API_KEY", Style = LlmStyle.OpenAI },
            new LlmProvider { Id = "openrouter", Name = "OpenRouter",
                DefaultEndpoint = "https://openrouter.ai/api/v1/chat/completions",
                DefaultModel = "google/gemini-2.0-flash-001", EnvKey = "OPENROUTER_API_KEY", Style = LlmStyle.OpenAI },
            new LlmProvider { Id = "gemini", Name = "Google Gemini",
                DefaultEndpoint = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
                DefaultModel = "gemini-2.0-flash", EnvKey = "GEMINI_API_KEY", Style = LlmStyle.OpenAI },
            new LlmProvider { Id = "anthropic", Name = "Anthropic (Claude)",
                DefaultEndpoint = "https://api.anthropic.com/v1/messages",
                DefaultModel = "claude-haiku-4-5", EnvKey = "ANTHROPIC_API_KEY", Style = LlmStyle.Anthropic },
            new LlmProvider { Id = "glm", Name = "GLM (Z.AI)",
                DefaultEndpoint = "https://api.z.ai/api/anthropic/v1/messages",
                DefaultModel = "glm-5.2", EnvKey = "ZAI_API_KEY", Style = LlmStyle.Anthropic },
            new LlmProvider { Id = "custom", Name = "Custom (OpenAI-compatible)",
                DefaultEndpoint = "", DefaultModel = "", EnvKey = "LLM_API_KEY",
                Style = LlmStyle.OpenAI, IsCustom = true },
        };

        public static LlmProvider Get(string id)
        {
            return All.FirstOrDefault(p => p.Id == id) ?? All[0];
        }
    }
}
