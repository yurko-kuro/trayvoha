# Безпека TrayVoha

Цей документ описує актуальну модель безпеки TrayVoha 1.5.0 для Windows, Linux і macOS.

## Межа довіри

TrayVoha локально перевіряє вибрані користувачем території за даними зовнішнього джерела NEPTUN.

`TrayVoha <── HTTPS ──> NEPTUN`

Єдиний дозволений зовнішній runtime endpoint:

`https://neptun.in.ua/api/v1/alerts`

HTTP redirects заборонені. Розмір відповіді обмежений до 1 MiB на всіх реалізаціях.

Детальніше про джерело: [NEPTUN](NEPTUN.md).

## Геолокація та приватність

**Доступ до геолокації: ПОВИНЕН БУТИ ВІДСУТНІЙ.**

TrayVoha не використовує і не повинен використовувати:

- системні Location/GPS API;
- запити дозволу на геолокацію;
- координати користувача;
- IP-geolocation;
- позиціонування через Wi-Fi або Bluetooth;
- browser-mediated geolocation;
- автоматичне визначення території за місцем перебування.

Території вибираються вручну та зберігаються локально. Область або район не додаються до URL чи тіла HTTP-запиту.

NEPTUN бачить звичайні мережеві метадані HTTPS-з'єднання: публічну IP-адресу, TLS/HTTP metadata та User-Agent TrayVoha.

## Мережеві інваріанти

Windows CI виконує live runtime-аудит і перевіряє, що застосунок:

- встановлює вихідне TCP-з'єднання лише на порт 443;
- підключається до адрес, отриманих для `neptun.in.ua`;
- не відкриває TCP listener;
- не відкриває UDP endpoint;
- не запускає дочірні процеси під час runtime-аудиту.

Успішний аудит фіксує:

`NetworkInvariant=ONLY_NEPTUN_443`

`AuditResult=PASS`

Для Windows, Linux і macOS CI також перевіряє фіксований endpoint, заборону redirects та bounded response.

## Browser та виконання коду

Runtime не повинен:

- відкривати браузер або зовнішні вебсторінки;
- завантажувати та виконувати код;
- мати runtime plugin/update механізм із завантаженням executable content;
- створювати service, driver або firewall rule;
- відкривати inbound network listener.

Дані NEPTUN обробляються як JSON-дані, а не як код.

## Локальні дані

Windows:

`%APPDATA%\TrayVoha\settings.json`

Linux:

`~/.config/trayvoha/settings.json`

macOS:

`~/Library/Application Support/TrayVoha/settings.json`

Налаштування не повинні містити паролів, API-токенів або інших secrets. Вибрані території є локальними privacy-relevant settings.

## Автозапуск

- Windows: `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, value `TrayVoha`; installer сам його не створює.
- Linux: стандартний XDG autostart.
- macOS: штатний `SMAppService`.

Автозапуск вмикається лише дією користувача.

## Windows installer

CI виконує реальну тиху установку та видалення installer-а і перевіряє SHA256 установленого payload, uninstall registration, Start Menu shortcut, відсутність installer-created autostart та збереження користувацьких даних.

Успішний аудит фіксує:

`InstallerInvariant=INSTALL_HASH_UNINSTALL_PASS`

`AuditResult=PASS`

## Підпис і репутація

Поточні Windows CI-артефакти не мають довіреного Authenticode-підпису. Це може викликати SmartScreen-попередження.

macOS CI збирає `.app` і може використовувати ad-hoc signature для перевірки цілісності збірки, але це не замінює Apple Developer ID signing і notarization для публічного production release.

## Залежність від джерела даних

Помилка, недоступність або компрометація NEPTUN може призвести до неправильного, відсутнього або застарілого відображення стану тривоги.

TrayVoha є допоміжним засобом і не повинен вважатися заміною офіційних каналів оповіщення.

## CI security invariants

Поточний CI перевіряє щонайменше:

- canonical product identity TrayVoha;
- відсутність browser/location механізмів;
- фіксований runtime endpoint;
- заборону HTTP redirects;
- bounded NEPTUN response;
- Windows build з warnings-as-errors;
- live Windows network invariant;
- Windows installer install/uninstall invariant;
- Linux package builds;
- macOS Swift/AppKit build та platform security invariants.

Security-документ описує поточну реалізацію і не замінює повторний аудит після змін мережевого коду, persistence, installer/package logic або platform permissions.
