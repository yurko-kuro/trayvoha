# Debian-пакет

Збірка пакета для Ubuntu та Debian:

```bash
./packaging/debian/build-deb.sh
```

Результат: `dist/tryvoha-desktop_1.4.0_all.deb`.

Встановлення:

```bash
sudo apt install ./tryvoha-desktop_1.4.0_all.deb
```

Пакет встановлює застосунок системно, додає його до меню та вмикає автозапуск для графічних сесій. Користувач може вимкнути або знову ввімкнути автозапуск у меню значка «Тривога».

Видалення:

```bash
sudo apt remove tryvoha-desktop
```

Налаштування користувачів у `~/.config/tryvoha` під час видалення пакета не видаляються.
