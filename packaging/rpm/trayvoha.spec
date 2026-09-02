Name:           trayvoha
Version:        1.4.0
Release:        1
Summary:        Сповіщення про повітряні тривоги у системному треї
License:        LicenseRef-Proprietary
URL:            https://github.com/yurko-kuro/trayvoha
BuildArch:      noarch

%global appdir %{_prefix}/lib/trayvoha

Requires:       python3
Requires:       python3-gobject
Requires:       gtk3
Requires:       libayatana-appindicator-gtk3
Requires:       libnotify

%description
TrayVoha показує стан повітряних тривог для вибраних районів
та областей України у системному треї Linux.

%prep

%build

%install
install -d \
    %{buildroot}%{_bindir} \
    %{buildroot}%{appdir} \
    %{buildroot}%{_datadir}/applications \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps \
    %{buildroot}%{_sysconfdir}/xdg/autostart

install -m 0755 %{repo_root}/linux/trayvoha.py \
    %{buildroot}%{appdir}/trayvoha.py
install -m 0644 %{repo_root}/linux/districts.json \
    %{buildroot}%{appdir}/districts.json
install -m 0644 %{repo_root}/linux/trayvoha.svg \
    %{buildroot}%{appdir}/trayvoha.svg
install -m 0644 %{repo_root}/linux/trayvoha-normal.svg \
    %{buildroot}%{appdir}/trayvoha-normal.svg
install -m 0644 %{repo_root}/linux/trayvoha-alert.svg \
    %{buildroot}%{appdir}/trayvoha-alert.svg
install -m 0644 %{repo_root}/linux/trayvoha-unknown.svg \
    %{buildroot}%{appdir}/trayvoha-unknown.svg

ln -s ../lib/trayvoha/trayvoha.py %{buildroot}%{_bindir}/trayvoha

install -m 0644 %{repo_root}/packaging/debian/trayvoha.desktop \
    %{buildroot}%{_datadir}/applications/trayvoha.desktop
install -m 0644 %{repo_root}/packaging/debian/trayvoha-autostart.desktop \
    %{buildroot}%{_sysconfdir}/xdg/autostart/trayvoha.desktop
install -m 0644 %{repo_root}/linux/trayvoha.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/trayvoha.svg

%files
%{_bindir}/trayvoha
%{appdir}/
%{_datadir}/applications/trayvoha.desktop
%{_datadir}/icons/hicolor/scalable/apps/trayvoha.svg
%config(noreplace) %{_sysconfdir}/xdg/autostart/trayvoha.desktop

%changelog
* Wed Sep 02 2026 Yurii Chornyi <yurko.kuro@gmail.com> - 1.4.0-1
- Перейменовано продукт на TrayVoha
