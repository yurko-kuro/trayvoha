# RPM-пакет

Збірка пакета для Fedora:

```bash
sudo dnf install rpm-build
./packaging/rpm/build-rpm.sh
```

Встановлення готового пакета:

```bash
sudo dnf install ./tryvoha-desktop-1.4.0-1.noarch.rpm
```

Пакет встановлює застосунок системно, додає його до меню та вмикає автозапуск для графічних сесій.

Видалення:

```bash
sudo dnf remove tryvoha-desktop
```

Налаштування користувачів у `~/.config/tryvoha` під час видалення пакета не видаляються.
