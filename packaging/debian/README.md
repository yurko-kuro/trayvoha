# Debian-пакет TrayVoha

Збірка пакета для Ubuntu та Debian:

```bash
./packaging/debian/build-deb.sh
```

Результат: `dist/trayvoha_1.0.0_all.deb`.

Встановлення:

```bash
sudo apt install ./trayvoha_1.0.0_all.deb
```

Пакет встановлює TrayVoha системно, додає його до меню та вмикає автозапуск для графічних сесій. Користувач може вимкнути або знову ввімкнути автозапуск у меню TrayVoha.

Видалення:

```bash
sudo apt remove trayvoha
```

Налаштування користувачів у `~/.config/trayvoha` під час видалення пакета не видаляються.
