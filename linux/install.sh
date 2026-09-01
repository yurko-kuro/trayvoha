#!/usr/bin/env bash

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
install_dir="$data_home/alerttray"
bin_dir="$HOME/.local/bin"
applications_dir="$data_home/applications"

missing=""
command -v python3 >/dev/null 2>&1 || missing="$missing python3"
command -v notify-send >/dev/null 2>&1 || missing="$missing libnotify-bin"

if ! python3 -c 'import gi; gi.require_version("Gtk", "3.0")' >/dev/null 2>&1; then
    missing="$missing python3-gi gir1.2-gtk-3.0"
fi

if ! python3 -c 'import gi; gi.require_version("AyatanaAppIndicator3", "0.1")' >/dev/null 2>&1; then
    missing="$missing gir1.2-ayatanaappindicator3-0.1"
fi

if [ -n "$missing" ]; then
    echo "Install required packages first:"
    echo "sudo apt update && sudo apt install$missing"
    exit 1
fi

mkdir -p "$install_dir" "$bin_dir" "$applications_dir"
install -m 0755 "$script_dir/alerttray.py" "$install_dir/alerttray.py"
install -m 0644 "$script_dir/districts.json" "$install_dir/districts.json"
install -m 0644 "$script_dir/alerttray-normal.svg" "$install_dir/alerttray-normal.svg"
install -m 0644 "$script_dir/alerttray-alert.svg" "$install_dir/alerttray-alert.svg"

ln -sfn "$install_dir/alerttray.py" "$bin_dir/alerttray"

desktop_file="$applications_dir/alerttray.desktop"
{
    echo "[Desktop Entry]"
    echo "Type=Application"
    echo "Name=AlertTray"
    echo "Comment=Air-raid alerts for selected areas"
    printf 'Exec=python3 "%s/alerttray.py"\n' "$install_dir"
    printf 'Icon=%s/alerttray-normal.svg\n' "$install_dir"
    echo "Terminal=false"
    echo "Categories=Utility;"
} > "$desktop_file"

chmod 0644 "$desktop_file"

echo ""
echo "READY: $bin_dir/alerttray"
echo "Run: alerttray"
