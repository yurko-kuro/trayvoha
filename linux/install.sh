#!/usr/bin/env bash

set -eu

if [ "$(id -u)" -eq 0 ]; then
    echo "Не запускайте install.sh через sudo. Встановлення виконується для поточного користувача."
    exit 1
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
install_dir="$data_home/trayvoha"
bin_dir="$HOME/.local/bin"
applications_dir="$data_home/applications"
autostart_dir="$config_home/autostart"
log_dir="$config_home/trayvoha"

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
    echo "Спочатку встановіть необхідні пакети:"
    echo "sudo apt update && sudo apt install$missing"
    exit 1
fi

mkdir -p "$install_dir" "$bin_dir" "$applications_dir" "$autostart_dir" "$log_dir"
install -m 0755 "$script_dir/trayvoha.py" "$install_dir/trayvoha.py"
install -m 0644 "$script_dir/trayvoha_app.py" "$install_dir/trayvoha_app.py"
install -m 0644 "$script_dir/districts.json" "$install_dir/districts.json"
install -m 0644 "$script_dir/trayvoha.svg" "$install_dir/trayvoha.svg"
install -m 0644 "$script_dir/trayvoha-normal.svg" "$install_dir/trayvoha-normal.svg"
install -m 0644 "$script_dir/trayvoha-alert.svg" "$install_dir/trayvoha-alert.svg"
install -m 0644 "$script_dir/trayvoha-unknown.svg" "$install_dir/trayvoha-unknown.svg"

ln -sfn "$install_dir/trayvoha.py" "$bin_dir/trayvoha"

write_desktop_file() {
    target="$1"
    {
        echo "[Desktop Entry]"
        echo "Version=1.0"
        echo "Type=Application"
        echo "Name=TrayVoha"
        echo "Comment=Сповіщення про повітряні тривоги для вибраних територій"
        printf 'Exec=python3 "%s/trayvoha.py"\n' "$install_dir"
        printf 'Icon=%s/trayvoha.svg\n' "$install_dir"
        echo "Terminal=false"
        echo "Categories=Utility;"
        echo "StartupNotify=false"
        echo "X-GNOME-Autostart-enabled=true"
    } > "$target"
    chmod 0644 "$target"
}

desktop_file="$applications_dir/trayvoha.desktop"
autostart_file="$autostart_dir/trayvoha.desktop"
write_desktop_file "$desktop_file"
write_desktop_file "$autostart_file"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
fi

running=0
if command -v pgrep >/dev/null 2>&1; then
    if pgrep -u "$(id -u)" -f "$install_dir/trayvoha.py" >/dev/null 2>&1; then
        running=1
    fi
fi

if [ "$running" -eq 0 ] && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }; then
    nohup python3 "$install_dir/trayvoha.py" \
        >> "$log_dir/trayvoha.log" 2>&1 </dev/null &
fi

echo ""
echo "ГОТОВО: TrayVoha встановлено та додано до автозапуску."
echo "Команда запуску: $bin_dir/trayvoha"
echo "Автозапуск: $autostart_file"
