// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"

// Settings -> Playback: autoplay, sleep timer fade-out, next/previous within
// a favourite group, the favorite tiles page.
Page {
    id: settingsPage
    objectName: "settingsPlaybackPage"

    // Values of AppSettings.tileView, in the order of the combo box
    readonly property var tileViewOptions: ["off", "always", "landscape"]

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Playback")
            }

            TextSwitch {
                text: qsTr("Play last station on start")
                description: qsTr("Starts the last heard station when the app opens.")
                checked: appWindow.appSettings.autoplayLastStation
                automaticCheck: false
                onClicked: appWindow.appSettings.autoplayLastStation = !appWindow.appSettings.autoplayLastStation
            }

            TextSwitch {
                text: qsTr("Fade out")
                description: qsTr("Lowers the volume during the last 30 seconds of the sleep timer.")
                checked: appWindow.appSettings.sleepFadeOut
                automaticCheck: false
                onClicked: appWindow.appSettings.sleepFadeOut = !appWindow.appSettings.sleepFadeOut
            }

            TextSwitch {
                text: qsTr("Stay within favorite group")
                description: qsTr("Next and previous (cover, lock screen, headset) stay in the playing station's group. Off: through all favorites.")
                checked: appWindow.appSettings.loopWithinFavGroup
                automaticCheck: false
                onClicked: appWindow.appSettings.loopWithinFavGroup = !appWindow.appSettings.loopWithinFavGroup
            }

            // Favorite tiles (1.1): an extra ring page with large tiles
            SectionHeader { text: qsTr("Favorite tiles") }

            ComboBox {
                id: tileViewBox
                label: qsTr("Favorite tiles")
                description: qsTr("Large tiles as an extra page left of the start page, e.g. for the car.")
                menu: ContextMenu {
                    MenuItem { text: qsTr("Off") }
                    MenuItem { text: qsTr("Always") }
                    MenuItem { text: qsTr("Only in landscape") }
                }
                Component.onCompleted: {
                    var i = settingsPage.tileViewOptions.indexOf(appWindow.appSettings.tileView)
                    currentIndex = i >= 0 ? i : 0
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        appWindow.appSettings.tileView = settingsPage.tileViewOptions[currentIndex]
                    }
                }
            }

            TextSwitch {
                visible: appWindow.appSettings.tileView !== "off"
                text: qsTr("Open when turning to landscape")
                description: qsTr("Opens the tiles when the phone is turned to landscape.")
                checked: appWindow.appSettings.tileViewAutoOpen
                automaticCheck: false
                onClicked: appWindow.appSettings.tileViewAutoOpen = !appWindow.appSettings.tileViewAutoOpen
            }
        }

        VerticalScrollDecorator {}
    }
}
