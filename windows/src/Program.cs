using System;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace WhisperWin
{
    public static class Program
    {
        [STAThread]
        public static void Main(string[] args)
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;

            if (args.Length > 0 && args[0] == "--selftest")
            {
                SelfTest.Run(args.Length > 1 ? args[1] : "selftest.txt");
                return;
            }

            bool createdNew;
            using (new Mutex(true, "WhisperAppWin-SingleInstance", out createdNew))
            {
                if (!createdNew)
                {
                    MessageBox.Show("WhisperApp เปิดอยู่แล้ว — ดูไอคอนไมโครโฟนที่ tray (มุมขวาล่าง)",
                        "WhisperApp", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }

                SetProcessDPIAware();
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.ThreadException += delegate(object s, ThreadExceptionEventArgs e)
                {
                    Log.Error("UI exception: " + e.Exception);
                };
                AppDomain.CurrentDomain.UnhandledException += delegate(object s, UnhandledExceptionEventArgs e)
                {
                    Log.Error("Fatal: " + e.ExceptionObject);
                };

                Application.Run(new TrayContext());
            }
        }

        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();
    }

    /// Headless smoke test (--selftest [outfile]) — verifies config round-trip and microphone capture
    /// without touching the network or the real config file.
    public static class SelfTest
    {
        public static void Run(string outPath)
        {
            var r = new StringBuilder();
            r.AppendLine("WhisperApp for Windows — self test");
            r.AppendLine("time: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
            r.AppendLine("64-bit process: " + Environment.Is64BitProcess);

            try
            {
                var cfg = new AppConfig();
                var json = Json.Serializer().Serialize(cfg);
                var back = Json.Serializer().Deserialize<AppConfig>(json);
                r.AppendLine("config json round-trip: " + (back != null && back.SttProvider == cfg.SttProvider ? "OK" : "FAIL"));
            }
            catch (Exception ex) { r.AppendLine("config json round-trip: FAIL — " + ex.Message); }

            r.AppendLine("stt providers: " + SttRegistry.All.Count + ", llm providers: " + LlmRegistry.All.Count);

            try
            {
                var rec = new AudioRecorder();
                if (rec.Start())
                {
                    Thread.Sleep(500);
                    var lvl = rec.Level;
                    var wav = rec.Stop();
                    if (wav != null)
                    {
                        var size = new FileInfo(wav).Length;
                        r.AppendLine("microphone: OK — recorded " + size + " bytes in 0.5s (level " + lvl.ToString("0.00") + ")");
                        r.AppendLine("wav header: " + (size > 44 ? "OK" : "FAIL (empty)"));
                        File.Delete(wav);
                    }
                    else r.AppendLine("microphone: opened but produced no data");
                }
                else r.AppendLine("microphone: NOT FOUND (waveInOpen failed) — ต่อไมค์หรือเช็คสิทธิ์ไมโครโฟน");
            }
            catch (Exception ex) { r.AppendLine("microphone: FAIL — " + ex.Message); }

            try
            {
                var cfg = new AppConfig();
                r.AppendLine("local whisper exe: " + (LocalWhisper.FindExe(cfg) ?? "(not installed — cloud only)"));
            }
            catch (Exception ex) { r.AppendLine("local whisper: " + ex.Message); }

            try { File.WriteAllText(outPath, r.ToString(), Encoding.UTF8); }
            catch { }
            Log.Info("selftest:\n" + r);
        }
    }
}
