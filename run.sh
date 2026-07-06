#!/bin/bash
# Build + ประกอบ .app bundle แล้วเปิด (วิธีนี้ระบบจะขอสิทธิ์ไมโครโฟนได้ถูกต้อง)
cd "$(dirname "$0")"
./make_app.sh && open Whisper.app
