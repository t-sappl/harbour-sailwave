# SPDX-License-Identifier: GPL-3.0-or-later
#
# Transitional package - OpenRepos only, not for the Jolla Store or Chum.
#
# Up to 1.0.1 Sailwave was packaged as harbour-sailwave; since 1.1 it is
# harbour-sailwave-radio (the old name was taken in the Jolla Store).
# Package managers cannot follow a rename on their own, and the Harbour
# rules forbid "Obsoletes:" in the app package. So harbour-sailwave gets
# one last version without any app files that only requires the new
# package: updating it (e.g. in Storeman) removes the old app and installs
# harbour-sailwave-radio. Favourites, histories and settings are kept - both
# use the same data folders (OrganizationName/ApplicationName in the
# .desktop file are still harbour-sailwave).
#
# Build (noarch, one package for all devices), in this folder:
#   sfdk -c target=SailfishOS-5.1.0.11-aarch64 -c no-fix-version build
# or with rpmbuild on the PC:
#   rpmbuild -bb --define "_topdir $PWD/build" rpm/harbour-sailwave.spec
Name:       harbour-sailwave
Summary:    Transitional package: Sailwave is now harbour-sailwave-radio
Version:    1.1
Release:    1
License:    GPL-3.0-or-later
URL:        https://github.com/t-sappl/harbour-sailwave/
BuildArch:  noarch
Requires:   harbour-sailwave-radio

%description
Sailwave has a new package name: harbour-sailwave-radio. This empty
package only exists so that updating the old harbour-sailwave installs the
new one. Favorites, histories and settings are kept. It can be removed
afterwards.

%prep

%build

%install
mkdir -p %{buildroot}%{_datadir}/doc/%{name}
cat > %{buildroot}%{_datadir}/doc/%{name}/README <<'TXT'
Sailwave is now packaged as harbour-sailwave-radio.
This transitional package can be removed.
TXT

%files
%{_datadir}/doc/%{name}/README

%changelog
* Fri Oct 16 2026 Thomas Sappl <thomas.sappl@gmail.com> - 1.1-1
- Transitional package: installs harbour-sailwave-radio (new package name
  of Sailwave since 1.1). Favorites, histories and settings are kept.
