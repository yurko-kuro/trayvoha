# RPM-пакет TrayVoha

Збірка пакета для Fedora:

```bash
sudo dnf install rpm-build
./packaging/rpm/build-rpm.sh
```

Встановлення готового пакета:

```bash
sudo dnf install ./trayvoha-1.0.0-1.noarch.rpm
```

Пакет встановлює TrayVoha системно, додає його до меню та вмикає автозапуск для графічних сесій.

Видалення:

```bash
sudo dnf remove trayvoha
```

Налаштування користувачів у `~/.config/trayvoha` під час видалення пакета не видаляються.
