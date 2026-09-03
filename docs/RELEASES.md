# Релізи TrayVoha

## Поточний реліз

Поточна версія: **1.0.0**.

TrayVoha 1.0.0 — перший публічний реліз під канонічною назвою **TrayVoha** для Windows, Linux і macOS. Реліз публікується як **pre-release** для ознайомлення та ручного тестування.

## Артефакти 1.0.0

### Windows

- `TrayVoha-Windows.zip` — переносна self-contained збірка;
- `TrayVoha-Setup-x64.exe` — installer для Windows x64.

### Linux

- `TrayVoha-Linux.zip` — переносний комплект;
- `trayvoha_1.0.0_all.deb` — Ubuntu/Debian;
- `trayvoha-1.0.0-1.noarch.rpm` — Fedora/RPM-сумісні системи.

### macOS

- `TrayVoha-macOS.dmg` — образ із `TrayVoha.app` та посиланням на `/Applications`;
- `TrayVoha-macOS.zip` — universal `TrayVoha.app` для `arm64` і `x86_64`, macOS 13+.

## Що входить до 1.0.0

- ручний вибір областей і районів;
- локальне зберігання вибору;
- автоматична перевірка стану приблизно раз на 10 секунд;
- системні сповіщення про тривогу та відбій;
- системна Light/Dark тема;
- керований користувачем автозапуск;
- фіксований NEPTUN endpoint;
- заборонені HTTP redirects;
- обмеження response body до 1 MiB;
- відсутність геолокації та телеметрії;
- Windows runtime network audit та installer install/uninstall audit;
- Debian, RPM і portable Linux packages;
- universal macOS binary `arm64 + x86_64`, ZIP та DMG.

## Distribution

Поточні Windows-артефакти не мають production Authenticode-підпису. macOS-збірка має ad-hoc signature для перевірки цілісності; для широкого production-розповсюдження потрібні Apple Developer ID signing і notarization.

Перед широким розповсюдженням також потрібні завершені ручні smoke-тести на цільових системах та фінальні скриншоти для `GUIDE.md`.
