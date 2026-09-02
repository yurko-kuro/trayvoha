#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import urllib.request


class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


urllib.request.install_opener(
    urllib.request.build_opener(NoRedirectHandler())
)

from trayvoha_app import main
import trayvoha_app


class TrayVohaApp(trayvoha_app.TrayVohaApp):
    def __init__(self):
        self._detail_dialog = None
        super().__init__()

    def _notify(self, title: str, body: str, active: bool):
        self._notify_summary(title, active)
        self._show_detail_dialog(title, body)

    @staticmethod
    def _notify_summary(title: str, active: bool):
        icon = str(trayvoha_app.ALERT_ICON if active else trayvoha_app.NORMAL_ICON)
        summary = (
            "Відкрито детальний стан у TrayVoha"
            if active
            else "На вибраних територіях активної тривоги немає"
        )
        try:
            subprocess.Popen(
                [
                    "notify-send",
                    "-a",
                    "TrayVoha",
                    "-i",
                    icon,
                    "-t",
                    "8000",
                    title,
                    summary,
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except FileNotFoundError:
            pass

    def _show_detail_dialog(self, title: str, body: str):
        if self._detail_dialog is not None:
            self._detail_dialog.destroy()

        dialog = trayvoha_app.Gtk.Dialog(title="TrayVoha")
        dialog.set_default_size(560, -1)
        dialog.set_position(trayvoha_app.Gtk.WindowPosition.CENTER)
        dialog.set_resizable(False)

        content = dialog.get_content_area()
        content.set_spacing(12)
        content.set_border_width(16)

        heading = trayvoha_app.Gtk.Label()
        heading.set_markup(
            f"<b>{trayvoha_app.GLib.markup_escape_text(title)}</b>"
        )
        heading.set_xalign(0)
        content.pack_start(heading, False, False, 0)

        details = trayvoha_app.Gtk.Label(label=body)
        details.set_xalign(0)
        details.set_yalign(0)
        details.set_line_wrap(True)
        details.set_selectable(True)
        content.pack_start(details, False, False, 0)

        dialog.add_button("Закрити", trayvoha_app.Gtk.ResponseType.CLOSE)
        dialog.connect("response", lambda current, _response: current.destroy())

        def clear_reference(current):
            if self._detail_dialog is current:
                self._detail_dialog = None

        dialog.connect("destroy", clear_reference)
        dialog.show_all()
        dialog.present()
        self._detail_dialog = dialog


def main() -> int:
    if not trayvoha_app.acquire_single_instance():
        return 0
    TrayVohaApp()
    trayvoha_app.Gtk.main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
