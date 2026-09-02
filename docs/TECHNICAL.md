# Технічна реалізація TrayVoha

## Архітектура

TrayVoha — локальний десктопний застосунок без власного backend-сервера.

Основний цикл:

`TrayVoha → HTTPS GET → NEPTUN → JSON → локальна фільтрація → tray/menu bar → системне сповіщення`

Єдиний зовнішній runtime endpoint:

`https://neptun.in.ua/api/v1/alerts`

Перевірка виконується приблизно раз на 10 секунд. Вибрані області та райони зберігаються локально і не передаються в запиті.

## Windows

- мова: C#;
- runtime: .NET 8;
- UI: Windows Forms;
- HTTP: `System.Net.Http.HttpClient` + `HttpClientHandler`;
- JSON: `System.Text.Json`;
- tray: `System.Windows.Forms.NotifyIcon`;
- сповіщення: Windows tray notifications через `NotifyIcon`;
- автозапуск: `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`;
- налаштування: JSON у `%APPDATA%\TrayVoha\settings.json`;
- тема: системний Light/Dark режим Windows;
- пакування: self-contained single-file `win-x64`;
- installer: Inno Setup.

Зовнішніх NuGet-пакетів у проєкті немає. Використовуються бібліотеки стандартного .NET runtime та Windows Forms.

## Linux

- мова: Python 3;
- UI: GTK 3 через PyGObject (`python3-gi`);
- tray: AyatanaAppIndicator3 або AppIndicator3;
- HTTP: стандартний `urllib.request`;
- JSON: стандартний модуль `json`;
- single-instance: локальний Unix domain socket;
- сповіщення: `libnotify-bin`;
- автозапуск: XDG Autostart (`.desktop`);
- налаштування: `~/.config/trayvoha/settings.json` або `$XDG_CONFIG_HOME/trayvoha/settings.json`;
- тема: системна GTK-тема;
- пакування: Debian `.deb`, RPM `.rpm`, переносний ZIP.

Основні системні залежності Debian/Ubuntu:

- `python3 >= 3.10`;
- `python3-gi`;
- `gir1.2-gtk-3.0`;
- `gir1.2-ayatanaappindicator3-0.1` або `gir1.2-appindicator3-0.1`;
- `libnotify-bin`.

Окремих Python-пакетів із PyPI не використовується.

## macOS

- мова: Swift;
- мінімальна система: macOS 13;
- UI: AppKit;
- menu bar: `NSStatusBar` / `NSStatusItem`;
- HTTP: Foundation `URLSession`;
- JSON і локальні дані: Foundation;
- сповіщення: `UserNotifications` / `UNUserNotificationCenter`;
- автозапуск: `ServiceManagement` / `SMAppService`;
- налаштування: `~/Library/Application Support/TrayVoha/settings.json`;
- тема: системний AppKit appearance;
- пакування: universal `TrayVoha.app` для `arm64` і `x86_64`, ZIP та DMG;
- DMG: стандартний образ із `TrayVoha.app` і посиланням на `/Applications`.

Swift Package Manager використовується без зовнішніх package dependencies. Застосунок працює на системних Apple frameworks: AppKit, Foundation, ServiceManagement і UserNotifications.

## Мережева поведінка

На всіх платформах:

- тільки HTTPS;
- endpoint фіксований у коді;
- HTTP redirects заборонені;
- timeout запиту обмежений;
- response body обмежений до 1 MiB;
- відповідь обробляється як JSON;
- фільтрація територій виконується локально;
- runtime не повинен відкривати browser, listener або завантажувати executable content.

## Локальні дані

Зберігаються лише налаштування застосунку та вибрані території. Паролі, API-ключі, токени авторизації та облікові записи не використовуються.

## Збірка та перевірки

GitHub Actions окремо перевіряє Windows, Linux і macOS.

Перевіряються:

- збірка з актуального source tree;
- фіксований NEPTUN endpoint;
- відсутність геолокації та browser-механізмів;
- заборона redirects;
- ліміт відповіді 1 MiB;
- Windows runtime network audit;
- Windows installer install/uninstall audit;
- Debian, RPM і portable Linux packages;
- macOS universal binary `arm64 + x86_64`;
- `codesign` integrity check;
- `hdiutil verify` для DMG;
- mount DMG і перевірка `TrayVoha.app` та `/Applications` link.

Production-підпис Windows Authenticode та Apple Developer ID/notarization є окремими distribution-механізмами і не входять до поточної CI-перевірки цілісності.