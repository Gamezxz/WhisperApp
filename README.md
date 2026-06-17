# WhisperApp

A macOS menu-bar speech-to-text dictation app — press a hotkey, speak, and the corrected text is pasted into whatever you're typing. Think Wispr Flow, built on open STT/LLM APIs you control.

![WhisperApp](assets/logo.png)

## Features

- 🎙️ **Global hotkey** (toggle or hold-to-talk) — configurable, including the Fn key alone
- ☁️ **Multi-provider STT** — ElevenLabs Scribe, OpenAI, Groq (Whisper), or any OpenAI-compatible endpoint
- 🖥️ **Local STT** — whisper.cpp (large-v3) fallback, fully offline
- ✨ **AI text correction** — DeepSeek, OpenAI, Groq, Gemini, Anthropic, GLM (Z.AI), or custom — fixes garbled words & adds punctuation
- 📋 **Auto-paste** into the focused app (simulates ⌘V)
- 🌊 Live waveform + status overlay (recording → transcribing → fixing → done)
- 🔒 Keys stored locally (`~/.whisperapp/*.key` or shell env), never bundled or shipped

## Requirements

- macOS 13+
- **Permissions:** Microphone + Accessibility (for auto-paste)
- Optional: `whisper.cpp` (Homebrew) for local STT

## Install

1. Download `WhisperApp-x.x.x.dmg` from [Releases](../../releases)
2. Drag **WhisperApp** to **Applications**
3. Open it — a mic icon appears in the menu bar
4. **System Settings → Privacy & Security:**
   - enable **Microphone**
   - enable **Accessibility** (for auto-paste)
5. Click the mic icon → **Settings…** → add your STT + LLM API keys
6. Press the hotkey (default `⌃⌥Space`) and speak

## Configure keys

Keys are read from (in order): the Settings UI (saved to `~/.whisperapp/`) → shell env (`~/.zshrc`).

```sh
# optional: put keys in ~/.zshrc instead of the Settings UI
export ELEVENLABS_API_KEY="..."
export DEEPSEEK_API_KEY="..."
export ZAI_API_KEY="..."          # for GLM (Z.AI) via Anthropic-compatible endpoint
```

## Build from source

```bash
git clone <this-repo>
cd WhisperApp
./make_app.sh        # build + sign + assemble .app
./make_dmg.sh        # build distributable .dmg
```

For a stable signature (so macOS remembers permissions across rebuilds), sign
with your own **Developer ID Application** certificate — `make_app.sh` auto-detects it.

## Architecture

- SwiftUI menu-bar app (`LSUIElement`), Carbon/`NSEvent` global hotkey
- `AVAudioEngine` → 16 kHz mono Int16 WAV recording
- Cloud STT via multipart upload (ElevenLabs `model_id`/`language_code` or OpenAI-style `model`/`language`)
- LLM correction via OpenAI-compatible **or** Anthropic-compatible request styles
- Floating `NSPanel` + SwiftUI status overlay

## License

MIT
