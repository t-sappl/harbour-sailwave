# SPDX-License-Identifier: GPL-3.0-or-later
Name:       harbour-sailwave

Summary:    Internet radio player for Sailfish OS
Version:    1.0
Release:    1
License:    GPL-3.0-or-later
URL:        https://github.com/t-sappl/harbour-sailwave/
Source0:    %{name}-%{version}.tar.bz2

# Unversioned on purpose: Harbour only allows unversioned Requires
Requires:   sailfishsilica-qt5
Requires:   qt5-qtmultimedia
# QML module QtMultimedia (Audio element for playback)
Requires:   qt5-qtdeclarative-import-multimedia
# Lock screen controls (Amber.Mpris): no dependency in the Harbour package -
# the Harbour check rejects "Recommends: qml(Amber.Mpris)" ("not allowed in
# RPM"). The app loads the module through a Loader (see
# qml/harbour-sailwave.qml): if it is missing, the app keeps running
# normally, just without the lock screen integration.
# Chum builds (OBS, _chum defined) keep it as a soft dependency: there the
# module is installed along with the app when it can be resolved. Depend on
# the QML module itself ("qml(Amber.Mpris)", the virtual capability RPM
# generates for every package shipping it) rather than on a package name,
# which differs between repositories/architectures.
%if 0%{?_chum}
Recommends: qml(Amber.Mpris)
%endif
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Multimedia)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(sailfishsecrets)
BuildRequires:  desktop-file-utils

%description
Sailwave is a simple internet radio player for Sailfish OS,
based on the free community station database of radio-browser.info.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
%qmake5_install

desktop-file-install --delete-original \
  --dir %{buildroot}%{_datadir}/applications \
   %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png

%changelog
* Sat Oct 03 2026 Thomas Sappl <thomas.sappl@gmail.com> - 1.0-1
- First public release.
