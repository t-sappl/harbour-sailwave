# SPDX-License-Identifier: GPL-3.0-or-later
# Package name since 1.1: harbour-sailwave was already taken (Jolla Store).
# Up to 1.0.1 the package was harbour-sailwave; OpenRepos users move over
# with the transitional package in migration/ (see there).
Name:       harbour-sailwave-radio

Summary:    Internet radio player for Sailfish OS
Version:    1.1
Release:    1
License:    GPL-3.0-or-later
URL:        https://github.com/t-sappl/harbour-sailwave/
Source0:    %{name}-%{version}.tar.bz2

# Unversioned on purpose: Harbour only allows unversioned Requires
Requires:   sailfishsilica-qt5
Requires:   qt5-qtmultimedia
# QML module QtMultimedia (Audio element for playback)
Requires:   qt5-qtdeclarative-import-multimedia
# Lock screen, headset and car controls (MPRIS). The module is not
# installed on every device, so the package pulls it in. Harbour allows
# "qml(Amber.Mpris)" as an unversioned Requires (allowed_requires.conf of
# the Harbour RPM validator) - only "Recommends:" is rejected. Depend on the
# QML module itself (the virtual capability RPM generates for every package
# shipping it) rather than on a package name. The app still loads the
# module through a Loader (qml/harbour-sailwave.qml), so it would keep
# running without it.
Requires:   qml(Amber.Mpris)
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Multimedia)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(sailfishsecrets)
BuildRequires:  desktop-file-utils
# lrelease for the translations (CONFIG += sailfishapp_i18n) - the SDK has
# it, a clean OBS/Chum build environment only with this
BuildRequires:  qt5-qttools-linguist

%description
Sailwave brings thousands of internet radio stations to Sailfish OS - from
the community database radio-browser.info, in a native Silica interface:
top stations matched to your listening, advanced search, favorites with
groups, track history with album covers, sleep timer, lock screen controls,
backups and optional WebDAV sync. No account, no tracking, no ads.

%if 0%{?_chum}
Title: Sailwave
Type: desktop-application
DeveloperName: Thomas Sappl
Categories:
 - Audio
 - AudioVideo
 - Player
Custom:
  Repo: https://github.com/t-sappl/harbour-sailwave
PackageIcon: https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/icons/172x172/harbour-sailwave-radio.png
Screenshots:
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/start-page.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/player.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/track-history.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/advanced-search.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/settings.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/cover.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/lock-screen.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/backup.png
Links:
  Homepage: https://github.com/t-sappl/harbour-sailwave
  Bugtracker: https://github.com/t-sappl/harbour-sailwave/issues
%endif

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
* Fri Oct 16 2026 Thomas Sappl <thomas.sappl@gmail.com> - 1.1-1
- New package name harbour-sailwave-radio (harbour-sailwave was taken).
  Favorites, histories and settings are kept; OpenRepos users get the new
  package through a last update of harbour-sailwave.
- Landscape: player panel on the right with large previous/play/next
  buttons, the pages next to it.
- Favorite tiles: large favorite tiles as an extra page left of the start
  page - always, or only in landscape; optionally opened when turning the
  phone (e.g. in the car).
- Lock screen, headset and car controls: the package now installs the
  system module Amber.Mpris, which was missing on some devices.
- Next and previous also work while paused, and only appear when there is
  another favorite to switch to.
- Setting renamed to "Stay within favorite group"; its value is now kept
  after a restart.
- WebDAV: a bare server address (e.g. https://cloud.example.com) is
  completed to the Nextcloud WebDAV folder of the user.
* Sun Oct 11 2026 Thomas Sappl <thomas.sappl@gmail.com> - 1.0.1-1
- New Feature: Added Next and Previous control buttons on the lock screen and cover page.
- New Setting: Added option to restrict Next and Previous media actions to the current favorite group instead of cycling through all favorites.
* Sat Oct 03 2026 Thomas Sappl <thomas.sappl@gmail.com> - 1.0-1
- First public release.
