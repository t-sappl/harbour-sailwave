Name:       harbour-sailwave

Summary:    Internet radio player for Sailfish OS
Version:    0.1
Release:    7
License:    GPLv3
URL:        https://example.com/harbour-sailwave
Source0:    %{name}-%{version}.tar.bz2

Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   qt5-qtmultimedia
# Depend on the QML module itself rather than on a specific package name
# (amber-mpris-qt5 is not named the same in every repository/architecture and
# could not be resolved on some devices). "qml(Amber.Mpris)" is the virtual
# capability RPM generates automatically for every package that ships this
# QML module - the more robust variant other Sailfish apps use as well.
# Deliberately "Recommends" (soft dependency) instead of "Requires": if the
# module is available it is installed along with the app; if it cannot be
# resolved anywhere, it does NOT block installing the app itself. As an extra
# safeguard the app loads the module through a Loader anyway (see
# qml/harbour-sailwave.qml): if it is missing, the app keeps running normally,
# just without the lock screen integration.
Recommends: qml(Amber.Mpris)
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Multimedia)
BuildRequires:  pkgconfig(Qt5Network)
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
