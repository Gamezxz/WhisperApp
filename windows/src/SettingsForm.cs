using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace WhisperWin
{
    /// Settings dialog — provider keys/models/endpoints, language, hotkey, autostart, local whisper.
    public class SettingsForm : Form
    {
        private readonly AppConfig _cfg;

        // working copies so Cancel discards edits
        private readonly Dictionary<string, string> _sttKeys, _sttModels, _sttEndpoints;
        private readonly Dictionary<string, string> _llmKeys, _llmModels, _llmEndpoints;
        private string _sttPrev, _llmPrev;

        private ComboBox _cboStt, _cboLlm, _cboLang, _cboKey;
        private TextBox _txtSttKey, _txtSttModel, _txtSttEndpoint;
        private TextBox _txtLlmKey, _txtLlmModel, _txtLlmEndpoint;
        private CheckBox _chkCorrection, _chkCtrl, _chkAlt, _chkShift, _chkAutostart, _chkLocal;
        private RadioButton _radHold, _radToggle;
        private TextBox _txtWhisperExe, _txtModelDir;

        public event Action Saved;

        private class KeyItem
        {
            public string Name; public int Vk;
            public override string ToString() { return Name; }
        }

        private static readonly KeyItem[] HotkeyChoices = BuildKeyChoices();

        private static KeyItem[] BuildKeyChoices()
        {
            var list = new List<KeyItem>();
            for (int i = 0; i < 12; i++)
                list.Add(new KeyItem { Name = "F" + (i + 1), Vk = 0x70 + i });
            list.Add(new KeyItem { Name = "CapsLock", Vk = 0x14 });
            list.Add(new KeyItem { Name = "ScrollLock", Vk = 0x91 });
            list.Add(new KeyItem { Name = "Pause", Vk = 0x13 });
            list.Add(new KeyItem { Name = "Insert", Vk = 0x2D });
            list.Add(new KeyItem { Name = "Home", Vk = 0x24 });
            list.Add(new KeyItem { Name = "End", Vk = 0x23 });
            list.Add(new KeyItem { Name = "PageUp", Vk = 0x21 });
            list.Add(new KeyItem { Name = "PageDown", Vk = 0x22 });
            list.Add(new KeyItem { Name = "Space", Vk = 0x20 });
            list.Add(new KeyItem { Name = "Right Ctrl", Vk = 0xA3 });
            list.Add(new KeyItem { Name = "Right Alt", Vk = 0xA5 });
            list.Add(new KeyItem { Name = "Right Shift", Vk = 0xA1 });
            return list.ToArray();
        }

        private static readonly HashSet<int> ModifierVks = new HashSet<int> { 0x14, 0xA1, 0xA3, 0xA5 };

        public SettingsForm(AppConfig cfg)
        {
            _cfg = cfg;
            _sttKeys = new Dictionary<string, string>(cfg.SttKeys);
            _sttModels = new Dictionary<string, string>(cfg.SttModels);
            _sttEndpoints = new Dictionary<string, string>(cfg.SttEndpoints);
            _llmKeys = new Dictionary<string, string>(cfg.LlmKeys);
            _llmModels = new Dictionary<string, string>(cfg.LlmModels);
            _llmEndpoints = new Dictionary<string, string>(cfg.LlmEndpoints);

            Text = "WhisperApp — ตั้งค่า";
            Font = new Font("Segoe UI", 9.5f);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(560, 716);

            BuildUi();
            LoadFromConfig();
        }

        // ---------- UI construction ----------

        private void BuildUi()
        {
            int y = 12;

            // --- STT group ---
            var gStt = AddGroup("ถอดเสียงเป็นข้อความ (Speech-to-Text)", y, 152);
            _cboStt = AddCombo(gStt, "ผู้ให้บริการ", 26, SttRegistry.All.Cast<object>().ToArray());
            _txtSttKey = AddText(gStt, "API key", 56, 400, true);
            _txtSttModel = AddText(gStt, "โมเดล", 86, 250, false);
            _txtSttEndpoint = AddText(gStt, "Endpoint", 116, 400, false);
            _cboStt.SelectedIndexChanged += delegate { OnSttProviderChanged(); };
            y += 152 + 10;

            // --- LLM group ---
            var gLlm = AddGroup("เกลาข้อความด้วย AI (แก้คำผิด เว้นวรรค ใส่วรรคตอน)", y, 182);
            _chkCorrection = AddCheck(gLlm, "เปิดใช้งาน — ส่งข้อความผ่าน LLM ก่อนพิมพ์", 26);
            _cboLlm = AddCombo(gLlm, "ผู้ให้บริการ", 56, LlmRegistry.All.Cast<object>().ToArray());
            _txtLlmKey = AddText(gLlm, "API key", 86, 400, true);
            _txtLlmModel = AddText(gLlm, "โมเดล", 116, 250, false);
            _txtLlmEndpoint = AddText(gLlm, "Endpoint", 146, 400, false);
            _cboLlm.SelectedIndexChanged += delegate { OnLlmProviderChanged(); };
            y += 182 + 10;

            // --- General group ---
            var gGen = AddGroup("ทั่วไป", y, 148);
            _cboLang = AddCombo(gGen, "ภาษาที่พูด", 26, new object[] { "ไทย", "English", "ตรวจอัตโนมัติ" });

            AddLabel(gGen, "ปุ่มลัด", 60);
            _cboKey = new ComboBox { Left = 130, Top = 56, Width = 110, DropDownStyle = ComboBoxStyle.DropDownList };
            _cboKey.Items.AddRange(HotkeyChoices.Cast<object>().ToArray());
            _cboKey.SelectedIndexChanged += delegate { UpdateModifierBoxes(); };
            gGen.Controls.Add(_cboKey);
            _chkCtrl = new CheckBox { Text = "Ctrl", Left = 250, Top = 57, Width = 55 };
            _chkAlt = new CheckBox { Text = "Alt", Left = 305, Top = 57, Width = 50 };
            _chkShift = new CheckBox { Text = "Shift", Left = 355, Top = 57, Width = 60 };
            gGen.Controls.AddRange(new Control[] { _chkCtrl, _chkAlt, _chkShift });

            _radHold = new RadioButton { Text = "กดค้างเพื่อพูด ปล่อยแล้วพิมพ์ (push-to-talk)", Left = 130, Top = 86, Width = 400, Checked = true };
            _radToggle = new RadioButton { Text = "กดครั้งแรกเริ่มอัด กดอีกครั้งหยุด", Left = 130, Top = 112, Width = 400 };
            gGen.Controls.AddRange(new Control[] { _radHold, _radToggle });
            y += 148 + 10;

            // --- Local whisper group ---
            var gLocal = AddGroup("Whisper ในเครื่อง (ออฟไลน์ — ไม่บังคับ)", y, 118);
            _chkLocal = AddCheck(gLocal, "ใช้ whisper.cpp ในเครื่องแทน cloud", 26);
            _txtWhisperExe = AddText(gLocal, "whisper-cli.exe", 56, 400, false);
            _txtModelDir = AddText(gLocal, "โฟลเดอร์โมเดล", 86, 400, false);
            y += 118 + 10;

            _chkAutostart = new CheckBox { Text = "เริ่มโปรแกรมอัตโนมัติเมื่อเปิดเครื่อง", Left = 22, Top = y, Width = 300 };
            Controls.Add(_chkAutostart);
            y += 34;

            var btnSave = new Button { Text = "บันทึก", Left = 356, Top = y, Width = 92, Height = 30 };
            var btnCancel = new Button { Text = "ยกเลิก", Left = 456, Top = y, Width = 92, Height = 30 };
            btnSave.Click += delegate { SaveAndClose(); };
            btnCancel.Click += delegate { Close(); };
            Controls.AddRange(new Control[] { btnSave, btnCancel });
            AcceptButton = btnSave;
            CancelButton = btnCancel;
        }

        private GroupBox AddGroup(string title, int y, int height)
        {
            var g = new GroupBox { Text = title, Left = 12, Top = y, Width = 536, Height = height };
            Controls.Add(g);
            return g;
        }

        private void AddLabel(GroupBox g, string text, int y)
        {
            g.Controls.Add(new Label { Text = text, Left = 14, Top = y, Width = 112, TextAlign = ContentAlignment.MiddleLeft });
        }

        private ComboBox AddCombo(GroupBox g, string label, int y, object[] items)
        {
            AddLabel(g, label, y + 4);
            var cbo = new ComboBox { Left = 130, Top = y, Width = 240, DropDownStyle = ComboBoxStyle.DropDownList };
            cbo.Items.AddRange(items);
            g.Controls.Add(cbo);
            return cbo;
        }

        private CheckBox AddCheck(GroupBox g, string text, int y)
        {
            var chk = new CheckBox { Text = text, Left = 130, Top = y, Width = 392 };
            g.Controls.Add(chk);
            return chk;
        }

        private TextBox AddText(GroupBox g, string label, int y, int width, bool password)
        {
            AddLabel(g, label, y + 3);
            var txt = new TextBox { Left = 130, Top = y, Width = width };
            if (password) txt.UseSystemPasswordChar = true;
            g.Controls.Add(txt);
            return txt;
        }

        // ---------- load / stash / save ----------

        private void LoadFromConfig()
        {
            _cboStt.SelectedIndex = Math.Max(0, SttRegistry.All.FindIndex(p => p.Id == _cfg.SttProvider));
            _sttPrev = CurrentStt().Id;
            LoadSttFields(CurrentStt());

            _chkCorrection.Checked = _cfg.UseCorrection;
            _cboLlm.SelectedIndex = Math.Max(0, LlmRegistry.All.FindIndex(p => p.Id == _cfg.LlmProvider));
            _llmPrev = CurrentLlm().Id;
            LoadLlmFields(CurrentLlm());

            _cboLang.SelectedIndex = _cfg.Language == "en" ? 1 : (_cfg.Language == "auto" ? 2 : 0);

            int keyIdx = Array.FindIndex(HotkeyChoices, k => k.Vk == _cfg.HotkeyVk);
            _cboKey.SelectedIndex = keyIdx >= 0 ? keyIdx : 8; // F9
            _chkCtrl.Checked = _cfg.HotkeyCtrl;
            _chkAlt.Checked = _cfg.HotkeyAlt;
            _chkShift.Checked = _cfg.HotkeyShift;
            _radHold.Checked = _cfg.HotkeyHoldMode;
            _radToggle.Checked = !_cfg.HotkeyHoldMode;
            UpdateModifierBoxes();

            _chkLocal.Checked = !_cfg.UseCloudStt;
            _txtWhisperExe.Text = _cfg.LocalWhisperExe ?? "";
            _txtModelDir.Text = _cfg.LocalWhisperModelDir ?? "";
            SetCue(_txtWhisperExe, "ค้นหาอัตโนมัติ (PATH หรือ %USERPROFILE%\\.whisper-models)");
            SetCue(_txtModelDir, LocalWhisper.DefaultModelDir);

            _chkAutostart.Checked = Autostart.IsEnabled();
        }

        private SttProvider CurrentStt() { return (SttProvider)_cboStt.SelectedItem; }
        private LlmProvider CurrentLlm() { return (LlmProvider)_cboLlm.SelectedItem; }

        private void OnSttProviderChanged()
        {
            StashStt(_sttPrev);
            var p = CurrentStt();
            _sttPrev = p.Id;
            LoadSttFields(p);
        }

        private void OnLlmProviderChanged()
        {
            StashLlm(_llmPrev);
            var p = CurrentLlm();
            _llmPrev = p.Id;
            LoadLlmFields(p);
        }

        private static string DictGet(Dictionary<string, string> d, string k)
        {
            string v;
            return d.TryGetValue(k, out v) ? v : "";
        }

        private static void DictSet(Dictionary<string, string> d, string k, string v)
        {
            if (string.IsNullOrWhiteSpace(v)) d.Remove(k);
            else d[k] = v.Trim();
        }

        private void LoadSttFields(SttProvider p)
        {
            _txtSttKey.Text = DictGet(_sttKeys, p.Id);
            _txtSttModel.Text = DictGet(_sttModels, p.Id);
            _txtSttEndpoint.Text = DictGet(_sttEndpoints, p.Id);
            SetCue(_txtSttKey, EnvHint(p.EnvKey));
            SetCue(_txtSttModel, p.DefaultModel);
            SetCue(_txtSttEndpoint, p.DefaultEndpoint);
        }

        private void LoadLlmFields(LlmProvider p)
        {
            _txtLlmKey.Text = DictGet(_llmKeys, p.Id);
            _txtLlmModel.Text = DictGet(_llmModels, p.Id);
            _txtLlmEndpoint.Text = DictGet(_llmEndpoints, p.Id);
            SetCue(_txtLlmKey, EnvHint(p.EnvKey));
            SetCue(_txtLlmModel, p.DefaultModel);
            SetCue(_txtLlmEndpoint, p.DefaultEndpoint);
        }

        private static string EnvHint(string envKey)
        {
            var v = Environment.GetEnvironmentVariable(envKey);
            return string.IsNullOrWhiteSpace(v)
                ? "วางคีย์ที่นี่ (หรือตั้ง env " + envKey + ")"
                : "ใช้จาก env " + envKey + " (ใส่เพื่อ override)";
        }

        private void StashStt(string id)
        {
            if (id == null) return;
            DictSet(_sttKeys, id, _txtSttKey.Text);
            DictSet(_sttModels, id, _txtSttModel.Text);
            DictSet(_sttEndpoints, id, _txtSttEndpoint.Text);
        }

        private void StashLlm(string id)
        {
            if (id == null) return;
            DictSet(_llmKeys, id, _txtLlmKey.Text);
            DictSet(_llmModels, id, _txtLlmModel.Text);
            DictSet(_llmEndpoints, id, _txtLlmEndpoint.Text);
        }

        private void UpdateModifierBoxes()
        {
            var item = (KeyItem)_cboKey.SelectedItem;
            bool isModifier = item != null && ModifierVks.Contains(item.Vk);
            _chkCtrl.Enabled = _chkAlt.Enabled = _chkShift.Enabled = !isModifier;
            if (isModifier) _chkCtrl.Checked = _chkAlt.Checked = _chkShift.Checked = false;
        }

        private void SaveAndClose()
        {
            StashStt(CurrentStt().Id);
            StashLlm(CurrentLlm().Id);

            _cfg.SttProvider = CurrentStt().Id;
            _cfg.SttKeys.Clear(); foreach (var kv in _sttKeys) _cfg.SttKeys[kv.Key] = kv.Value;
            _cfg.SttModels.Clear(); foreach (var kv in _sttModels) _cfg.SttModels[kv.Key] = kv.Value;
            _cfg.SttEndpoints.Clear(); foreach (var kv in _sttEndpoints) _cfg.SttEndpoints[kv.Key] = kv.Value;

            _cfg.UseCorrection = _chkCorrection.Checked;
            _cfg.LlmProvider = CurrentLlm().Id;
            _cfg.LlmKeys.Clear(); foreach (var kv in _llmKeys) _cfg.LlmKeys[kv.Key] = kv.Value;
            _cfg.LlmModels.Clear(); foreach (var kv in _llmModels) _cfg.LlmModels[kv.Key] = kv.Value;
            _cfg.LlmEndpoints.Clear(); foreach (var kv in _llmEndpoints) _cfg.LlmEndpoints[kv.Key] = kv.Value;

            _cfg.Language = _cboLang.SelectedIndex == 1 ? "en" : (_cboLang.SelectedIndex == 2 ? "auto" : "th");

            var key = (KeyItem)_cboKey.SelectedItem;
            if (key != null) _cfg.HotkeyVk = key.Vk;
            _cfg.HotkeyCtrl = _chkCtrl.Checked;
            _cfg.HotkeyAlt = _chkAlt.Checked;
            _cfg.HotkeyShift = _chkShift.Checked;
            _cfg.HotkeyHoldMode = _radHold.Checked;

            _cfg.UseCloudStt = !_chkLocal.Checked;
            _cfg.LocalWhisperExe = _txtWhisperExe.Text.Trim();
            _cfg.LocalWhisperModelDir = _txtModelDir.Text.Trim();

            _cfg.Save();
            Autostart.Set(_chkAutostart.Checked);

            var cb = Saved;
            if (cb != null) cb();
            Close();
        }

        // ---------- cue banner (placeholder text) ----------

        private const int EM_SETCUEBANNER = 0x1501;

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);

        private static void SetCue(TextBox txt, string text)
        {
            SendMessage(txt.Handle, EM_SETCUEBANNER, (IntPtr)1, text ?? "");
        }
    }
}
