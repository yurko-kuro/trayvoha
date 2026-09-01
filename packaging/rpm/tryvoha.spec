Name:           tryvoha-desktop
Version:        1.4.0
Release:        1
Summary:        Air-raid alerts in the system tray
License:        LicenseRef-Proprietary
URL:            https://github.com/yurko-kuro/tryvoha-desktop
BuildArch:      noarch

%global appdir %{_prefix}/lib/tryvoha

Requires:       python3
Requires:       python3-gobject
Requires:       gtk3
Requires:       libayatana-appindicator-gtk3
Requires:       libnotify

%description
Тривога показує стан повітряних тривог для вибраних районів
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

install -m 0755 %{repo_root}/linux/tryvoha.py \
    %{buildroot}%{appdir}/tryvoha.py
install -m 0644 %{repo_root}/linux/districts.json \
    %{buildroot}%{appdir}/districts.json
install -m 0644 %{repo_root}/linux/tryvoha-normal.svg \
    %{buildroot}%{appdir}/tryvoha-normal.svg
install -m 0644 %{repo_root}/linux/tryvoha-alert.svg \
    %{buildroot}%{appdir}/tryvoha-alert.svg

ln -s ../lib/tryvoha/tryvoha.py %{buildroot}%{_bindir}/tryvoha

install -m 0644 %{repo_root}/packaging/debian/tryvoha.desktop \
    %{buildroot}%{_datadir}/applications/tryvoha.desktop
install -m 0644 %{repo_root}/packaging/debian/tryvoha-autostart.desktop \
    %{buildroot}%{_sysconfdir}/xdg/autostart/tryvoha.desktop
install -m 0644 %{repo_root}/linux/tryvoha-normal.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/tryvoha-normal.svg

%files
%{_bindir}/tryvoha
%{appdir}/
%{_datadir}/applications/tryvoha.desktop
%{_datadir}/icons/hicolor/scalable/apps/tryvoha-normal.svg
%config(noreplace) %{_sysconfdir}/xdg/autostart/tryvoha.desktop

%changelog
* Tue Sep 01 2026 Yurii Chornyi <yurko.kuro@gmail.com> - 1.4.0-1
- Initial Fedora package
