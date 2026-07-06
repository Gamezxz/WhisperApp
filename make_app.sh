#!/bin/bash
# สร้าง WhisperApp.app bundle ที่ถูกต้อง (มี Info.plist + NSMicrophoneUsageDescription)
set -e
cd "$(dirname "$0")"

APP_NAME="WhisperApp"          # SPM executable name (must match Package.swift target)
APP_BUNDLE="Whisper.app"       # name shown in /Applications
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

# Logo (for the About window)
if [ -f "assets/logo.png" ]; then
    cp "assets/logo.png" "$APP_BUNDLE/Contents/Resources/logo.png"
fi

# Embed Sparkle.framework (universal) for auto-update
SPARKLE_FW=$(find .build/artifacts -type d -name "Sparkle.framework" -path "*macos-arm64_x86_64*" 2>/dev/null | head -1)
if [ -n "$SPARKLE_FW" ]; then
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"
    rm -rf "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    cp -R "$SPARKLE_FW" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    # executable must find @rpath/Sparkle.framework → add rpath to ../Frameworks
    install_name_tool -add_rpath @loader_path/../Frameworks "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    echo "🪄 Embed Sparkle.framework"
else
    echo "⚠️  ไม่พบ Sparkle.framework — รัน 'swift build' ก่อน make_app.sh"
fi

# Code signing:
# - ถ้ามี "Developer ID Application" → sign ด้วย cert นี้ (identity คงที่ สิทธิ์ TCC อยู่ข้าม rebuild)
# - ไม่งั้น fallback ad-hoc (สิทธิ์จะหายทุกครั้งที่ rebuild)
DEV_ID=$(security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep "Developer ID Application" | head -1 | sed -n 's/.*"\(.*\)".*/\1/p')

if [ -n "$DEV_ID" ]; then
    # Sign nested Sparkle.framework ก่อน (ลำดับสำคัญ — nested ต้อง sign ก่อน bundle)
    if [ -d "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework" ]; then
        codesign --force --sign "$DEV_ID" --options runtime --timestamp \
            "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    fi
    echo "✍️  Code signing ด้วย Developer ID: $DEV_ID"
    codesign --force --options runtime --timestamp \
        --entitlements WhisperApp.entitlements \
        --sign "$DEV_ID" "$APP_BUNDLE"
else
    echo "✍️  Code signing (ad-hoc) — แนะนำให้ติดตั้ง Developer ID cert เพื่อสิทธิ์คงที่"
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "✅ เสร็จ: $APP_BUNDLE"
echo "   เปิดด้วย: open $APP_BUNDLE"
