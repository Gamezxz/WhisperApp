#!/bin/bash
# สร้าง .dmg สำหรับติดตั้ง (drag app ไปที่ Applications)
# ทำความสะอาดก่อนทุกครั้ง + sign ด้วย Developer ID + ไม่มี key ใดๆ
set -e
cd "$(dirname "$0")"

APP_NAME="Whisper"
APP_BUNDLE="$APP_NAME.app"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null || echo "1.0")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "🔨 สร้าง release build + bundle ใหม่..."
./make_app.sh >/dev/null

# หา Developer ID
DEV_ID=$(security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep "Developer ID Application" | head -1 | sed -n 's/.*"\(.*\)".*/\1/p')

# Notarize + staple the .app itself (ไม่ใช่แค่ DMG)
# จำเป็นเพราะ: Sparkle แจก .zip ของ .app, และถ้า user แตก .app ออกจาก DMG,
# Gatekeeper บนเครื่องอื่นเช็ค .app โดยตรง — ถ้าไม่มี notarization ticket → บล็อก
NOTARY_PROFILE="whisperapp-notary"
if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "📤 Notarizing $APP_BUNDLE (อาจใช้เวลา 1-5 นาที)..."
    NOTARY_ZIP="/tmp/${APP_NAME}-notary.zip"
    ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"
    if xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait; then
        xcrun stapler staple "$APP_BUNDLE"
        echo "✅ $APP_BUNDLE notarized + stapled"
    else
        echo "⚠️  Notarize .app ไม่ผ่าน — ดู log: xcrun notarytool log <submission-id> --keychain-profile $NOTARY_PROFILE"
    fi
    rm -f "$NOTARY_ZIP"
else
    echo "⚠️  ข้าม notarize .app — ไม่มี credentials profile '$NOTARY_PROFILE'"
    echo "   สร้างครั้งเดียว: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <apple-id> --team-id DYJAX3728R"
fi

echo "📦 เตรียม staging สำหรับ DMG..."
STAGE=$(mktemp -d)
cp -R "$APP_BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# ใส่พื้นหลัง (ใช้ logo) ถ้ามี
mkdir -p "$STAGE/.background"
[ -f "assets/logo.png" ] && cp "assets/logo.png" "$STAGE/.background/background.png"

RW_DMG="/tmp/${APP_NAME}-rw.dmg"
rm -f "$RW_DMG" "$DMG_NAME"

echo "💽 สร้าง read-write DMG..."
hdiutil create -srcfolder "$STAGE" -fs HFS+ -volname "$APP_NAME" -format UDRW "$RW_DMG" >/dev/null

# mount เพื่อจัด layout หน้าต่าง
MOUNT_DIR="/tmp/${APP_NAME}_mnt"
rm -rf "$MOUNT_DIR"; mkdir -p "$MOUNT_DIR"
hdiutil attach "$RW_DMG" -readwrite -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null

echo "🎨 จัด layout หน้าต่าง (optional)..."
osascript <<APPLESCRIPT || echo "   (ข้าม layout — DMG ยังใช้ติดตั้งได้ปกติ)"
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 760, 440}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set position of item "$APP_NAME" of container window to {130, 140}
        set position of item "Applications" of container window to {430, 140}
        close without saving
    end tell
end tell
APPLESCRIPT

echo "🔒 ปิด mount + แปลงเป็น compressed read-only DMG..."
hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME" >/dev/null
rm -f "$RW_DMG"
rm -rf "$STAGE"

# sign DMG ด้วย Developer ID (ทำให้ Gatekeeper ไม่เตือน)
if [ -n "$DEV_ID" ]; then
    codesign --sign "$DEV_ID" --timestamp "$DMG_NAME" 2>/dev/null && echo "✍️  sign DMG ด้วย Developer ID"
fi

# Notarize + staple (ทำให้เครื่องอื่นเปิดได้โดยไม่มีคำเตือนความปลอดภัย)
# ต้องมี credentials profile ชื่อ "whisperapp-notary" (สร้างครั้งเดียวด้วย:
#   xcrun notarytool store-credentials "whisperapp-notary" --apple-id <apple-id> --team-id DYJAX3728R)
NOTARY_PROFILE="whisperapp-notary"
if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "📤 ส่ง notarize กับ Apple (อาจใช้เวลา 1-5 นาที)..."
    if xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait; then
        xcrun stapler staple "$DMG_NAME"
        echo "✅ Notarized + stapled — เปิดบนเครื่องอื่นได้โดยไม่มีคำเตือน"
    else
        echo "⚠️  Notarize ไม่ผ่าน — ดู log ด้วย: xcrun notarytool log <submission-id> --keychain-profile $NOTARY_PROFILE"
    fi
else
    echo "⚠️  ข้าม notarize — ยังไม่มี credentials profile '$NOTARY_PROFILE'"
    echo "   สร้างครั้งเดียว: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <apple-id> --team-id DYJAX3728R"
fi

echo ""
echo "✅ เสร็จ: $DMG_NAME"
ls -lh "$DMG_NAME"
