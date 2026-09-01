#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/../.." && pwd)"
version="${1:-1.4.0}"
output_dir="${2:-$repo_root/dist}"

case "$version" in
    *[!0-9A-Za-z.+:~-]*|"")
        echo "Invalid Debian package version: $version" >&2
        exit 1
        ;;
esac

command -v dpkg-deb >/dev/null 2>&1 || {
    echo "dpkg-deb is required to build the package." >&2
    exit 1
}

package_root="$(mktemp -d)"
trap 'rm -rf -- "$package_root"' EXIT
chmod 0755 "$package_root"

install -d \
    "$package_root/DEBIAN" \
    "$package_root/usr/bin" \
    "$package_root/usr/lib/tryvoha" \
    "$package_root/usr/share/applications" \
    "$package_root/usr/share/icons/hicolor/scalable/apps" \
    "$package_root/etc/xdg/autostart"

sed "s/@VERSION@/$version/g" \
    "$script_dir/control.in" > "$package_root/DEBIAN/control"

install -m 0755 "$repo_root/linux/tryvoha.py" \
    "$package_root/usr/lib/tryvoha/tryvoha.py"
install -m 0644 "$repo_root/linux/districts.json" \
    "$package_root/usr/lib/tryvoha/districts.json"
install -m 0644 "$repo_root/linux/tryvoha-normal.svg" \
    "$package_root/usr/lib/tryvoha/tryvoha-normal.svg"
install -m 0644 "$repo_root/linux/tryvoha-alert.svg" \
    "$package_root/usr/lib/tryvoha/tryvoha-alert.svg"

ln -s ../lib/tryvoha/tryvoha.py "$package_root/usr/bin/tryvoha"

install -m 0644 "$script_dir/tryvoha.desktop" \
    "$package_root/usr/share/applications/tryvoha.desktop"
install -m 0644 "$script_dir/tryvoha-autostart.desktop" \
    "$package_root/etc/xdg/autostart/tryvoha.desktop"
install -m 0644 "$repo_root/linux/tryvoha-normal.svg" \
    "$package_root/usr/share/icons/hicolor/scalable/apps/tryvoha-normal.svg"

mkdir -p "$output_dir"
package_path="$output_dir/tryvoha-desktop_${version}_all.deb"
dpkg-deb --root-owner-group --build "$package_root" "$package_path"

echo "$package_path"
