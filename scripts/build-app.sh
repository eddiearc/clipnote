#!/bin/bash
# 在真实 Mac 上把 SwiftPM 可执行文件打成 Clipnote.app。
# 用法：scripts/build-app.sh [debug|release]
# Linux / CI 无法链接 EventKit，请不要在非 macOS 上运行本脚本。
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Clipnote must be built on macOS. EventKit is not available here." >&2
  exit 1
fi

CONFIG="${1:-release}"
APP="build/Clipnote.app"
VERSION="0.1.0"

echo "Building Clipnote ($CONFIG)…"
swift build -c "$CONFIG" --product Clipnote
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Clipnote"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Clipnote"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist" >/dev/null

IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/{print $2; exit}')" || true
fi

if [ -n "$IDENTITY" ]; then
  codesign --force --options runtime --timestamp --entitlements Resources/Clipnote.entitlements --sign "$IDENTITY" "$APP"
  echo "Signed with $IDENTITY"
else
  # 本地开发：ad hoc 签名并带上 Reminders 权限。沙盒应用必须是 bundle。
  codesign --force --deep --entitlements Resources/Clipnote.entitlements --sign - "$APP"
  echo "Signed ad hoc (no Developer ID found)"
fi

echo "Built $APP"
echo "Open it with: open $APP"
echo "Grant Reminders access when prompted, or use System Settings → Privacy & Security → Reminders."
