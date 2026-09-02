#!/usr/bin/env bash

set -eu

if [ "$(id -u)" -eq 0 ]; then
    echo "Не запускайте uninstall.sh через sudo."
    exit 1
fi

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
install_dir="$data_home/tryvoha"

rm -f "$HOME/.local/bin/tryvoha"
rm -f "$data_home/applications/tryvoha.desktop"
rm -f "$config_home/autostart/tryvoha.desktop"
rm -f "$install_dir/tryvoha.py"
rm -f "$install_dir/districts.json"
rm -f "$install_dir/tryvoha.svg"
rm -f "$install_dir/tryvoha-normal.svg"
rm -f "$install_dir/tryvoha-alert.svg"
rmdir "$install_dir" 2>/dev/null || true

echo "Тривогу видалено. Налаштування у $config_home/tryvoha збережено."
