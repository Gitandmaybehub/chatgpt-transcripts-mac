#!/bin/zsh
# Builds Transcripts.app into ~/Applications and starts it.
set -e
cd "$(dirname "$0")"
APP=~/Applications/Transcripts.app
B=build; rm -rf $B; mkdir -p $B/icon.iconset
swiftc make_icon.swift -o $B/make_icon && $B/make_icon $B/icon.png
for s in 16 32 128 256 512; do
  sips -z $s $s $B/icon.png --out $B/icon.iconset/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) $B/icon.png --out $B/icon.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $B/icon.iconset -o $B/AppIcon.icns
swiftc -O -parse-as-library main.swift -o $B/Transcripts
pkill -x Transcripts || true
rm -rf $APP; mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp $B/Transcripts $APP/Contents/MacOS/; cp $B/AppIcon.icns $APP/Contents/Resources/
cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Transcripts</string>
<key>CFBundleDisplayName</key><string>Transcripts</string>
<key>CFBundleIdentifier</key><string>com.christiangiangrande.transcripts</string>
<key>CFBundleExecutable</key><string>Transcripts</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --deep -s - $APP
open $APP
echo "built $APP"
