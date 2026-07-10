using System;
using System.Collections.Generic;
using System.IO;
using System.Web.Script.Serialization;

namespace WhisperWin
{
    /// App settings persisted as JSON at %APPDATA%\WhisperApp\config.json
    /// API key resolution order matches macOS version: saved value → environment variable
    public class AppConfig
    {
        public string SttProvider = "groq";
        public Dictionary<string, string> SttKeys = new Dictionary<string, string>();
        public Dictionary<string, string> SttModels = new Dictionary<string, string>();
        public Dictionary<string, string> SttEndpoints = new Dictionary<string, string>();

        public string LlmProvider = "groq";
        public Dictionary<string, string> LlmKeys = new Dictionary<string, string>();
        public Dictionary<string, string> LlmModels = new Dictionary<string, string>();
        public Dictionary<string, string> LlmEndpoints = new Dictionary<string, string>();

        public string Language = "th";          // th | en | auto
        public bool UseCorrection = true;
        public bool UseCloudStt = true;

        public int HotkeyVk = 0x78;             // F9
        public bool HotkeyCtrl = false;
        public bool HotkeyAlt = false;
        public bool HotkeyShift = false;
        public bool HotkeyHoldMode = true;      // true = push-to-talk, false = toggle

        public string LocalWhisperExe = "";     // path to whisper-cli.exe (optional)
        public string LocalWhisperModelDir = ""; // dir containing ggml-*.bin (optional)

        // ---------- persistence ----------

        public static string Dir
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "WhisperApp"); }
        }

        public static string FilePath
        {
            get { return Path.Combine(Dir, "config.json"); }
        }

        public static AppConfig Load()
        {
            try
            {
                if (File.Exists(FilePath))
                {
                    var json = File.ReadAllText(FilePath);
                    var ser = new JavaScriptSerializer { MaxJsonLength = 8 * 1024 * 1024 };
                    var cfg = ser.Deserialize<AppConfig>(json);
                    if (cfg != null) { cfg.EnsureDicts(); return cfg; }
                }
            }
            catch (Exception ex) { Log.Error("Config load: " + ex.Message); }
            var fresh = new AppConfig();
            fresh.EnsureDicts();
            return fresh;
        }

        public void Save()
        {
            try
            {
                Directory.CreateDirectory(Dir);
                var ser = new JavaScriptSerializer { MaxJsonLength = 8 * 1024 * 1024 };
                File.WriteAllText(FilePath, ser.Serialize(this));
            }
            catch (Exception ex) { Log.Error("Config save: " + ex.Message); }
        }

        private void EnsureDicts()
        {
            if (SttKeys == null) SttKeys = new Dictionary<string, string>();
            if (SttModels == null) SttModels = new Dictionary<string, string>();
            if (SttEndpoints == null) SttEndpoints = new Dictionary<string, string>();
            if (LlmKeys == null) LlmKeys = new Dictionary<string, string>();
            if (LlmModels == null) LlmModels = new Dictionary<string, string>();
            if (LlmEndpoints == null) LlmEndpoints = new Dictionary<string, string>();
        }

        // ---------- resolution helpers (saved value → env var → default) ----------

        private static string FromDict(Dictionary<string, string> d, string key)
        {
            string v;
            if (d != null && d.TryGetValue(key, out v) && !string.IsNullOrWhiteSpace(v)) return v.Trim();
            return null;
        }

        public string SttKey(SttProvider p)
        {
            return FromDict(SttKeys, p.Id) ?? EnvOrNull(p.EnvKey);
        }

        public string SttModel(SttProvider p)
        {
            return FromDict(SttModels, p.Id) ?? p.DefaultModel;
        }

        public string SttEndpoint(SttProvider p)
        {
            return FromDict(SttEndpoints, p.Id) ?? p.DefaultEndpoint;
        }

        public string LlmKey(LlmProvider p)
        {
            return FromDict(LlmKeys, p.Id) ?? EnvOrNull(p.EnvKey);
        }

        public string LlmModel(LlmProvider p)
        {
            return FromDict(LlmModels, p.Id) ?? p.DefaultModel;
        }

        public string LlmEndpoint(LlmProvider p)
        {
            return FromDict(LlmEndpoints, p.Id) ?? p.DefaultEndpoint;
        }

        public bool SttConfigured()
        {
            var p = SttRegistry.Get(SttProvider);
            return !string.IsNullOrEmpty(SttKey(p)) && !string.IsNullOrEmpty(SttEndpoint(p));
        }

        public bool LlmConfigured()
        {
            var p = LlmRegistry.Get(LlmProvider);
            return !string.IsNullOrEmpty(LlmKey(p)) && !string.IsNullOrEmpty(LlmEndpoint(p));
        }

        private static string EnvOrNull(string name)
        {
            if (string.IsNullOrEmpty(name)) return null;
            var v = Environment.GetEnvironmentVariable(name);
            return string.IsNullOrWhiteSpace(v) ? null : v.Trim();
        }
    }

    /// Minimal file logger at %APPDATA%\WhisperApp\app.log
    public static class Log
    {
        private static readonly object Gate = new object();

        public static string LogPath
        {
            get { return Path.Combine(AppConfig.Dir, "app.log"); }
        }

        public static void Info(string msg) { WriteLine("INFO  " + msg); }
        public static void Error(string msg) { WriteLine("ERROR " + msg); }

        private static void WriteLine(string msg)
        {
            try
            {
                lock (Gate)
                {
                    Directory.CreateDirectory(AppConfig.Dir);
                    File.AppendAllText(LogPath,
                        DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  " + msg + Environment.NewLine);
                }
            }
            catch { }
        }
    }
}
