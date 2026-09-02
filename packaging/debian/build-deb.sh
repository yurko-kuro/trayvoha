#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/../.." && pwd)"
version="${1:-1.5.0}"
output_dir="${2:-$repo_root/dist}"

case "$version" in
    *[!0-9A-Za-z.+:~-]*|"")
        echo "Некоректна версія Debian-пакета: $version" >&2
        exit 1
        ;;
esac

command -v dpkg-deb >/dev/null 2>&1 || {
    echo "Для складання пакета потрібна команда dpkg-deb." >&2
    exit 1
}

package_root="$(mktemp -d)"
trap 'rm -rf -- "$package_root"' EXIT
chmod 0755 "$package_root"

install -d \
    "$package_root/DEBIAN" \
    "$package_root/usr/bin" \
    "$package_root/usr/lib/trayvoha" \
    "$package_root/usr/share/applications" \
    "$package_root/usr/share/icons/hicolor/scalable/apps" \
    "$package_root/etc/xdg/autostart"

sed "s/@VERSION@/$version/g" \
    "$script_dir/control.in" > "$package_root/DEBIAN/control"

install -m 0755 "$repo_root/linux/trayvoha.py" \
    "$package_root/usr/lib/trayvoha/trayvoha.py"
install -m 0644 "$repo_root/linux/trayvoha_app.py" \
    "$package_root/usr/lib/trayvoha/trayvoha_app.py"
install -m 0644 "$repo_root/linux/districts.json" \
    "$package_root/usr/lib/trayvoha/districts.json"
install -m 0644 "$repo_root/linux/trayvoha.svg" \
    "$package_root/usr/lib/trayvoha/trayvoha.svg"
install -m 0644 "$repo_root/linux/trayvoha-normal.svg" \
    "$package_root/usr/lib/trayvoha/trayvoha-normal.svg"
install -m 0644 "$repo_root/linux/trayvoha-alert.svg" \
    "$package_root/usr/lib/trayvoha/trayvoha-alert.svg"
install -m 0644 "$repo_root/linux/trayvoha-unknown.svg" \
    "$package_root/usr/lib/trayvoha/trayvoha-unknown.svg"

ln -s ../lib/trayvoha/trayvoha.py "$package_root/usr/bin/trayvoha"

install -m 0644 "$script_dir/trayvoha.desktop" \
    "$package_root/usr/share/applications/trayvoha.desktop"
install -m 0644 "$script_dir/trayvoha-autostart.desktop" \
    "$package_root/etc/xdg/autostart/trayvoha.desktop"
install -m 0644 "$repo_root/linux/trayvoha.svg" \
    "$package_root/usr/share/icons/hicolor/scalable/apps/trayvoha.svg"

mkdir -p "$output_dir"
package_path="$output_dir/trayvoha_${version}_all.deb"
dpkg-deb --root-owner-group --build "$package_root" "$package_path"

echo "$package_path"
