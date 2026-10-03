// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// Correcting a station's homepage (many entries on radio-browser.info are
// missing or outdated). The homepage is used for the link on the info page
// and for the station logo fallback (Google favicon).
//
// Accept/cancel work like every Sailfish dialog (header or swipe). "Reset"
// in the pulley menu only puts the homepage from the station database back
// into the field - nothing is stored until the dialog is accepted.
// The caller reads `homepage` in its onAccepted handler.
Dialog {
    id: dialog
    objectName: "homepageDialog"

    // Homepage from radio-browser.info (what "Reset" returns to)
    property string originalHomepage: ""
    // Homepage shown when the dialog opens (the correction, if there is one)
    property string initialHomepage: ""

    // Result: the entered URL without surrounding spaces
    readonly property string homepage: urlField.text.replace(/^\s+|\s+$/g, "")

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        // Only offered if it would change something (no pulley menu with
        // just a disabled entry)
        PullDownMenu {
            visible: dialog.homepage !== dialog.originalHomepage

            MenuItem {
                text: qsTr("Reset")
                onClicked: urlField.text = dialog.originalHomepage
            }
        }

        Column {
            id: column
            width: parent.width

            DialogHeader {
                title: qsTr("Homepage")
            }

            TextField {
                id: urlField
                width: parent.width
                focus: true
                text: dialog.initialHomepage
                label: qsTr("Homepage URL")
                placeholderText: qsTr("https://…")
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: dialog.accept()
            }
        }

        VerticalScrollDecorator {}
    }
}
