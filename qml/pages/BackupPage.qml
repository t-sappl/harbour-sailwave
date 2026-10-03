// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Share 1.0

// "Back up favorites": format (JSON backup or M3U playlist) and target.
//  - This device: Documents/Sailwave, next to the automatically updated
//    sailwave-favorites.json, as sailwave-backup-<date_time>.json or
//    sailwave-playlist-<date_time>.m3u - one place for everything, the name
//    tells the kind of file. (A free folder picker was rejected: it shows
//    folders the sandbox may not write to.)
//  - Share: the same dated file, then the system's sharing menu
//    (Sailfish.Share, allowed in the Jolla Store) - mail, Bluetooth, ...
//  - WebDAV server: only if a server is set up in the settings; uploads
//    right away (fixed names in "Sailwave/")
Page {
    id: page
    objectName: "backupPage"

    readonly property string format: formatCombo.currentIndex === 1 ? "m3u" : "json"
    property bool uploading: false

    function report(path) {
        var name = path.substring(path.lastIndexOf("/") + 1)
        if (path.length > 0) {
            appWindow.showMessage(page.format === "m3u"
                                  ? qsTr("Playlist saved as %1").arg(name)
                                  : qsTr("Backup saved as %1").arg(name))
        } else {
            appWindow.showMessage(page.format === "m3u"
                                  ? qsTr("Playlist could not be saved")
                                  : qsTr("Backup could not be saved"))
        }
    }

    // Saves the dated file (it stays as a backup) and opens the sharing menu
    function shareFile() {
        var path = appWindow.favoritesBackup.backupToDevice(format)
        if (path.length === 0) {
            report(path)
            return
        }
        shareAction.mimeType = format === "m3u" ? "audio/x-mpegurl" : "application/json"
        shareAction.resources = [path]
        shareAction.trigger()
    }

    ShareAction {
        id: shareAction
        title: qsTr("Share favorites")
    }

    function saveToServer() {
        uploading = true
        appWindow.favoritesBackup.backupToWebdav(format, function(ok, status) {
            page.uploading = false
            appWindow.showMessage(ok ? qsTr("Saved on the WebDAV server")
                                  : (status === 401 || status === 403) ? qsTr("WebDAV sign-in failed")
                                  : status === 0 ? qsTr("WebDAV server not reachable")
                                  : qsTr("Could not be saved on the WebDAV server"))
        })
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Back up favorites")
            }

            ComboBox {
                id: formatCombo
                width: parent.width
                label: qsTr("Format")
                currentIndex: 0
                description: currentIndex === 1
                             ? qsTr("For other radio and media player apps.")
                             : qsTr("Can be restored on this or another device.")
                menu: ContextMenu {
                    MenuItem { text: qsTr("Backup (JSON)") }
                    MenuItem { text: qsTr("Playlist (M3U)") }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("The current state is saved automatically as sailwave-favorites.json. "
                           + "Here you create an additional file with date and time.")
            }

            SectionHeader {
                text: qsTr("Save to")
            }

            // --- This device ---
            BackgroundItem {
                id: deviceItem
                width: parent.width
                height: Theme.itemSizeMedium
                onClicked: page.report(appWindow.favoritesBackup.backupToDevice(page.format))

                Column {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        width: parent.width
                        text: qsTr("This device")
                        color: deviceItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }
                    Label {
                        width: parent.width
                        text: "Documents/Sailwave/" + (page.format === "m3u" ? "sailwave-playlist-…" : "sailwave-backup-…")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        truncationMode: TruncationMode.Fade
                    }
                }
            }

            // --- Share ---
            BackgroundItem {
                id: shareItem
                width: parent.width
                height: Theme.itemSizeMedium
                onClicked: page.shareFile()

                Column {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        width: parent.width
                        text: qsTr("Share")
                        color: shareItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }
                    Label {
                        width: parent.width
                        text: qsTr("Saves the file on this device and opens the share menu")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        truncationMode: TruncationMode.Fade
                    }
                }
            }

            // --- WebDAV server (only if set up) ---
            BackgroundItem {
                id: serverItem
                width: parent.width
                height: Theme.itemSizeMedium
                visible: appWindow.favoritesBackup.webdavAvailable
                enabled: !page.uploading
                onClicked: page.saveToServer()

                Column {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin - (busy.running ? busy.width + Theme.paddingMedium : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        width: parent.width
                        text: qsTr("WebDAV server")
                        color: serverItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }
                    Label {
                        width: parent.width
                        text: appWindow.appSettings.webdavUrl
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        truncationMode: TruncationMode.Fade
                    }
                }

                BusyIndicator {
                    id: busy
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    size: BusyIndicatorSize.Small
                    running: page.uploading
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
