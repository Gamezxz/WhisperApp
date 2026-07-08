using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace WhisperWin
{
    /// Offline STT via whisper.cpp (whisper-cli.exe) — mirrors WhisperService.swift.
    /// Exe: config path → %USERPROFILE%\.whisper-models\whisper-cli.exe → PATH
    /// Model: best .bin in %USERPROFILE%\.whisper-models (large-v3 > large > medium > small > base > tiny)
    public static class LocalWhisper
    {
        public static string DefaultModelDir
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".whisper-models"); }
        }

        public static string FindExe(AppConfig cfg)
        {
            if (!string.IsNullOrWhiteSpace(cfg.LocalWhisperExe) && File.Exists(cfg.LocalWhisperExe))
                return cfg.LocalWhisperExe;

            var inModels = Path.Combine(DefaultModelDir, "whisper-cli.exe");
            if (File.Exists(inModels)) return inModels;

            var paths = (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';');
            foreach (var dir in paths)
            {
                if (string.IsNullOrWhiteSpace(dir)) continue;
                try
                {
                    var candidate = Path.Combine(dir.Trim(), "whisper-cli.exe");
                    if (File.Exists(candidate)) return candidate;
                }
                catch { }
            }
            return null;
        }

        public static string FindModel(AppConfig cfg)
        {
            var dir = string.IsNullOrWhiteSpace(cfg.LocalWhisperModelDir) ? DefaultModelDir : cfg.LocalWhisperModelDir;
            if (!Directory.Exists(dir)) return null;
            var bins = Directory.GetFiles(dir, "*.bin");
            if (bins.Length == 0) return null;

            var priority = new[] { "large-v3", "large", "medium", "small", "base", "tiny" };
            foreach (var key in priority)
            {
                var match = bins.FirstOrDefault(b => Path.GetFileName(b).Contains(key));
                if (match != null) return match;
            }
            return bins[0];
        }

        public static Task<string> TranscribeAsync(AppConfig cfg, string wavPath, string language)
        {
            return Task.Run(() =>
            {
                var exe = FindExe(cfg);
                if (exe == null)
                    throw new InvalidOperationException("ไม่พบ whisper-cli.exe (ตั้งค่า path ใน Settings)");
                var model = FindModel(cfg);
                if (model == null)
                    throw new InvalidOperationException("ไม่พบไฟล์โมเดล ggml-*.bin ใน " + DefaultModelDir);

                var psi = new ProcessStartInfo
                {
                    FileName = exe,
                    Arguments = "-m \"" + model + "\" -f \"" + wavPath + "\" -nt -l " + language,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    StandardOutputEncoding = System.Text.Encoding.UTF8,
                };

                using (var proc = Process.Start(psi))
                {
                    var stdout = proc.StandardOutput.ReadToEnd();
                    var stderr = proc.StandardError.ReadToEnd();
                    proc.WaitForExit();

                    if (!string.IsNullOrWhiteSpace(stderr))
                        Log.Info("whisper stderr: " + SttClient.Truncate(stderr, 500));

                    // strip ANSI color codes (ESC[...m) in case whisper outputs color
                    var ansi = (char)27 + "\\[[0-9;]*m";
                    var cleaned = Regex.Replace(stdout, ansi, "");
                    var trimmed = string.Join(" ",
                            cleaned.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)
                                   .Where(l => !l.StartsWith("[")))
                        .Trim();
                    return trimmed.Length == 0 ? null : trimmed;
                }
            });
        }
    }
}
