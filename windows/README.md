# WhisperApp for Windows

พอร์ตของ [WhisperApp](https://github.com/Gamezxz/WhisperApp) (macOS) มาเป็นแอป Windows แบบ system tray —
**กดปุ่มลัดค้างแล้วพูด ปล่อยปุ่ม ข้อความจะพิมพ์ลงแอปที่ใช้อยู่ให้อัตโนมัติ** (สไตล์ Wispr Flow)

พูด → ถอดเสียง (Groq / OpenAI / ElevenLabs / whisper.cpp ในเครื่อง) → AI เกลาข้อความ (แก้คำผิด เว้นวรรค วรรคตอน) → วางลงแอปที่โฟกัสอยู่ผ่าน Ctrl+V

## เริ่มใช้งาน

1. ดับเบิลคลิก `run.bat` (build อัตโนมัติครั้งแรก แล้วเปิดแอปเป็นไอคอนไมค์ที่ tray)
2. ครั้งแรกหน้าตั้งค่าจะเปิดเอง → ใส่ API key
   - แนะนำ **Groq** (ฟรี, เร็ว): คีย์เดียวใช้ได้ทั้งถอดเสียง + เกลาข้อความ — สมัครที่ console.groq.com
3. เปิดแอปไหนก็ได้ คลิกช่องพิมพ์ → **กด F9 ค้างไว้ พูด แล้วปล่อย** → ข้อความพิมพ์ให้เอง

> ถ้า auto-paste ไม่ทำงาน ข้อความจะอยู่ใน clipboard เสมอ — กด Ctrl+V เองได้เลย

## ปุ่มลัด

- ค่าเริ่มต้น: **กด F9 ค้างเพื่อพูด** (push-to-talk) — ปล่อยแล้วเริ่มถอดเสียงทันที
- เปลี่ยนปุ่ม (F1–F12, CapsLock, Right Ctrl, Space ฯลฯ + Ctrl/Alt/Shift) และสลับเป็นโหมด
  กดครั้งแรกเริ่ม/กดอีกครั้งหยุด ได้ในหน้าตั้งค่า
- ปุ่มลัดถูก "กลืน" ไว้ ไม่พิมพ์ลงแอปที่ใช้งานอยู่

## ผู้ให้บริการที่รองรับ (เหมือนเวอร์ชัน macOS)

| | ตัวเลือก |
|---|---|
| ถอดเสียง (STT) | Groq Whisper (ค่าเริ่มต้น) · OpenAI · ElevenLabs Scribe · endpoint ใดๆ ที่เข้ากับ OpenAI · whisper.cpp ในเครื่อง (ออฟไลน์) |
| เกลาข้อความ (LLM) | Groq (ค่าเริ่มต้น) · DeepSeek · OpenAI · OpenRouter · Gemini · Anthropic Claude · GLM (Z.AI) · custom |

API key ใส่ในหน้าตั้งค่า หรือใช้จาก environment variable เดิมก็ได้ (`GROQ_API_KEY`, `OPENAI_API_KEY`,
`ELEVENLABS_API_KEY`, `DEEPSEEK_API_KEY`, `ANTHROPIC_API_KEY`, …) — ค่าที่ใส่ในแอปจะ override env

การตั้งค่าทั้งหมดเก็บที่ `%APPDATA%\WhisperApp\config.json` (log อยู่ที่ `app.log` ข้างกัน)

## whisper.cpp ในเครื่อง (ออฟไลน์ — ไม่บังคับ)

1. โหลด whisper.cpp binary ของ Windows (`whisper-cli.exe`) วางที่ `%USERPROFILE%\.whisper-models\` (หรือใน PATH)
2. โหลดโมเดล `ggml-*.bin` ใส่โฟลเดอร์เดียวกัน (แอปเลือกตัวที่แม่นสุดให้เอง: large-v3 > medium > … > tiny)
3. ติ๊ก "ใช้ whisper.cpp ในเครื่องแทน cloud" ในหน้าตั้งค่า

## การ build

ไม่ต้องติดตั้งอะไรเพิ่ม — ใช้ .NET Framework 4.8 ที่มากับ Windows 10/11 และคอมไพเลอร์ Roslyn
จาก VS 2019 Build Tools (fallback เป็น csc ของ .NET Framework):

```bat
build.bat        รี่คอมไพล์ → WhisperApp.exe (ไฟล์เดียว ไม่มี dependency)
run.bat          build ถ้ายังไม่มี exe แล้วเปิดแอป
WhisperApp.exe --selftest [out.txt]   ทดสอบไมค์/config แบบไม่มี UI
```

เปิดติดเครื่องอัตโนมัติ: ติ๊ก "เริ่มพร้อม Windows" ในหน้าตั้งค่าหรือเมนู tray (เขียน HKCU Run key)

## แก้ปัญหา

- **ไม่พบไมโครโฟน** — เช็คสาย/เลือก default input ใน Sound settings และ Settings > Privacy > Microphone
  ต้องเปิด "Let desktop apps access your microphone"
- **paste ไม่ลงแอปที่รันแบบ Administrator** — Windows บล็อกการส่งคีย์ข้ามระดับสิทธิ์
  ให้รัน WhisperApp แบบ admin ด้วย หรือกด Ctrl+V เอง (ข้อความอยู่ใน clipboard แล้ว)
- **ถอดเสียงช้า/error** — ดู `%APPDATA%\WhisperApp\app.log` (เมนู tray → เปิดโฟลเดอร์ข้อมูล)

## ต่างจากเวอร์ชัน macOS ตรงไหน

- ปุ่มลัดเริ่มต้นเป็น **F9** (Windows ไม่เปิดปุ่ม Fn ให้แอปอ่านเหมือน macOS)
- โหมด toggle ไม่ต้องเคาะ 2 ครั้งตอนเริ่ม (ปุ่มลัดถูกกลืน ไม่รบกวนแอปอื่น จึงไม่จำเป็น)
- ไม่ต้องขอสิทธิ์ Accessibility — Windows ให้จำลอง Ctrl+V ได้เลย
