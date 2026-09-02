#!/usr/bin/env python3

from __future__ import annotations

import urllib.request


class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


urllib.request.install_opener(
    urllib.request.build_opener(NoRedirectHandler())
)

from trayvoha_app import main


if __name__ == "__main__":
    raise SystemExit(main())
