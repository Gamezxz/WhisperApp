using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace WhisperWin
{
    /// Global hotkey via a low-level keyboard hook (works in every app, supports
    /// hold/push-to-talk and toggle modes, and modifier keys like Right Ctrl as the hotkey).
    /// The hotkey press is swallowed so it never types into the focused app.
    public class HotkeyManager : IDisposable
    {
        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN = 0x0100;
        private const int WM_KEYUP = 0x0101;
        private const int WM_SYSKEYDOWN = 0x0104;
        private const int WM_SYSKEYUP = 0x0105;
        private const int LLKHF_INJECTED = 0x10;

        private IntPtr _hook = IntPtr.Zero;
        private readonly LowLevelKeyboardProc _proc; // kept alive so GC can't collect the delegate
        private bool _keyIsDown;

        public int Vk = 0x78;           // F9
        public bool Ctrl, Alt, Shift;
        public bool HoldMode = true;

        /// hold: fires on press → start; toggle: fires on press → flip
        public Action OnKeyDown;
        /// hold mode only: fires on release → stop
        public Action OnKeyUp;

        private static readonly HashSet<int> ModifierVks = new HashSet<int>
        {
            0xA0, 0xA1, // L/R Shift
            0xA2, 0xA3, // L/R Ctrl
            0xA4, 0xA5, // L/R Alt
            0x14,       // CapsLock (treated as standalone key)
        };

        public HotkeyManager()
        {
            _proc = HookCallback;
        }

        public void Install()
        {
            if (_hook != IntPtr.Zero) return;
            using (var cur = Process.GetCurrentProcess())
            using (var mod = cur.MainModule)
            {
                _hook = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(mod.ModuleName), 0);
            }
            if (_hook == IntPtr.Zero) Log.Error("SetWindowsHookEx failed: " + Marshal.GetLastWin32Error());
        }

        public void Uninstall()
        {
            if (_hook != IntPtr.Zero)
            {
                UnhookWindowsHookEx(_hook);
                _hook = IntPtr.Zero;
            }
            _keyIsDown = false;
        }

        public void Dispose() { Uninstall(); }

        public string DisplayString
        {
            get
            {
                var parts = new List<string>();
                if (Ctrl) parts.Add("Ctrl");
                if (Alt) parts.Add("Alt");
                if (Shift) parts.Add("Shift");
                parts.Add(KeyName(Vk));
                return string.Join("+", parts);
            }
        }

        public static string KeyName(int vk)
        {
            if (vk >= 0x70 && vk <= 0x7B) return "F" + (vk - 0x70 + 1);
            switch (vk)
            {
                case 0x14: return "CapsLock";
                case 0x91: return "ScrollLock";
                case 0x13: return "Pause";
                case 0x2D: return "Insert";
                case 0x24: return "Home";
                case 0x23: return "End";
                case 0x21: return "PageUp";
                case 0x22: return "PageDown";
                case 0x20: return "Space";
                case 0xA1: return "Right Shift";
                case 0xA3: return "Right Ctrl";
                case 0xA5: return "Right Alt";
                default: return ((Keys)vk).ToString();
            }
        }

        private static bool IsDown(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }

        private bool ModifiersMatch()
        {
            if (ModifierVks.Contains(Vk)) return true; // modifier-only hotkey → no extra mods required
            const int VK_CONTROL = 0x11, VK_MENU = 0x12, VK_SHIFT = 0x10;
            return IsDown(VK_CONTROL) == Ctrl && IsDown(VK_MENU) == Alt && IsDown(VK_SHIFT) == Shift;
        }

        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0)
            {
                var info = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
                bool injected = (info.flags & LLKHF_INJECTED) != 0;
                int msg = (int)wParam;

                if (!injected && (int)info.vkCode == Vk)
                {
                    if (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN)
                    {
                        if (_keyIsDown)
                            return (IntPtr)1; // swallow auto-repeat while held

                        if (ModifiersMatch())
                        {
                            _keyIsDown = true;
                            var cb = OnKeyDown;
                            if (cb != null) cb();
                            return (IntPtr)1; // swallow so the key never reaches the focused app
                        }
                    }
                    else if (msg == WM_KEYUP || msg == WM_SYSKEYUP)
                    {
                        if (_keyIsDown)
                        {
                            _keyIsDown = false;
                            if (HoldMode)
                            {
                                var cb = OnKeyUp;
                                if (cb != null) cb();
                            }
                            return (IntPtr)1;
                        }
                    }
                }
            }
            return CallNextHookEx(_hook, nCode, wParam, lParam);
        }

        // ---------- P/Invoke ----------

        private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        private struct KBDLLHOOKSTRUCT
        {
            public uint vkCode;
            public uint scanCode;
            public uint flags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll")]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll")]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int vKey);
    }
}
