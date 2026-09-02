#!/usr/bin/env python3

from __future__ import annotations

from datetime import datetime
import json
import os
import socket
import subprocess
import sys
import threading
import unicodedata
import urllib.request
from pathlib import Path

try:
    import gi

    gi.require_version("Gtk", "3.0")
    try:
        gi.require_version("AyatanaAppIndicator3", "0.1")
        from gi.repository import AyatanaAppIndicator3 as AppIndicator3
    except (ValueError, ImportError):
        gi.require_version("AppIndicator3", "0.1")
        from gi.repository import AppIndicator3

    from gi.repository import Gdk, GLib, Gtk
except (ImportError, ValueError) as error:
    print("Відсутні залежності GTK/AppIndicator:", error, file=sys.stderr)
    print(
        "Встановіть: sudo apt install python3-gi gir1.2-gtk-3.0 "
        "gir1.2-ayatanaappindicator3-0.1 libnotify-bin",
        file=sys.stderr,
    )
    raise SystemExit(1)


APP_DIR = Path(__file__).resolve().parent
CATALOG_FILE = APP_DIR / "districts.json"
NORMAL_ICON = APP_DIR / "trayvoha-normal.svg"
ALERT_ICON = APP_DIR / "trayvoha-alert.svg"
UNKNOWN_ICON = APP_DIR / "trayvoha-unknown.svg"
ALERTS_URL = "https://neptun.in.ua/api/v1/alerts"
MAX_RESPONSE_BYTES = 1_048_576

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
SETTINGS_DIR = CONFIG_HOME / "trayvoha"
SETTINGS_FILE = SETTINGS_DIR / "settings.json"
AUTOSTART_FILE = CONFIG_HOME / "autostart" / "trayvoha.desktop"
SYSTEM_AUTOSTART_FILE = Path("/etc/xdg/autostart/trayvoha.desktop")

_INSTANCE_SOCKET: socket.socket | None = None


def acquire_single_instance() -> bool:
    global _INSTANCE_SOCKET

    instance_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        instance_socket.bind(f"\0trayvoha-{os.getuid()}")
    except OSError:
        instance_socket.close()
        return False

    _INSTANCE_SOCKET = instance_socket
    return True


def user_autostart_is_hidden() -> bool:
    try:
        lines = AUTOSTART_FILE.read_text(encoding="utf-8").splitlines()
    except OSError:
        return False
    return any(line.strip().lower() == "hidden=true" for line in lines)


def autostart_is_enabled() -> bool:
    if AUTOSTART_FILE.exists():
        return not user_autostart_is_hidden()
    return SYSTEM_AUTOSTART_FILE.exists()


def normalize(value: str) -> str:
    return unicodedata.normalize("NFC", value or "").strip().lower()


def oblast_key(oblast: str) -> str:
    return "oblast:" + normalize(oblast)


def raion_key(key: str) -> str:
    return "raion:" + normalize(key)


def key_value(selection_key: str) -> str:
    return selection_key.split(":", 1)[1] if ":" in selection_key else ""


class SelectionDialog:
    def __init__(self, oblasts: list[str], raions: list[dict], selected: list[str]):
        self.oblasts = oblasts
        self.raions = raions
        self.selected = set(selected)
        self.store = Gtk.TreeStore(bool, str, str, bool)

        self.dialog = Gtk.Dialog(title="Вибір територій", flags=Gtk.DialogFlags.MODAL)
        self.dialog.set_default_size(620, 720)
        self.dialog.set_position(Gtk.WindowPosition.CENTER)
        self.dialog.set_resizable(True)

        self._install_accent_theme()
        self._build_content()

    def _install_accent_theme(self) -> None:
        css = b"""
            button.suggested-action {
                background-image: none;
                background-color: #cd2030;
                color: #ffffff;
            }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def _build_content(self) -> None:
        content = self.dialog.get_content_area()
        content.set_spacing(10)
        content.set_border_width(12)

        instruction = Gtk.Label(
            label=(
                "Розгорніть потрібну область і позначте території. "
                "Галочка на самій області означає весь регіон."
            )
        )
        instruction.set_line_wrap(True)
        instruction.set_xalign(0)
        content.pack_start(instruction, False, False, 0)

        for oblast in self.oblasts:
            o_key = oblast_key(oblast)
            root = self.store.append(None, [o_key in self.selected, oblast, o_key, True])
            has_selection = o_key in self.selected
            for raion in (item for item in self.raions if item["oblast"] == oblast):
                r_key = raion_key(raion["key"])
                checked = not has_selection and r_key in self.selected
                self.store.append(root, [checked, raion["name"], r_key, False])
                has_selection = has_selection or checked

        tree = Gtk.TreeView(model=self.store)
        tree.set_headers_visible(False)

        toggle = Gtk.CellRendererToggle()
        toggle.set_property("activatable", True)
        toggle.connect("toggled", self._toggle_row)
        tree.append_column(Gtk.TreeViewColumn("", toggle, active=0))

        text = Gtk.CellRendererText()
        tree.append_column(Gtk.TreeViewColumn("Територія", text, text=1))

        scroller = Gtk.ScrolledWindow()
        scroller.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scroller.add(tree)
        content.pack_start(scroller, True, True, 0)

        tree.show_all()
        root = self.store.get_iter_first()
        index = 0
        while root:
            if self._row_or_children_checked(root):
                tree.expand_row(Gtk.TreePath(index), False)
            root = self.store.iter_next(root)
            index += 1

        clear_button = self.dialog.add_button("Зняти всі", Gtk.ResponseType.NONE)
        clear_button.connect("clicked", lambda _button: self._clear_all())
        self.dialog.add_button("Скасувати", Gtk.ResponseType.CANCEL)
        save_button = self.dialog.add_button("Зберегти", Gtk.ResponseType.OK)
        save_button.get_style_context().add_class("suggested-action")
        self.dialog.set_default_response(Gtk.ResponseType.OK)
        self.dialog.show_all()

    def _toggle_row(self, _renderer, path: str) -> None:
        tree_iter = self.store.get_iter(path)
        checked = not self.store.get_value(tree_iter, 0)
        is_oblast = self.store.get_value(tree_iter, 3)
        self.store.set_value(tree_iter, 0, checked)

        if is_oblast and checked:
            child = self.store.iter_children(tree_iter)
            while child:
                self.store.set_value(child, 0, False)
                child = self.store.iter_next(child)
        elif not is_oblast and checked:
            parent = self.store.iter_parent(tree_iter)
            if parent:
                self.store.set_value(parent, 0, False)

    def _clear_all(self) -> None:
        def clear(_model, _path, tree_iter, _data):
            self.store.set_value(tree_iter, 0, False)

        self.store.foreach(clear, None)

    def _row_or_children_checked(self, tree_iter) -> bool:
        if self.store.get_value(tree_iter, 0):
            return True
        child = self.store.iter_children(tree_iter)
        while child:
            if self.store.get_value(child, 0):
                return True
            child = self.store.iter_next(child)
        return False

    def run(self) -> tuple[bool, list[str]]:
        response = self.dialog.run()
        if response != Gtk.ResponseType.OK:
            self.dialog.destroy()
            return False, []

        selected: list[str] = []

        def collect(_model, _path, tree_iter, _data):
            if self.store.get_value(tree_iter, 0):
                selected.append(self.store.get_value(tree_iter, 2))

        self.store.foreach(collect, None)
        self.dialog.destroy()
        return True, sorted(set(selected))


class TrayVohaApp:
    def __init__(self):
        catalog = json.loads(CATALOG_FILE.read_text(encoding="utf-8"))
        self.oblasts: list[str] = catalog["oblasts"]
        self.raions: list[dict] = catalog["raions"]
        self.raions_by_key = {normalize(item["key"]): item for item in self.raions}
        self.settings = self._load_settings()

        self.last_fingerprint: str | None = None
        self.last_active: bool | None = None
        self.checking = False
        self.force_pending = False

        self.indicator = AppIndicator3.Indicator.new(
            "trayvoha",
            "trayvoha-unknown",
            AppIndicator3.IndicatorCategory.APPLICATION_STATUS,
        )
        self.indicator.set_icon_theme_path(str(APP_DIR))
        self._set_icon("unknown")
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.indicator.set_title("TrayVoha")
        self.indicator.set_menu(self._build_menu())

        GLib.idle_add(self._first_run)
        GLib.timeout_add_seconds(10, self._poll)

    def _build_menu(self):
        menu = Gtk.Menu()

        self.status_item = Gtk.MenuItem(label="Перевіряю стан…")
        self.status_item.set_sensitive(False)
        menu.append(self.status_item)

        self.selection_item = Gtk.MenuItem(label=self._selection_summary())
        self.selection_item.set_sensitive(False)
        menu.append(self.selection_item)
        menu.append(Gtk.SeparatorMenuItem())

        configure = Gtk.MenuItem(label="Налаштувати території…")
        configure.connect("activate", lambda _item: self._configure())
        menu.append(configure)

        check_now = Gtk.MenuItem(label="Показати стан зараз")
        check_now.connect("activate", lambda _item: self.request_check(True))
        menu.append(check_now)

        self.autostart_item = Gtk.CheckMenuItem(label="Запускати разом із системою")
        self.autostart_item.set_active(autostart_is_enabled())
        self.autostart_item.connect("toggled", self._toggle_autostart)
        menu.append(self.autostart_item)
        menu.append(Gtk.SeparatorMenuItem())

        source = Gtk.MenuItem(label="Джерело: NEPTUN")
        source.set_sensitive(False)
        menu.append(source)

        quit_item = Gtk.MenuItem(label="Вийти")
        quit_item.connect("activate", lambda _item: Gtk.main_quit())
        menu.append(quit_item)

        menu.show_all()
        return menu

    def _first_run(self):
        if not self.settings.get("setup_completed", False):
            if not self._configure():
                self._set_icon("unknown")
                self.status_item.set_label("Не вибрано територій")
        else:
            self.request_check(True)
        return False

    def _configure(self):
        dialog = SelectionDialog(
            self.oblasts,
            self.raions,
            self.settings.get("selected_area_keys", []),
        )
        saved, selected = dialog.run()
        if not saved:
            return False

        self.settings["selected_area_keys"] = selected
        self.settings["setup_completed"] = True
        self._save_settings()
        self.selection_item.set_label(self._selection_summary())
        self.last_fingerprint = None
        self.last_active = None
        self.request_check(True)
        return True

    def _poll(self):
        self.request_check(False)
        return True

    def request_check(self, force: bool):
        selected = list(self.settings.get("selected_area_keys", []))
        if not selected:
            self._set_icon("unknown")
            self.status_item.set_label("Не вибрано територій")
            return

        if self.checking:
            self.force_pending = self.force_pending or force
            return

        self.checking = True
        threading.Thread(target=self._fetch_worker, args=(selected, force), daemon=True).start()

    def _fetch_worker(self, selected: list[str], force: bool):
        try:
            request = urllib.request.Request(ALERTS_URL, headers={"User-Agent": "TrayVoha/1.0.0"})
            with urllib.request.urlopen(request, timeout=8) as response:
                content_length = response.headers.get("Content-Length")
                if content_length is not None and int(content_length) > MAX_RESPONSE_BYTES:
                    raise ValueError("Джерело даних повернуло завелику відповідь.")

                response_bytes = response.read(MAX_RESPONSE_BYTES + 1)
                if len(response_bytes) > MAX_RESPONSE_BYTES:
                    raise ValueError("Джерело даних повернуло завелику відповідь.")

                payload = json.loads(response_bytes)
            state = self._compute_state(payload, selected)
            GLib.idle_add(self._apply_state, state, selected, force)
        except Exception:
            GLib.idle_add(self._apply_error)

    def _compute_state(self, payload: dict, selected: list[str]) -> dict:
        raion_alerts = payload.get("raions", [])
        oblast_alerts = payload.get("oblasts", [])
        statuses: dict[str, bool] = {}
        active_areas: list[dict] = []
        fingerprint_parts: list[str] = []

        for selection_key in selected:
            matches: list[tuple[str, dict]] = []
            if selection_key.startswith("raion:"):
                raion = self.raions_by_key.get(key_value(selection_key))
                if raion:
                    matches.extend(
                        ("raion", item)
                        for item in raion_alerts
                        if normalize(item.get("key", "")) == normalize(raion["key"])
                    )
                    matches.extend(
                        ("oblast", item)
                        for item in oblast_alerts
                        if self._belongs_to_oblast(item, raion["oblast"])
                    )
            elif selection_key.startswith("oblast:"):
                oblast = next(
                    (item for item in self.oblasts if normalize(item) == key_value(selection_key)),
                    None,
                )
                if oblast:
                    matches.extend(
                        ("raion", item)
                        for item in raion_alerts
                        if self._belongs_to_oblast(item, oblast)
                    )
                    matches.extend(
                        ("oblast", item)
                        for item in oblast_alerts
                        if self._belongs_to_oblast(item, oblast)
                    )

            statuses[selection_key] = bool(matches)
            if matches:
                since_values = [
                    str(item.get("since", ""))
                    for _source_type, item in matches
                    if item.get("since")
                ]
                active_areas.append(
                    {
                        "selection_key": selection_key,
                        "since": min(since_values) if since_values else "",
                    }
                )

            for source_type, item in matches:
                fingerprint_parts.append(
                    "|".join(
                        (
                            selection_key,
                            source_type,
                            normalize(item.get("key", "")),
                            item.get("since", ""),
                        )
                    )
                )

        return {
            "statuses": statuses,
            "active": any(statuses.values()),
            "active_areas": active_areas,
            "fingerprint": ";".join(sorted(fingerprint_parts)),
        }

    @staticmethod
    def _belongs_to_oblast(item: dict, oblast: str) -> bool:
        expected = normalize(oblast)
        return normalize(item.get("oblast", "")) == expected or normalize(item.get("name", "")) == expected

    def _apply_state(self, state: dict, checked_selection: list[str], force: bool):
        self.checking = False
        if set(checked_selection) != set(self.settings.get("selected_area_keys", [])):
            self.request_check(True)
            return False

        active = state["active"]
        self._set_icon("alert" if active else "normal")
        self.status_item.set_label(
            "Зараз: повітряна тривога" if active else "Зараз: тривоги немає"
        )

        changed = state["fingerprint"] != self.last_fingerprint
        if force or changed:
            all_clear = self.last_active is True and not active
            title = (
                "Повітряна тривога"
                if active
                else "Відбій повітряної тривоги"
                if all_clear
                else "Тривоги немає"
            )
            self._notify(title, self._notification_body(state), active)

        self.last_fingerprint = state["fingerprint"]
        self.last_active = active
        self._run_pending_check()
        return False

    def _apply_error(self):
        self.checking = False
        self._set_icon("unknown")
        self.status_item.set_label("Немає зв’язку з джерелом даних")
        self._run_pending_check()
        return False

    def _run_pending_check(self):
        if self.force_pending:
            self.force_pending = False
            self.request_check(True)

    def _notification_body(self, state: dict) -> str:
        lines: list[str] = []
        if state["active"]:
            for active_area in state.get("active_areas", []):
                if lines:
                    lines.append("")
                lines.append(self._display_name(active_area["selection_key"]))
                lines.append(f'Оголошено: {self._format_alert_time(active_area.get("since", ""))}')
        else:
            for selection_key in self.settings.get("selected_area_keys", []):
                lines.append(self._display_name(selection_key))

        lines.extend(("", "Джерело: NEPTUN"))
        return "\n".join(lines)

    @staticmethod
    def _format_alert_time(value: str) -> str:
        if not value:
            return "немає даних"
        try:
            alert_time = datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone()
        except (TypeError, ValueError):
            return "немає даних"

        now = datetime.now().astimezone()
        return alert_time.strftime("%H:%M") if alert_time.date() == now.date() else alert_time.strftime("%d.%m, %H:%M")

    def _display_name(self, selection_key: str) -> str:
        if selection_key.startswith("raion:"):
            raion = self.raions_by_key.get(key_value(selection_key))
            return (
                f'{raion["name"]} ({raion["oblast"]})'
                if raion
                else selection_key
            )
        if selection_key.startswith("oblast:"):
            return next(
                (item for item in self.oblasts if normalize(item) == key_value(selection_key)),
                selection_key,
            )
        return selection_key

    def _selection_summary(self) -> str:
        selected = self.settings.get("selected_area_keys", [])
        if not selected:
            return "Території: нічого не вибрано"
        if len(selected) <= 2:
            return "Території: " + ", ".join(self._display_name(item) for item in selected)
        return f"Території: вибрано {len(selected)}"

    def _set_icon(self, state: str):
        if state == "alert":
            icon_name = "trayvoha-alert"
            description = "Повітряна тривога"
        elif state == "normal":
            icon_name = "trayvoha-normal"
            description = "TrayVoha"
        else:
            icon_name = "trayvoha-unknown"
            description = "Дані недоступні"
        self.indicator.set_icon_full(icon_name, description)

    @staticmethod
    def _notify(title: str, body: str, active: bool):
        icon = str(ALERT_ICON if active else NORMAL_ICON)
        try:
            subprocess.Popen(
                ["notify-send", "-a", "TrayVoha", "-i", icon, "-t", "8000", title, body],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except FileNotFoundError:
            pass

    def _toggle_autostart(self, item):
        enabled = item.get_active()
        if enabled:
            if SYSTEM_AUTOSTART_FILE.exists():
                try:
                    AUTOSTART_FILE.unlink()
                except FileNotFoundError:
                    pass
            else:
                AUTOSTART_FILE.parent.mkdir(parents=True, exist_ok=True)
                script_path = str(Path(__file__).resolve()).replace('"', '\\"')
                AUTOSTART_FILE.write_text(
                    "\n".join(
                        (
                            "[Desktop Entry]",
                            "Type=Application",
                            "Name=TrayVoha",
                            f'Exec=python3 "{script_path}"',
                            "Terminal=false",
                            "X-GNOME-Autostart-enabled=true",
                            "",
                        )
                    ),
                    encoding="utf-8",
                )
        else:
            if SYSTEM_AUTOSTART_FILE.exists():
                AUTOSTART_FILE.parent.mkdir(parents=True, exist_ok=True)
                AUTOSTART_FILE.write_text(
                    "[Desktop Entry]\nHidden=true\n",
                    encoding="utf-8",
                )
            else:
                try:
                    AUTOSTART_FILE.unlink()
                except FileNotFoundError:
                    pass

    @staticmethod
    def _load_settings() -> dict:
        default = {"version": 1, "setup_completed": False, "selected_area_keys": []}
        try:
            loaded = json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))
            if not isinstance(loaded, dict):
                return default
            return {**default, **loaded}
        except (FileNotFoundError, json.JSONDecodeError, OSError):
            return default

    def _save_settings(self):
        SETTINGS_DIR.mkdir(parents=True, exist_ok=True)
        temporary = SETTINGS_FILE.with_suffix(".tmp")
        temporary.write_text(json.dumps(self.settings, ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(SETTINGS_FILE)


def main() -> int:
    if not acquire_single_instance():
        return 0
    TrayVohaApp()
    Gtk.main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
