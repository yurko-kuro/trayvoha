# TrayVoha

**TrayVoha** — застосунок для сповіщень про повітряні тривоги для вибраних районів і областей України.

## Можливості

- вибір окремих районів або цілої області;
- одночасне відстеження кількох територій;
- сповіщення про початок та відбій повітряної тривоги;
- показ часу оголошення тривоги;
- окремі стани для нормальної роботи, активної тривоги та недоступності джерела даних;
- світла та темна тема відповідно до системної теми;
- автоматичний запуск після входу до системи;
- Windows, Linux і macOS;
- без реєстрації, реклами та API-ключів.

## Документація

- [Короткий бриф](docs/BRIEF.md)
- [Інструкція користувача](docs/USER_GUIDE.md)
- [Технічна реалізація](docs/TECHNICAL.md)
- [Модель безпеки](docs/SECURITY.md)
- [Джерело даних NEPTUN](docs/NEPTUN.md)
- [Релізи та артефакти](docs/RELEASES.md)

## Завантаження

Перевірені збірки публікуються в розділі [Releases](https://github.com/yurko-kuro/trayvoha/releases).

Поточний реліз `v1.4.0` є історичним legacy-релізом зі старими назвами. Канонічний релізний цикл TrayVoha починається з версії `1.5.0` після завершення фінальної перевірки.

Канонічні назви артефактів:

- `TrayVoha-Windows.zip` — переносна Windows-збірка;
- `TrayVoha-Setup-x64.exe` — Windows installer;
- `TrayVoha-Linux.zip` — переносна Linux-версія;
- `trayvoha_<version>_all.deb` — Ubuntu/Debian;
- `trayvoha-<version>-1.noarch.rpm` — Fedora/RPM;
- `TrayVoha-macOS.dmg` — основний користувацький macOS-образ для встановлення через перетягування до `Applications`;
- `TrayVoha-macOS.zip` — альтернативний архів із universal `TrayVoha.app` для Apple Silicon та Intel.

## Windows

Windows-збірка self-contained і не потребує окремого встановлення .NET. Також передбачений звичайний installer.

Подвійний лівий клік по значку TrayVoha показує поточний стан, правий клік відкриває меню.

## Linux

Для Ubuntu/Debian:

```bash
sudo apt install ./trayvoha_<version>_all.deb
```

Для Fedora:

```bash
sudo dnf install ./trayvoha-<version>-1.noarch.rpm
```

Для переносного встановлення:

```bash
chmod +x install.sh uninstall.sh
./install.sh
```

## macOS

macOS-версія є нативним menu-bar застосунком на Swift/AppKit і використовує системні механізми сповіщень, теми та автозапуску.

CI окремо збирає `arm64` і `x86_64`, об'єднує їх у universal binary та перевіряє обидві архітектури через `lipo`. Один `TrayVoha.app` призначений для Apple Silicon та Intel Mac з macOS 13 або новішою.

Для звичайного встановлення передбачений `TrayVoha-macOS.dmg`: користувач відкриває образ і перетягує `TrayVoha.app` до `Applications`. `TrayVoha-macOS.zip` залишається альтернативним способом отримати той самий застосунок без DMG.

Поточна CI-збірка підписується ad-hoc для перевірки цілісності; production-розповсюдження потребує Developer ID signing і notarization.

## Дані та приватність

TrayVoha отримує дані лише з фіксованого HTTPS API NEPTUN. Вибір територій зберігається локально й не передається як параметр запиту.

TrayVoha не використовує геолокацію, GPS, IP-geolocation, Wi-Fi/Bluetooth positioning і не запитує дозволу на визначення місцезнаходження.

Застосунок не повинен автоматично відкривати зовнішні сайти або браузер.

## Важливо

TrayVoha є допоміжним інформаційним застосунком і не замінює офіційні сигнали повітряної тривоги.
