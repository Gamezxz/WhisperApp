using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace WhisperWin
{
    public enum Stage { Idle, Recording, Transcribing, Correcting, Done, Error }

    /// Floating status pill at the bottom-center of the screen — never takes focus,
    /// shows current stage + a live waveform while recording (like the macOS overlay).
    public class Overlay : Form
    {
        private const int WS_EX_NOACTIVATE = 0x08000000;
        private const int WS_EX_TOOLWINDOW = 0x00000080;

        private Stage _stage = Stage.Idle;
        private string _text = "";
        private readonly float[] _bars = new float[28];
        private readonly Timer _anim;
        private readonly Font _font = new Font("Segoe UI", 10.5f, FontStyle.Regular);

        /// Live input level 0..1 — set by the controller while recording.
        public float Level { get; set; }

        public Overlay()
        {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            StartPosition = FormStartPosition.Manual;
            Size = new Size(360, 54);
            BackColor = Color.FromArgb(30, 30, 34);
            Opacity = 0.95;
            DoubleBuffered = true;

            _anim = new Timer { Interval = 50 };
            _anim.Tick += delegate
            {
                Array.Copy(_bars, 1, _bars, 0, _bars.Length - 1);
                _bars[_bars.Length - 1] = _stage == Stage.Recording ? Level : 0;
                Invalidate();
            };
        }

        protected override bool ShowWithoutActivation
        {
            get { return true; }
        }

        protected override CreateParams CreateParams
        {
            get
            {
                var cp = base.CreateParams;
                cp.ExStyle |= WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW;
                return cp;
            }
        }

        public void SetStage(Stage stage, string text)
        {
            _stage = stage;
            _text = text ?? "";

            if (stage == Stage.Idle)
            {
                _anim.Stop();
                Hide();
                return;
            }

            if (stage == Stage.Recording)
            {
                Array.Clear(_bars, 0, _bars.Length);
                _anim.Start();
            }
            else
            {
                _anim.Stop();
            }

            PositionBottomCenter();
            if (!Visible) Show();
            Invalidate();
        }

        private void PositionBottomCenter()
        {
            var wa = Screen.PrimaryScreen.WorkingArea;
            Location = new Point(wa.Left + (wa.Width - Width) / 2, wa.Bottom - Height - 28);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            using (var path = RoundedRect(new Rectangle(0, 0, Width, Height), 16))
                Region = new Region(path);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            Color accent;
            switch (_stage)
            {
                case Stage.Recording: accent = Color.FromArgb(255, 82, 82); break;
                case Stage.Transcribing: accent = Color.FromArgb(255, 170, 60); break;
                case Stage.Correcting: accent = Color.FromArgb(180, 130, 255); break;
                case Stage.Done: accent = Color.FromArgb(90, 210, 120); break;
                case Stage.Error: accent = Color.FromArgb(255, 100, 100); break;
                default: accent = Color.Gray; break;
            }

            // status dot
            using (var b = new SolidBrush(accent))
                g.FillEllipse(b, 16, Height / 2 - 5, 10, 10);

            // waveform (recording only) on the right side
            int barsRight = 18;
            int barsWidth = _stage == Stage.Recording ? 96 : 0;
            if (_stage == Stage.Recording)
            {
                int x0 = Width - barsRight - barsWidth;
                int mid = Height / 2;
                using (var b = new SolidBrush(Color.FromArgb(200, accent)))
                {
                    float step = barsWidth / (float)_bars.Length;
                    for (int i = 0; i < _bars.Length; i++)
                    {
                        float h = Math.Max(2f, _bars[i] * (Height - 22));
                        g.FillRectangle(b, x0 + i * step, mid - h / 2, Math.Max(1.5f, step - 1.5f), h);
                    }
                }
            }

            // status text
            var textRect = new RectangleF(34, 0, Width - 34 - barsRight - barsWidth - 6, Height);
            using (var sf = new StringFormat { LineAlignment = StringAlignment.Center, Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap })
            using (var tb = new SolidBrush(Color.FromArgb(240, 240, 245)))
                g.DrawString(_text, _font, tb, textRect, sf);
        }

        private static GraphicsPath RoundedRect(Rectangle r, int radius)
        {
            int d = radius * 2;
            var path = new GraphicsPath();
            path.AddArc(r.X, r.Y, d, d, 180, 90);
            path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                _anim.Dispose();
                _font.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
