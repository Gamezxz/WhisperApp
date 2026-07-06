#!/bin/bash
# Make a Sparkle release end-to-end:
#   DMG (for new installs) + signed .zip (for auto-update) + appcast item + GitHub release
#
# Usage: ./make_release.sh X.Y ["one-line release notes"]
#   e.g. ./make_release.sh 1.3 "Custom Dictionary, 16 languages, auto-update"
#
# Prereqs: EdDSA keypair already generated (generate_keys, once). sign_update pulls the
# private key from the macOS keychain automatically.
set -e
cd "$(dirname "$0")"

APP_NAME="Whisper"
APP_BUNDLE="$APP_NAME.app"
VERSION="${1:?usage: ./make_release.sh X.Y [\"release notes\"]}"
NOTES="${2:-Bug fixes and improvements.}"

SIGN_UPDATE=$(find .build/artifacts -type f -name sign_update -path "*bin*" 2>/dev/null | head -1)
if [ -z "$SIGN_UPDATE" ]; then
    echo "❌ ไม่พบ sign_update tool — รัน 'swift build' ก่อน (เพื่อ resolve Sparkle)"
    exit 1
fi

# 1. bump version
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" Info.plist

# 2. build + sign + notarize DMG (also rebuilds the .app bundle)
echo "🔨 Building + notarizing DMG…"
./make_dmg.sh >/dev/null

# 3. zip the .app for Sparkle (Whisper.app/ at archive root)
echo "📦 Zipping .app for Sparkle…"
rm -f "$APP_NAME-$VERSION.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$APP_NAME-$VERSION.zip"

# 4. EdDSA-sign the zip (private key from keychain)
echo "✍️  Signing update (EdDSA)…"
SIG_OUT=$("$SIGN_UPDATE" "$APP_NAME-$VERSION.zip")
EDSIG=$(echo "$SIG_OUT" | grep -o 'edSignature=[^ ]*' | cut -d= -f2)
LENGTH=$(echo "$SIG_OUT" | grep -o 'length=[0-9]*' | cut -d= -f2)
echo "   edSignature: $EDSIG"
echo "   length: $LENGTH"

# 5. insert a new <item> at the top of the appcast
echo "📝 Updating docs/appcast.xml…"
PUBDATE=$(LC_ALL=C date -R)
VERSION="$VERSION" PUBDATE="$PUBDATE" NOTES="$NOTES" EDSIG="$EDSIG" LENGTH="$LENGTH" \
python3 - <<'PY'
import os
v, pub, notes, sig, length = (os.environ[k] for k in
    ("VERSION", "PUBDATE", "NOTES", "EDSIG", "LENGTH"))
item = f'''    <item>
        <title>Version {v}</title>
        <pubDate>{pub}</pubDate>
        <sparkle:version>{v}</sparkle:version>
        <sparkle:shortVersionString>{v}</sparkle:shortVersionString>
        <description><![CDATA[{notes}]]></description>
        <enclosure url="https://github.com/Gamezxz/WhisperApp/releases/download/v{v}/Whisper-{v}.zip" type="application/octet-stream" sparkle:edSignature="{sig}" sparkle:length="{length}" />
    </item>'''
path = "docs/appcast.xml"
with open(path, encoding="utf-8") as f:
    txt = f.read()
marker = "<language>en</language>"
if marker not in txt:
    raise SystemExit("❌ ไม่พบ <language>en</language> ใน appcast.xml")
# avoid duplicate item for same version
if f"<sparkle:version>{v}</sparkle:version>" in txt:
    raise SystemExit(f"❌ version {v} มีอยู่แล้วใน appcast.xml")
txt = txt.replace(marker, marker + "\n" + item, 1)
with open(path, "w", encoding="utf-8") as f:
    f.write(txt)
print(f"   inserted item for v{v}")
PY

# 6. GitHub release with both artifacts
echo "🚀 Creating GitHub release v$VERSION…"
gh release create "v$VERSION" "$APP_NAME-$VERSION.dmg" "$APP_NAME-$VERSION.zip" \
    --title "Whisper $VERSION" --notes "$NOTES"

cat <<EOF

✅ Release v$VERSION สร้างแล้ว

⚠️  ทำต่อด้วยมือ (สำคัญ — ไม่งั้น auto-update หา zip ไม่เจอ / เว็บไม่อัปเดต):
   1. แก้ docs/changelog.html — เพิ่ม <article class="release latest"> สำหรับ v$VERSION (ย้าย badge Latest จาก entry เก่า)
   2. แก้ docs/index.html — ลิงก์ DMG + JSON-LD softwareVersion/downloadUrl → v$VERSION
   3. git add docs/appcast.xml docs/changelog.html docs/index.html && git commit + git push
      (GitHub Pages deploy — Sparkle อ่าน appcast จากนั้น)
EOF
