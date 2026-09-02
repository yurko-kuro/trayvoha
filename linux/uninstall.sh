#!/usr/bin/env bash

set -eu

if [ "$(id -u)" -eq 0 ]; then
    echo "Не запускайте uninstall.sh через sudo."
    exit 1
fi

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
install_dir="$data_home/trayvoha"

rm -f "$HOME/.local/bin/trayvoha"
rm -f "$data_home/applications/trayvoha.desktop"
rm -f "$config_home/autostart/trayvoha.desktop"
rm -f "$install_dir/trayvoha.py"
rm -f "$install_dir/districts.json"
rm -f "$install_dir/trayvoha.svg"
rm -f "$install_dir/trayvoha-normal.svg"
rm -f "$install_dir/trayvoha-alert.svg"
rm -f "$install_dir/trayvoha-unknown.svg"
rmdir "$install_dir" 2>/dev/null || true

echo "TrayVoha видалено. Налаштування у $config_home/trayvoha збережено."
