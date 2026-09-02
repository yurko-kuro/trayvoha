# Релізи TrayVoha

## Поточний релізний цикл

Поточна версія у вихідному коді: **1.5.0**.

Версія 1.5.0 готується як перший канонічний реліз під назвою **TrayVoha** з повним покриттям трьох десктопних платформ:

- Windows;
- Linux;
- macOS.

Публікація релізу виконується лише після зелених CI-перевірок відповідного release checkpoint і ручної перевірки зібраних артефактів.

## Канонічні артефакти 1.5.0

### Windows

- `TrayVoha-Windows.zip` — переносна self-contained збірка;
- `TrayVoha-Setup-x64.exe` — installer для Windows x64.

### Linux

- `TrayVoha-Linux.zip` — переносний комплект;
- `trayvoha_1.5.0_all.deb` — Ubuntu/Debian;
- `trayvoha-1.5.0-1.noarch.rpm` — Fedora/RPM-сумісні системи.

### macOS

- `TrayVoha-macOS.dmg` — основний користувацький образ із `TrayVoha.app` та посиланням на `/Applications` для звичайного drag-to-Applications встановлення;
- `TrayVoha-macOS.zip` — альтернативний архів із тим самим universal `TrayVoha.app` для `arm64` і `x86_64`, macOS 13+.

CI збирає архітектури окремо, об'єднує їх через `lipo` та перевіряє наявність обох slices у фінальному виконуваному файлі. DMG окремо проходить `hdiutil verify`, монтується в CI, після чого перевіряються `TrayVoha.app`, посилання `Applications`, code signature та обидві архітектури всередині змонтованого образу.

Поточна macOS-збірка має ad-hoc code signature для перевірки цілісності bundle у CI. Для широкого production-розповсюдження потрібні Apple Developer ID signing і notarization.

## Що входить до 1.5.0

- канонічне ім'я продукту TrayVoha;
- Windows, Linux і macOS;
- universal macOS binary для Apple Silicon та Intel;
- macOS DMG із drag-to-Applications встановленням;
- ручний вибір областей і районів;
- локальне зберігання вибору;
- автоматична перевірка стану приблизно раз на 10 секунд;
- системні сповіщення про тривогу та відбій;
- системна Light/Dark тема;
- керований користувачем автозапуск;
- фіксований NEPTUN endpoint;
- заборонені HTTP redirects;
- обмеження response body до 1 MiB;
- відсутність геолокації, телеметрії та browser-mediated location;
- Windows live network audit і installer install/uninstall audit;
- окремий macOS CI на Apple runner;
- окремий CI для Debian, RPM і переносного Linux ZIP.

## Історичний v1.4.0

Опублікований `v1.4.0` залишається історичним legacy-релізом. Він створений до завершення переходу на канонічне ім'я TrayVoha та використовує попередню схему назв продукту й артефактів.

Його не слід використовувати як шаблон назв або пакування для нових релізів. Нові релізи використовують лише канонічні назви, наведені вище.

## Незакриті distribution-пункти

Перед широкою публікацією 1.5.0 потрібно окремо підтвердити:

- Windows Authenticode signing для EXE та installer-а;
- Apple Developer ID signing і notarization для macOS;
- остаточний формат атрибуції NEPTUN відповідно до чинних умов API;
- ручний smoke-test встановлення/запуску на реальних Windows, Ubuntu/Fedora та macOS;
- фінальні скриншоти для `GUIDE.md`.

Відсутність цих distribution-пунктів не означає помилку runtime-коду, але вони мають бути явно враховані перед широким розповсюдженням.
