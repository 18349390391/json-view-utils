#!/bin/bash
# JSON Editor 一键构建脚本：编译 release、生成图标、打包 .app
set -euo pipefail
cd "$(dirname "$0")"

echo "▶ 编译 (release)…"
swift build -c release

APP="JSONEditor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/JSONEditor "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# 中文本地化声明（使 AppKit 标准菜单/系统面板支持中文）
cp -R Resources/zh-Hans.lproj "$APP/Contents/Resources/zh-Hans.lproj"

echo "▶ 生成应用图标…"
TMPDIR_ICON="$(mktemp -d)"
ICON_1024="$TMPDIR_ICON/icon_1024.png"

# 用程序化渲染器生成（AppIcon.svg 的同源实现），保证圆角外透明、无白边
swift Resources/render_icon.swift "$ICON_1024"

ICONSET="$TMPDIR_ICON/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_1024" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ICON_1024" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp Resources/AppIcon.svg "$APP/Contents/Resources/AppIcon.svg"

echo "▶ 签名 (ad-hoc)…"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

# 刷新 LaunchServices 注册，避免 Finder 因缓存显示空白占位图标
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$(pwd)/$APP"
touch "$APP"

rm -rf "$TMPDIR_ICON"
echo "✅ 完成: $(pwd)/$APP"
echo "   双击即可打开；运行 ./JSONEditor.app/Contents/MacOS/JSONEditor --selftest 可执行核心自测"
