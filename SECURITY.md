# Безпека TrayVoha

Цей документ описує актуальну модель безпеки TrayVoha 1.5.0 для Windows і Linux.

## Призначення та межі довіри

TrayVoha — локальний застосунок системного трея, який періодично отримує стан повітряних тривог із зовнішнього джерела NEPTUN і показує його для територій, які користувач вибрав вручну.

Межа довіри runtime:

`TrayVoha <── HTTPS ──> NEPTUN`

Єдиний дозволений зовнішній runtime endpoint:

`https://neptun.in.ua/api/v1/alerts`

HTTP redirects заборонені. TrayVoha не повинен автоматично переходити на інший URL або host, навіть якщо джерело повертає перенаправлення.

## Геолокація та приватність

**Доступ до геолокації: ПОВИНЕН БУТИ ВІДСУТНІЙ.**

TrayVoha не використовує і не повинен використовувати:

- Windows, macOS, Linux або mobile Location/GPS API;
- запити дозволу на геолокацію;
- координати користувача;
- IP-geolocation;
- позиціонування через Wi-Fi або Bluetooth;
- browser-mediated geolocation;
- автоматичне визначення території за місцем перебування.

Території вибираються користувачем вручну та зберігаються локально.

Вибрана область або район не додаються до URL чи тіла HTTP-запиту. NEPTUN отримує звичайні мережеві метадані HTTPS-з'єднання, зокрема публічну IP-адресу, TLS/HTTP metadata та User-Agent `TrayVoha/1.5.0`.

## Мережеві інваріанти

Для Windows CI виконує runtime-аудит запущеного `TrayVoha.exe` з реальною вибраною територією.

Перевіряється, що:

- існує реальне вихідне TCP-з'єднання;
- кожне таке з'єднання має remote port `443`;
- remote address належить DNS-набору `neptun.in.ua`, який спостерігається під час аудиту;
- застосунок не відкриває TCP listener;
- застосунок не відкриває UDP endpoint;
- застосунок не запускає дочірні процеси під час мережевого runtime-аудиту.

Успішний аудит фіксує:

`NetworkInvariant=ONLY_NEPTUN_443`

`AuditResult=PASS`

## Обмеження відповіді джерела

Розмір HTTP-відповіді NEPTUN обмежений до `1,048,576` байт (1 MiB) на Windows і Linux.

Якщо `Content-Length` перевищує ліміт, відповідь відхиляється до повного читання. Якщо довжина не вказана або недостовірна, runtime читає максимум `1 MiB + 1 байт` і відхиляє перевищення.

JSON парситься лише після цієї перевірки.

Це обмежує ризик memory/resource DoS через надмірно великий response body.

## Browser та виконання коду

Runtime не повинен:

- відкривати браузер або зовнішні вебсторінки;
- завантажувати та виконувати код;
- мати plugin/update механізм, який отримує виконуваний код із мережі;
- створювати service, driver або firewall rule;
- відкривати inbound network listener.

Дані NEPTUN обробляються як JSON-дані, а не як код.

## Локальні дані

Windows settings зберігаються в:

`%APPDATA%\TrayVoha\settings.json`

Linux settings зберігаються в:

`~/.config/trayvoha/settings.json`

Налаштування не містять паролів, API-токенів або інших secrets. Вибрані території є локальними користувацькими даними і мають розглядатися як privacy-relevant settings.

Під час uninstall Windows installer не видаляє `%APPDATA%\TrayVoha` автоматично.

## Автозапуск

На Windows автозапуск вмикається лише явною дією користувача через `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, value `TrayVoha`.

Сам Windows installer не створює цей Run value.

Linux використовує стандартний desktop/autostart механізм.

## Windows installer

CI виконує реальну тиху установку та видалення installer-а.

Перевіряється, що:

- installation завершується успішно;
- SHA256 установленого `TrayVoha.exe` точно збігається з перевіреним payload;
- uninstall registration створена коректно;
- Start Menu shortcut створений;
- installer не вмикає HKCU autostart;
- uninstall завершується успішно;
- program files видаляються;
- user data зберігаються.

Успішний аудит фіксує:

`InstallerInvariant=INSTALL_HASH_UNINSTALL_PASS`

`AuditResult=PASS`

## Підпис і репутація Windows

Поточні CI-артефакти Windows не мають Authenticode-підпису.

Це означає, що Windows SmartScreen або браузер можуть показувати попередження для завантаженого EXE чи installer-а. Відсутність підпису не змінює SHA256-аудит payload, але є окремим supply-chain/reputation risk перед широким публічним розповсюдженням.

Для production release бажано використовувати довірений code-signing certificate із timestamp і підписувати як payload, так і installer.

## Залежність від джерела даних

Компрометація або помилка NEPTUN може призвести до неправильного, відсутнього або застарілого відображення стану тривоги.

Поточна модель не передбачає виконання коду з response body, тому такий сценарій розглядається насамперед як ризик цілісності та доступності даних, а не як штатний механізм remote code execution.

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
- побудову Debian package.

Security-документ описує поточну реалізацію і не замінює повторний аудит після змін мережевого коду, installer-а, persistence або platform permissions.
