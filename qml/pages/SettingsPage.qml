// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"
import "../CountryData.js" as CountryData

// Settings: a short main page with one entry per subject and a summary of
// its current values; the settings themselves are on sub-pages (as in
// Sailcast). Before 1.2 this was one long page. "About Sailwave" is in the
// pulley and, with the version, at the bottom.
Page {
    id: settingsPage
    objectName: "settingsPage"

    // The summary of the backup is re-read when the page is shown again
    property double lastBackupTime: 0
    function readLastBackup() {
        lastBackupTime = Math.max(appWindow.favoritesBackup.lastStateTime(),
                                  appWindow.favoritesBackup.lastManualTime())
    }
    onStatusChanged: if (status === PageStatus.Activating) readLastBackup()
    Component.onCompleted: readLastBackup()

    function join(parts) {
        return parts.filter(function(p) { return p !== "" }).join(" · ")
    }

    function countryName(code) {
        var c = CountryData.findCountry(code)
        return c ? CountryData.getLocalizedName(c) : code
    }

    function tileName(mode) {
        return mode === "always" ? qsTr("always")
             : mode === "landscape" ? qsTr("only in landscape") : qsTr("off")
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("About Sailwave")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
        }

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Settings")
            }

            SettingsEntry {
                title: qsTr("Playback")
                summary: settingsPage.join([
                    appWindow.appSettings.autoplayLastStation ? qsTr("plays last station on start") : "",
                    appWindow.appSettings.loopWithinFavGroup ? qsTr("next/previous within group") : "",
                    qsTr("tiles: %1").arg(settingsPage.tileName(appWindow.appSettings.tileView))])
                target: Qt.resolvedUrl("SettingsPlaybackPage.qml")
            }

            SettingsEntry {
                title: qsTr("Discover")
                summary: settingsPage.join([
                    appWindow.appSettings.homeCountry.length > 0
                        ? settingsPage.countryName(appWindow.appSettings.homeCountry)
                        : (appWindow.userCountry.length > 0
                           ? qsTr("Automatic (%1)").arg(settingsPage.countryName(appWindow.userCountry))
                           : qsTr("Automatic")),
                    appWindow.appSettings.autoVoteOnFavorite ? qsTr("votes for new favorites") : qsTr("no automatic votes")])
                target: Qt.resolvedUrl("SettingsDiscoverPage.qml")
            }

            SettingsEntry {
                title: qsTr("Backup and sync")
                summary: settingsPage.join([
                    appWindow.favoritesBackup.webdavEnabled ? qsTr("WebDAV sync")
                        : (appWindow.favoritesBackup.webdavAvailable ? qsTr("WebDAV backups") : qsTr("on this device")),
                    qsTr("last backup %1").arg(settingsPage.lastBackupTime > 0
                        ? Qt.formatDateTime(new Date(settingsPage.lastBackupTime), Qt.DefaultLocaleShortDate)
                        : qsTr("never"))])
                target: Qt.resolvedUrl("SettingsBackupPage.qml")
            }

            SettingsEntry {
                title: qsTr("Privacy")
                summary: {
                    var services = []
                    if (appWindow.appSettings.trackArtEnabled) services.push("iTunes")
                    if (appWindow.appSettings.googleLogoFallback) services.push("Google")
                    return settingsPage.join([
                        services.length > 0 ? qsTr("sends data to %1").arg(services.join(" + "))
                                            : qsTr("no data sent to Apple or Google"),
                        appWindow.appSettings.trackHistoryEnabled ? qsTr("track history on") : qsTr("track history off")])
                }
                target: Qt.resolvedUrl("SettingsPrivacyPage.qml")
            }

            Item { width: 1; height: Theme.paddingLarge * 2 }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: "Sailwave " + appWindow.appVersion
            }

            ActionPill {
                kind: "secondary"
                x: Theme.horizontalPageMargin
                text: qsTr("About Sailwave")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
        }

        VerticalScrollDecorator {}
    }
}
