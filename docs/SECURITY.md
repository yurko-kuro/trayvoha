# Безпека TrayVoha

Цей документ описує актуальну модель безпеки TrayVoha 1.0.0 для Windows, Linux і macOS.

## Межа довіри

`TrayVoha <── HTTPS ──> NEPTUN`

Єдиний дозволений зовнішній runtime endpoint:

`https://neptun.in.ua/api/v1/alerts`

HTTP redirects заборонені. Розмір відповіді обмежений до 1 MiB. Вибрані території фільтруються локально і не передаються в HTTP-запиті.

Детальніше про джерело: [NEPTUN](NEPTUN.md).

## Геолокація та приватність

TrayVoha не використовує:

- системні Location/GPS API;
- запити дозволу на геолокацію;
- координати користувача;
- IP-geolocation;
- позиціонування через Wi-Fi або Bluetooth;
- browser-mediated geolocation;
- автоматичне визначення території.

NEPTUN отримує лише звичайні мережеві метадані HTTPS-з'єднання: публічну IP-адресу, TLS/HTTP metadata та User-Agent TrayVoha.

## Мережеві інваріанти

На всіх платформах перевіряються:

- фіксований HTTPS endpoint;
- заборона HTTP redirects;
- bounded response до 1 MiB;
- відсутність browser/location механізмів.

Windows CI додатково виконує live runtime-аудит і перевіряє:

- вихідні TCP-з'єднання лише на порт 443;
- підключення лише до адрес `neptun.in.ua`;
- відсутність TCP listener;
- відсутність UDP endpoint;
- відсутність дочірніх процесів під час runtime-аудиту.

Успішний аудит фіксує:

`NetworkInvariant=ONLY_NEPTUN_443`

`AuditResult=PASS`

## Локальні дані

Windows:

`%APPDATA%\TrayVoha\settings.json`

Linux:

`~/.config/trayvoha/settings.json`

macOS:

`~/Library/Application Support/TrayVoha/settings.json`

Налаштування не містять паролів, API-токенів або облікових даних.

## Автозапуск

- Windows: `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`;
- Linux: XDG Autostart;
- macOS: `SMAppService`.

Автозапуск вмикається дією користувача.

## Пакування

### Windows

Self-contained single-file `TrayVoha.exe` та Inno Setup installer. CI виконує реальну install/uninstall перевірку і звіряє встановлений payload.

Успішний аудит фіксує:

`InstallerInvariant=INSTALL_HASH_UNINSTALL_PASS`

`AuditResult=PASS`

### Linux

CI збирає Debian `.deb`, RPM `.rpm` та portable ZIP і перевіряє runtime/package invariants.

### macOS

CI збирає universal `TrayVoha.app` для `arm64` і `x86_64`, ZIP та DMG.

Перевіряються:

- обидві архітектури через `lipo`;
- цілісність `.app` через `codesign --verify`;
- цілісність DMG через `hdiutil verify`;
- реальне монтування DMG;
- наявність `TrayVoha.app`;
- посилання `Applications -> /Applications`;
- universal binary усередині змонтованого DMG.

DMG не містить installer scripts, auto-install механізмів або обходу Gatekeeper.

## Підпис

Поточні Windows CI-артефакти не мають production Authenticode-підпису.

macOS CI використовує ad-hoc signature для перевірки цілісності. Для production-розповсюдження потрібні Apple Developer ID signing і notarization.

## Виконання коду

Runtime не повинен:

- відкривати browser або зовнішні вебсторінки;
- завантажувати та виконувати код;
- мати runtime plugin/update механізм із executable content;
- створювати service, driver або firewall rule;
- відкривати inbound network listener.

Дані NEPTUN обробляються як JSON-дані, а не як код.

## Залежність від джерела

Помилка, недоступність або компрометація NEPTUN може призвести до неправильного, відсутнього або застарілого відображення стану тривоги.

TrayVoha є допоміжним засобом і не замінює офіційні канали оповіщення.

Технічний склад платформи та використані системні механізми описані в [TECHNICAL.md](TECHNICAL.md).