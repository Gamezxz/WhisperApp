using System;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace WhisperWin
{
    /// Copies text to the clipboard and simulates Ctrl+V into the focused app.
    /// The text stays in the clipboard afterwards, so if auto-paste fails the user can Ctrl+V manually
    /// (same behavior as the macOS version).
    public static class Paster
    {
        /// Must be called from the UI (STA) thread.
        public static async void Paste(string text)
        {
            try
            {
                Clipboard.SetDataObject(text, true, 5, 100);
            }
            catch (Exception ex)
            {
                Log.Error("Clipboard: " + ex.Message);
                return;
            }

            await Task.Delay(60); // let the clipboard settle before the keystroke (macOS uses 50 ms)

            try
            {
                SendCtrlV();
            }
            catch (Exception ex)
            {
                Log.Error("SendInput: " + ex.Message);
            }
        }

        private static void SendCtrlV()
        {
            const ushort VK_CONTROL = 0x11;
            const ushort VK_V = 0x56;
            const uint KEYEVENTF_KEYUP = 0x0002;

            var inputs = new INPUT[4];
            inputs[0] = KeyInput(VK_CONTROL, 0);
            inputs[1] = KeyInput(VK_V, 0);
            inputs[2] = KeyInput(VK_V, KEYEVENTF_KEYUP);
            inputs[3] = KeyInput(VK_CONTROL, KEYEVENTF_KEYUP);

            uint sent = SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(INPUT)));
            if (sent != inputs.Length)
                Log.Error("SendInput sent " + sent + "/4: " + Marshal.GetLastWin32Error());
        }

        private static INPUT KeyInput(ushort vk, uint flags)
        {
            return new INPUT
            {
                type = 1, // INPUT_KEYBOARD
                U = new InputUnion
                {
                    ki = new KEYBDINPUT { wVk = vk, wScan = 0, dwFlags = flags, time = 0, dwExtraInfo = IntPtr.Zero }
                }
            };
        }

        // ---------- P/Invoke ----------

        [StructLayout(LayoutKind.Sequential)]
        private struct INPUT
        {
            public uint type;
            public InputUnion U;
        }

        [StructLayout(LayoutKind.Explicit)]
        private struct InputUnion
        {
            [FieldOffset(0)] public MOUSEINPUT mi;
            [FieldOffset(0)] public KEYBDINPUT ki;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MOUSEINPUT
        {
            public int dx, dy;
            public uint mouseData, dwFlags, time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct KEYBDINPUT
        {
            public ushort wVk, wScan;
            public uint dwFlags, time;
            public IntPtr dwExtraInfo;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    }
}
