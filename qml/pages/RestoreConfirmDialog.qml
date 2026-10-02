import QtQuick 2.6
import Sailfish.Silica 1.0

// Confirmation before restoring a backup: date, content, the restore mode
// and what it would change.
//  - "Replace current favorites" (default): favourites and groups become
//    exactly the backup - what one expects from "restore".
//  - "Add missing favorites only": nothing is deleted or regrouped.
// Either way the current state is saved as a backup state first.
Dialog {
    id: dialog
    objectName: "restoreConfirmDialog"

    property var backupData

    readonly property bool replaceMode: modeCombo.currentIndex === 0
    readonly property int favoriteCount: backupData ? backupData.favorites.length : 0
    readonly property int groupCount: backupData && backupData.groups ? backupData.groups.length : 0
    readonly property var changes: backupData ? appWindow.favoritesBackup.previewRestore(backupData)
                                              : ({ add: 0, remove: 0, regroup: 0, groupsAdd: 0, groupsRemove: 0 })

    function changeLines() {
        var lines = []
        if (changes.add > 0) lines.push(qsTr("%n favorite(s) will be added", "", changes.add))
        if (replaceMode && changes.remove > 0) lines.push(qsTr("%n favorite(s) will be removed", "", changes.remove))
        if (replaceMode && changes.regroup > 0) lines.push(qsTr("%n favorite(s) will change group", "", changes.regroup))
        if (changes.groupsAdd > 0) lines.push(qsTr("%n group(s) will be added", "", changes.groupsAdd))
        if (replaceMode && changes.groupsRemove > 0) lines.push(qsTr("%n group(s) will be removed", "", changes.groupsRemove))
        return lines.length > 0 ? lines.join("\n") : qsTr("No changes")
    }

    onAccepted: {
        var replace = replaceMode
        appWindow.favoritesBackup.restore(backupData, function(count) {
            appWindow.showMessage(replace ? qsTr("Favorites restored")
                                          : qsTr("%n favorite(s) added", "", count))
        }, replace ? "replace" : "merge")
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: qsTr("Restore favorites")
            }

            DetailItem {
                label: qsTr("Saved")
                value: dialog.backupData && dialog.backupData.savedAt
                       ? Qt.formatDateTime(new Date(dialog.backupData.savedAt), Qt.DefaultLocaleShortDate) : ""
            }
            DetailItem {
                label: qsTr("Content")
                value: qsTr("%n favorite(s)", "", dialog.favoriteCount) + " · "
                       + qsTr("%n group(s)", "", dialog.groupCount)
            }

            ComboBox {
                id: modeCombo
                width: parent.width
                label: qsTr("Restore mode")
                currentIndex: 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Replace current favorites") }
                    MenuItem { text: qsTr("Add missing favorites only") }
                }
            }

            SectionHeader {
                text: qsTr("Changes")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: dialog.changeLines()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: dialog.replaceMode
                      ? qsTr("Favorites and groups are set exactly to the backup. The current state "
                             + "is saved as a backup first.")
                      : qsTr("Missing favorites and groups are added. Favorites that already exist keep "
                             + "their group and position. Nothing is deleted. The current state is saved "
                             + "as a backup first.")
            }
        }

        VerticalScrollDecorator {}
    }
}
