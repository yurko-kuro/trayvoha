# TrayVoha 1.5.0

TrayVoha 1.5.0 — перший канонічний реліз TrayVoha з повним десктопним покриттям Windows, Linux і macOS.

## Основне

- вибір областей і районів України вручну;
- одночасне відстеження кількох територій;
- автоматична перевірка приблизно раз на 10 секунд;
- системні сповіщення про початок і відбій повітряної тривоги;
- системна Light/Dark тема;
- керований користувачем автозапуск;
- локальне зберігання вибраних територій;
- без геолокації, реєстрації, реклами та API-ключів.

## Windows

- self-contained `TrayVoha.exe` без окремого .NET Runtime;
- переносний `TrayVoha-Windows.zip`;
- installer `TrayVoha-Setup-x64.exe`;
- подвійний лівий клік по значку показує поточний стан;
- правий клік відкриває меню;
- CI перевіряє runtime-мережу та реальне встановлення/видалення installer-а.

## Linux

- переносний `TrayVoha-Linux.zip`;
- `trayvoha_1.5.0_all.deb` для Ubuntu/Debian;
- `trayvoha-1.5.0-1.noarch.rpm` для Fedora/RPM-сумісних систем;
- GTK/AppIndicator та системна GTK-тема.

## macOS

- нативний Swift/AppKit menu-bar застосунок;
- `TrayVoha-macOS.zip` із universal `TrayVoha.app` для Apple Silicon (`arm64`) та Intel (`x86_64`);
- мінімальна версія — macOS 13;
- системні Notification Center, Light/Dark appearance та автозапуск через macOS;
- CI окремо збирає обидві архітектури, об'єднує їх через `lipo` та перевіряє фінальний universal binary на Apple runner.

## Безпека та приватність

Єдиний зовнішній runtime endpoint:

`https://neptun.in.ua/api/v1/alerts`

- HTTPS only;
- HTTP redirects заборонені;
- response body обмежений до 1 MiB;
- вибрані території фільтруються локально і не передаються як параметри запиту;
- геолокація, IP-geolocation, Wi-Fi/Bluetooth positioning і телеметрія не використовуються;
- зовнішні сайти автоматично не відкриваються.

TrayVoha є допоміжним інформаційним застосунком і не замінює офіційні сигнали повітряної тривоги.

## Примітка щодо підпису

Перед широким production-розповсюдженням рекомендовані Windows Authenticode signing, Apple Developer ID signing та notarization macOS-збірки.
