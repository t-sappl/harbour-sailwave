// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0

// "Restore favorites": the automatic backup states (newest first), the
// manual backups in Documents/Sailwave (sailwave-backup-*.json, newest
// first), the current file on the WebDAV server (if a server is set up) and the Sailfish
// file picker (FilePickerPage, allowed in the Jolla Store) for any JSON
// file. Choosing one opens the confirmation dialog (replace or add, see
// FavoritesBackup.restore). Only the current server file is offered - older
// versions are not reachable via standard WebDAV (Nextcloud web interface).
Page {
    id: page
    objectName: "restorePage"

    property var versions: []
    property var manualBackups: []

    Component.onCompleted: {
        versions = appWindow.favoritesBackup.listVersions()
        manualBackups = appWindow.favoritesBackup.listManualBackups()
        if (appWindow.favoritesBackup.webdavAvailable) {
            loadRemote()
        }
    }

    // --- WebDAV server ---
    property var remoteData: null
    property string remoteEtag: ""
    // "loading", "ok", "none" (no file yet), "invalid", "auth", "offline", "error"
    property string remoteState: ""

    function loadRemote() {
        remoteState = "loading"
        appWindow.favoritesBackup.fetchRemote(function(data, status, etag) {
            page.remoteData = data
            page.remoteEtag = etag
            page.remoteState = data ? "ok"
                             : status === 200 ? "invalid"
                             : status === 404 ? "none"
                             : (status === 401 || status === 403) ? "auth"
                             : status === 0 ? "offline" : "error"
        })
    }

    function remoteTitle() {
        switch (remoteState) {
        case "loading": return qsTr("Loading …")
        case "ok": return remoteData.savedAt ? formatTime(new Date(remoteData.savedAt).getTime()) : qsTr("Current file")
        case "none": return qsTr("No backup on the server yet")
        case "invalid": return qsTr("The file on the server is not a Sailwave favorites file")
        case "auth": return qsTr("WebDAV sign-in failed")
        case "offline": return qsTr("WebDAV server not reachable")
        default: return qsTr("Could not be loaded from the WebDAV server")
        }
    }

    function formatTime(ms) {
        return Qt.formatDateTime(new Date(ms), Qt.DefaultLocaleShortDate)
    }

    // The picker closes itself after the choice; the confirmation dialog is
    // pushed once this page is active again (no push during an animation)
    property string pendingPath: ""

    onStatusChanged: {
        if (status === PageStatus.Active && pendingPath.length > 0) {
            var path = pendingPath
            pendingPath = ""
            confirm(path)
        }
    }

    Component {
        id: filePicker
        FilePickerPage {
            nameFilters: ["*.json"]
            onSelectedContentPropertiesChanged: page.pendingPath = selectedContentProperties.filePath
        }
    }

    function confirm(path) {
        var data = appWindow.favoritesBackup.readBackup(path)
        if (!data) {
            appWindow.showMessage(qsTr("This file is not a Sailwave favorites backup"))
            return
        }
        pageStack.push(Qt.resolvedUrl("RestoreConfirmDialog.qml"), { backupData: data })
    }

    function confirmRemote() {
        pageStack.push(Qt.resolvedUrl("RestoreConfirmDialog.qml"),
                       { backupData: remoteData, serverEtag: remoteEtag })
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Restore favorites")
            }

            SectionHeader {
                text: qsTr("Automatic backups")
            }

            Repeater {
                model: page.versions
                delegate: BackgroundItem {
                    id: versionItem
                    width: column.width
                    height: Theme.itemSizeMedium
                    onClicked: page.confirm(modelData.path)

                    Column {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            width: parent.width
                            text: page.formatTime(modelData.time)
                            color: versionItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                            truncationMode: TruncationMode.Fade
                        }
                        Label {
                            width: parent.width
                            text: qsTr("%n favorite(s)", "", modelData.favorites) + " · "
                                  + qsTr("%n group(s)", "", modelData.groups)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            truncationMode: TruncationMode.Fade
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.versions.length === 0
                text: qsTr("No automatic backups yet")
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            SectionHeader {
                text: qsTr("Saved backups")
            }

            Repeater {
                model: page.manualBackups
                delegate: BackgroundItem {
                    id: manualItem
                    width: column.width
                    height: Theme.itemSizeMedium
                    onClicked: page.confirm(modelData.path)

                    Column {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            width: parent.width
                            text: page.formatTime(modelData.time)
                            color: manualItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                            truncationMode: TruncationMode.Fade
                        }
                        Label {
                            width: parent.width
                            text: qsTr("%n favorite(s)", "", modelData.favorites) + " · "
                                  + qsTr("%n group(s)", "", modelData.groups)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            truncationMode: TruncationMode.Fade
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.manualBackups.length === 0
                text: qsTr("No saved backups yet")
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            SectionHeader {
                visible: appWindow.favoritesBackup.webdavAvailable
                text: qsTr("WebDAV server")
            }

            BackgroundItem {
                id: remoteItem
                width: column.width
                height: Theme.itemSizeMedium
                visible: appWindow.favoritesBackup.webdavAvailable
                enabled: page.remoteState === "ok"
                onClicked: page.confirmRemote()

                Column {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        width: parent.width
                        text: page.remoteTitle()
                        color: page.remoteState !== "ok" ? Theme.secondaryHighlightColor
                               : remoteItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }
                    Label {
                        width: parent.width
                        visible: page.remoteState === "ok"
                        text: page.remoteData
                              ? qsTr("%n favorite(s)", "", page.remoteData.favorites.length) + " · "
                                + qsTr("%n group(s)", "", (page.remoteData.groups || []).length)
                              : ""
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        truncationMode: TruncationMode.Fade
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: appWindow.favoritesBackup.webdavAvailable
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Only the current file on the server can be restored. Older versions are "
                           + "available in the web interface of Nextcloud (Versions).")
            }

            SectionHeader {
                text: qsTr("Other file")
            }

            BackgroundItem {
                id: chooseItem
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: pageStack.push(filePicker)

                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Choose file …")
                    color: chooseItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
            }

            // Sailjail: the app may read Documents and Downloads only, the
            // picker can also show other folders - say where to put files
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Files from Documents and Downloads")
            }
        }

        VerticalScrollDecorator {}
    }
}
