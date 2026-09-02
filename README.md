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
- [Модель безпеки](docs/SECURITY.md)
- [Джерело даних NEPTUN](docs/NEPTUN.md)

## Завантаження

Перевірені збірки публікуються в розділі [Releases](https://github.com/yurko-kuro/trayvoha/releases).

Канонічні назви артефактів релізів:

- `TrayVoha-Windows.zip` — Windows;
- `TrayVoha-Linux.zip` — переносна Linux-версія;
- `trayvoha_<version>_all.deb` — Ubuntu/Debian;
- `trayvoha-<version>-1.noarch.rpm` — Fedora;
- `TrayVoha-macOS.zip` — macOS.

## Windows

Windows-збірка self-contained і не потребує окремого встановлення .NET. Також передбачений звичайний installer.

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

## Дані та приватність

TrayVoha отримує дані лише з фіксованого HTTPS API NEPTUN. Вибір територій зберігається локально й не передається як параметр запиту.

TrayVoha не використовує геолокацію, GPS, IP-geolocation, Wi-Fi/Bluetooth positioning і не запитує дозволу на визначення місцезнаходження.

Застосунок не повинен автоматично відкривати зовнішні сайти або браузер.

## Важливо

TrayVoha є допоміжним інформаційним застосунком і не замінює офіційні сигнали повітряної тривоги.
