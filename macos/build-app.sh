#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
output_dir="${1:-$repo_root/dist-macos}"
app_dir="$output_dir/TrayVoha.app"
contents="$app_dir/Contents"
arm64_build="$script_dir/.build-universal-arm64"
x86_64_build="$script_dir/.build-universal-x86_64"

command -v swift >/dev/null 2>&1 || {
    echo "Для складання macOS-версії потрібен Swift toolchain." >&2
    exit 1
}
command -v plutil >/dev/null 2>&1 || {
    echo "Для складання macOS-версії потрібен plutil." >&2
    exit 1
}
command -v lipo >/dev/null 2>&1 || {
    echo "Для складання універсальної macOS-версії потрібен lipo." >&2
    exit 1
}

python3 "$repo_root/tools/generate-icon-assets.py"

rm -rf -- "$arm64_build" "$x86_64_build"
swift build \
    --package-path "$script_dir" \
    --scratch-path "$arm64_build" \
    -c release \
    --arch arm64
swift build \
    --package-path "$script_dir" \
    --scratch-path "$x86_64_build" \
    -c release \
    --arch x86_64

arm64_bin_dir="$(swift build --package-path "$script_dir" --scratch-path "$arm64_build" -c release --arch arm64 --show-bin-path)"
x86_64_bin_dir="$(swift build --package-path "$script_dir" --scratch-path "$x86_64_build" -c release --arch x86_64 --show-bin-path)"
arm64_binary="$arm64_bin_dir/TrayVohaMac"
x86_64_binary="$x86_64_bin_dir/TrayVohaMac"

test -s "$arm64_binary" || {
    echo "Не створено arm64 виконуваний файл TrayVohaMac." >&2
    exit 1
}
test -s "$x86_64_binary" || {
    echo "Не створено x86_64 виконуваний файл TrayVohaMac." >&2
    exit 1
}

test -s "$repo_root/assets/macos/trayvoha.icns" || {
    echo "Не створено macOS-іконку TrayVoha." >&2
    exit 1
}

rm -rf -- "$app_dir"
mkdir -p "$contents/MacOS" "$contents/Resources"
lipo -create "$arm64_binary" "$x86_64_binary" -output "$contents/MacOS/TrayVoha"
chmod 0755 "$contents/MacOS/TrayVoha"

architectures="$(lipo -archs "$contents/MacOS/TrayVoha")"
printf 'Архітектури TrayVoha: %s\n' "$architectures"
case " $architectures " in
    *" arm64 "*) ;;
    *) echo "Універсальна macOS-збірка не містить arm64." >&2; exit 1 ;;
esac
case " $architectures " in
    *" x86_64 "*) ;;
    *) echo "Універсальна macOS-збірка не містить x86_64." >&2; exit 1 ;;
esac

install -m 0644 "$repo_root/linux/districts.json" "$contents/Resources/districts.json"
install -m 0644 "$repo_root/assets/macos/trayvoha.icns" "$contents/Resources/trayvoha.icns"

cat > "$contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>uk</string>
    <key>CFBundleDisplayName</key>
    <string>TrayVoha</string>
    <key>CFBundleExecutable</key>
    <string>TrayVoha</string>
    <key>CFBundleIconFile</key>
    <string>trayvoha</string>
    <key>CFBundleIdentifier</key>
    <string>ua.yurkokuro.trayvoha</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>TrayVoha</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.5.0</string>
    <key>CFBundleVersion</key>
    <string>150</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$contents/Info.plist" >/dev/null

# Ad-hoc signature verifies bundle integrity in CI. Production distribution still needs Developer ID + notarization.
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"

mkdir -p "$output_dir"
rm -f -- "$output_dir/TrayVoha-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$output_dir/TrayVoha-macOS.zip"
test -s "$output_dir/TrayVoha-macOS.zip"

shasum -a 256 "$output_dir/TrayVoha-macOS.zip"
