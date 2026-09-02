# TrayVoha

**TrayVoha** — застосунок для сповіщень про повітряні тривоги для вибраних районів і областей України.

## Можливості

- вибір окремих районів або цілої області;
- одночасне відстеження кількох територій;
- сповіщення про початок та відбій повітряної тривоги;
- показ часу оголошення тривоги;
- окремі стани для нормальної роботи, активної тривоги та недоступності джерела даних;
- світла та темна тема;
- автоматичний запуск після входу до системи;
- Windows 10/11, Ubuntu/Debian і Fedora;
- підготовлена система іконок для macOS, Android та iOS;
- без реєстрації, реклами та API-ключів.

## Завантаження

Перевірені збірки публікуються в розділі [Releases](https://github.com/yurko-kuro/trayvoha/releases).

Канонічні назви артефактів наступних релізів:

- `TrayVoha-Windows.zip` — Windows;
- `TrayVoha-Linux.zip` — переносна Linux-версія;
- `trayvoha_<version>_all.deb` — Ubuntu/Debian;
- `trayvoha-<version>-1.noarch.rpm` — Fedora.

## Windows

Після розпакування Windows-збірки запускається `TrayVoha.exe`. Збірка self-contained і не потребує окремого встановлення .NET.

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

## Дані та приватність

TrayVoha отримує дані лише з фіксованого HTTPS API NEPTUN. Вибір територій зберігається локально.

TrayVoha не використовує геолокацію, GPS, IP-geolocation, Wi-Fi/Bluetooth positioning і не запитує дозволу на визначення місцезнаходження.

Застосунок не повинен автоматично відкривати зовнішні сайти або браузер.

## Важливо

TrayVoha є допоміжним інформаційним застосунком і не замінює офіційні сигнали повітряної тривоги.
