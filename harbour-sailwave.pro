# SPDX-License-Identifier: GPL-3.0-or-later
TARGET = harbour-sailwave

CONFIG += sailfishapp sailfishapp_i18n
TRANSLATIONS += \
    translations/harbour-sailwave-de.ts \
    translations/harbour-sailwave-fr.ts \
    translations/harbour-sailwave-es.ts

QT += network multimedia

# Sailfish Secrets for the WebDAV password (see src/secretstore.h).
# No own "CONFIG += link_pkgconfig": qmake loads CONFIG features in reverse
# order, so it would be processed before sailfishapp.prf adds its own
# PKGCONFIG entry - and -lsailfishapp would be missing when linking.
# sailfishapp.prf enables link_pkgconfig itself.
PKGCONFIG += sailfishsecrets
INCLUDEPATH += /usr/include/Sailfish

SOURCES += src/harbour-sailwave.cpp \
    src/artcomposer.cpp \
    src/secretstore.cpp \
    src/webdavclient.cpp

HEADERS += \
    src/artcomposer.h \
    src/filehelper.h \
    src/networkaccess.h \
    src/secretstore.h \
    src/webdavclient.h

# Listed only so that Qt Creator shows them in the project tree.
# Installation is handled by CONFIG += sailfishapp (the whole qml/ folder).
OTHER_FILES += rpm/harbour-sailwave.spec \
    harbour-sailwave.desktop \
    qml/harbour-sailwave.qml \
    qml/AppSettings.qml \
    qml/CoverArtCache.qml \
    qml/FavoritesBackup.qml \
    qml/FavoritesStore.qml \
    qml/FilterChip.qml \
    qml/FilterSection.qml \
    qml/MprisIntegration.qml \
    qml/PersistentState.qml \
    qml/PlayerBar.qml \
    qml/RingHint.qml \
    qml/MessageBanner.qml \
    qml/SleepBadge.qml \
    qml/SleepTimer.qml \
    qml/StationDelegate.qml \
    qml/StationIcon.qml \
    qml/TrackPreview.qml \
    qml/CountryData.js \
    qml/RadioApi.js \
    qml/ServerPool.js \
    qml/StationLogo.js \
    qml/TrackText.js \
    qml/cover/CoverPage.qml \
    qml/pages/AboutPage.qml \
    qml/pages/AdvancedSearchFilter.qml \
    qml/pages/AdvancedSearchPage.qml \
    qml/pages/BackupPage.qml \
    qml/pages/CountryPickerPage.qml \
    qml/pages/FavoritesPage.qml \
    qml/pages/GroupNameDialog.qml \
    qml/pages/HomepageDialog.qml \
    qml/pages/RestoreConfirmDialog.qml \
    qml/pages/RestorePage.qml \
    qml/pages/SettingsPage.qml \
    qml/pages/StationInfoPage.qml \
    qml/pages/SyncConflictPage.qml \
    qml/pages/TopStationsPage.qml \
    qml/pages/TrackHistoryPage.qml \
    translations/*.ts

# Install the app icons in the four sizes Sailfish OS expects
icon86.files = icons/86x86/harbour-sailwave.png
icon86.path = /usr/share/icons/hicolor/86x86/apps
icon108.files = icons/108x108/harbour-sailwave.png
icon108.path = /usr/share/icons/hicolor/108x108/apps
icon128.files = icons/128x128/harbour-sailwave.png
icon128.path = /usr/share/icons/hicolor/128x128/apps
icon172.files = icons/172x172/harbour-sailwave.png
icon172.path = /usr/share/icons/hicolor/172x172/apps

INSTALLS += icon86 icon108 icon128 icon172
