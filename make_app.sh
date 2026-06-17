#!/bin/bash
# สร้าง WhisperApp.app bundle ที่ถูกต้อง (มี Info.plist + NSMicrophoneUsageDescription)
set -e
cd "$(dirname "$0")"

APP_NAME="WhisperApp"
APP_BUNDLE="$APP_NAME.app"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

echo "🔨 Building release..."
swift build -c release

echo "📦 Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# App icon
if [ -f "assets/Icon.icns" ]; then
    cp "assets/Icon.icns" "$APP_BUNDLE/Contents/Resources/Icon.icns"
    echo "🎨 เพิ่ม app icon"
fi

# Code signing:
# - ถ้ามี "Developer ID Application" → sign ด้วย cert นี้ (identity คงที่ สิทธิ์ TCC อยู่ข้าม rebuild)
# - ไม่งั้น fallback ad-hoc (สิทธิ์จะหายทุกครั้งที่ rebuild)
DEV_ID=$(security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep "Developer ID Application" | head -1 | sed -n 's/.*"\(.*\)".*/\1/p')

if [ -n "$DEV_ID" ]; then
    echo "✍️  Code signing ด้วย Developer ID: $DEV_ID"
    codesign --force --deep --options runtime \
        --entitlements WhisperApp.entitlements \
        --sign "$DEV_ID" "$APP_BUNDLE"
else
    echo "✍️  Code signing (ad-hoc) — แนะนำให้ติดตั้ง Developer ID cert เพื่อสิทธิ์คงที่"
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "✅ เสร็จ: $APP_BUNDLE"
echo "   เปิดด้วย: open $APP_BUNDLE"
