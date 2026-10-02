import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0

// "Restore favorites": the automatic backup states (newest first) and the
// Sailfish file picker (FilePickerPage, allowed in the Jolla Store) for any
// JSON file. Choosing one opens the confirmation dialog; restoring merges
// (see FavoritesBackup.qml).
Page {
    id: page
    objectName: "restorePage"

    property var versions: []

    Component.onCompleted: versions = appWindow.favoritesBackup.listVersions()

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
        }

        VerticalScrollDecorator {}
    }
}
