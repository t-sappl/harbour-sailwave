// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// Name for a new favourite group, or a new name for an existing one.
// Accept/cancel like every Sailfish dialog; accepting is only possible with
// a name. The caller reads groupName in its onAccepted handler.
Dialog {
    id: dialog
    objectName: "groupNameDialog"

    // Header title, set by the caller ("New group" / "Rename group")
    property string title: ""
    property string initialName: ""

    readonly property string groupName: nameField.text.replace(/^\s+|\s+$/g, "")

    canAccept: groupName.length > 0

    Column {
        width: parent.width

        DialogHeader {
            title: dialog.title
        }

        TextField {
            id: nameField
            width: parent.width
            focus: true
            text: dialog.initialName
            label: qsTr("Group name")
            placeholderText: qsTr("Group name")
            EnterKey.enabled: dialog.canAccept
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: dialog.accept()
        }
    }
}
