import QtQuick 2.6
import Sailfish.Silica 1.0

// The favourites file on the WebDAV server was changed elsewhere since the
// last sync (another device, or a first connection to an existing file).
// The user decides: merge both (recommended, nothing is lost) or keep the
// state of this device (replaces the server file).
Page {
    id: page
    objectName: "syncConflictPage"

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Sync conflict")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: qsTr("The favorites on the WebDAV server were changed elsewhere since the last sync, "
                           + "e.g. on another device.")
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Merge both")
                onClicked: {
                    appWindow.favoritesBackup.resolveMerge()
                    pageStack.pop()
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Recommended. Favorites from the server that are missing here are added, "
                           + "then the result is uploaded. Nothing is deleted.")
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Keep this device's")
                onClicked: {
                    appWindow.favoritesBackup.resolveKeepLocal()
                    pageStack.pop()
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("The file on the server is replaced by the favorites of this device. "
                           + "Nextcloud keeps older versions of the file.")
            }
        }

        VerticalScrollDecorator {}
    }
}
