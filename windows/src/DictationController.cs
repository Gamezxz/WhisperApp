using System;
using System.IO;
using System.Threading.Tasks;

namespace WhisperWin
{
    /// Orchestrates everything: record → transcribe (cloud/local) → correct (LLM) → paste.
    /// All public members must be called on the UI thread; async continuations return to it
    /// via the WinForms SynchronizationContext.
    public class DictationController
    {
        private readonly AppConfig _cfg;
        private readonly AudioRecorder _recorder = new AudioRecorder();
        private readonly Overlay _overlay;
        private readonly System.Windows.Forms.Timer _levelTimer;
        private bool _processing;
        private int _gen; // stage generation — cancels stale auto-idle resets

        public event Action<Stage> StageChanged;

        public bool IsRecording { get { return _recorder.IsRecording; } }

        public DictationController(AppConfig cfg, Overlay overlay)
        {
            _cfg = cfg;
            _overlay = overlay;
            _levelTimer = new System.Windows.Forms.Timer { Interval = 50 };
            _levelTimer.Tick += delegate { _overlay.Level = _recorder.Level; };
        }

        public void Toggle()
        {
            if (_recorder.IsRecording) StopAndProcess();
            else Start();
        }

        public void Start()
        {
            if (_processing || _recorder.IsRecording) return;

            if (_recorder.Start())
            {
                _levelTimer.Start();
                SetStage(Stage.Recording, "กำลังฟัง…");
            }
            else
            {
                SetStage(Stage.Error, "ไม่พบไมโครโฟน — เช็คการเชื่อมต่อ/สิทธิ์ไมค์");
                AutoIdle(2500);
            }
        }

        public void StopAndProcess()
        {
            if (!_recorder.IsRecording) return;
            _levelTimer.Stop();

            var seconds = _recorder.RecordedSeconds;
            var path = _recorder.Stop();

            if (path == null || seconds < 0.15)
            {
                if (path != null) TryDelete(path);
                SetStage(Stage.Idle, "");
                return;
            }

            Process(path);
        }

        private async void Process(string wavPath)
        {
            _processing = true;
            SetStage(Stage.Transcribing, _cfg.UseCloudStt ? "กำลังถอดเสียง…" : "กำลังถอดเสียง (เครื่องนี้)…");

            string raw = null;
            string error = null;
            try
            {
                if (_cfg.UseCloudStt)
                    raw = await SttClient.TranscribeAsync(_cfg, wavPath, _cfg.Language);
                else
                    raw = await LocalWhisper.TranscribeAsync(_cfg, wavPath, _cfg.Language);
            }
            catch (Exception ex)
            {
                error = ex is InvalidOperationException ? ex.Message : "เชื่อมต่อไม่สำเร็จ: " + ex.Message;
                Log.Error("STT: " + ex);
            }
            finally
            {
                TryDelete(wavPath);
            }

            if (error != null)
            {
                _processing = false;
                SetStage(Stage.Error, error);
                AutoIdle(3000);
                return;
            }

            var text = TextCleaner.StripSoundAnnotations(raw ?? "");
            if (string.IsNullOrWhiteSpace(text))
            {
                _processing = false;
                SetStage(Stage.Error, "ไม่ได้ยินเสียงพูด");
                AutoIdle(1800);
                return;
            }

            if (_cfg.UseCorrection && _cfg.LlmConfigured())
            {
                SetStage(Stage.Correcting, "AI กำลังเกลาข้อความ…");
                var corrected = await LlmClient.CorrectAsync(_cfg, text, _cfg.Language);
                if (corrected != null) text = corrected;
            }

            Paster.Paste(text); // on UI thread — clipboard needs STA

            var snippet = text.Length <= 28 ? text : text.Substring(0, 28) + "…";
            _processing = false;
            SetStage(Stage.Done, "✓ " + snippet);
            AutoIdle(1500);
        }

        private void SetStage(Stage stage, string text)
        {
            _gen++;
            _overlay.SetStage(stage, text);
            var cb = StageChanged;
            if (cb != null) cb(stage);
        }

        private async void AutoIdle(int ms)
        {
            int gen = _gen;
            await Task.Delay(ms);
            if (gen == _gen) SetStage(Stage.Idle, "");
        }

        private static void TryDelete(string path)
        {
            try { File.Delete(path); } catch { }
        }
    }
}
