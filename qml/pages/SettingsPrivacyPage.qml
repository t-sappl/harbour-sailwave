// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"

// Settings -> Privacy: what is sent to other services, the track history,
// clearing history and cache.
Page {
    id: settingsPage
    objectName: "settingsPrivacyPage"

    readonly property var historyOptions: [50, 100, 200]

    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Privacy")
            }

            SectionHeader { text: qsTr("Sent to other services") }

            TextSwitch {
                text: qsTr("Song details from iTunes")
                description: qsTr("Looks up the cover, album and genre of the current song via the "
                                  + "iTunes Search API. The song title and artist are sent to Apple. "
                                  + "When off, only the station logo is shown.")
                checked: appWindow.appSettings.trackArtEnabled
                automaticCheck: false
                onClicked: appWindow.appSettings.trackArtEnabled = !appWindow.appSettings.trackArtEnabled
            }

            TextSwitch {
                text: qsTr("Load missing logos via Google")
                description: qsTr("If a station has no usable logo, the domain of its homepage is sent to "
                                  + "Google's favicon service to get the website's icon. "
                                  + "When off, a letter is shown instead.")
                checked: appWindow.appSettings.googleLogoFallback
                automaticCheck: false
                onClicked: appWindow.appSettings.googleLogoFallback = !appWindow.appSettings.googleLogoFallback
            }

            SectionHeader { text: qsTr("On this device") }

            TextSwitch {
                text: qsTr("Save track history")
                description: qsTr("Keeps a list of the songs played. Stored only on this device.")
                checked: appWindow.appSettings.trackHistoryEnabled
                automaticCheck: false
                onClicked: appWindow.appSettings.trackHistoryEnabled = !appWindow.appSettings.trackHistoryEnabled
            }

            ComboBox {
                label: qsTr("Track history length")
                enabled: appWindow.appSettings.trackHistoryEnabled
                menu: ContextMenu {
                    Repeater {
                        model: settingsPage.historyOptions
                        MenuItem { text: qsTr("%n tracks", "", modelData) }
                    }
                }
                Component.onCompleted: {
                    var i = settingsPage.historyOptions.indexOf(appWindow.appSettings.trackHistoryLimit)
                    currentIndex = i >= 0 ? i : 1
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        appWindow.appSettings.trackHistoryLimit = settingsPage.historyOptions[currentIndex]
                    }
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            Flow {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                ActionPill {
                    text: qsTr("Clear track history")
                    onClicked: remorse.execute(qsTr("Clearing track history"), function() {
                        appWindow.persistentState.clearTrackHistory()
                        appWindow.trackHistoryUpdated()
                    })
                }
                ActionPill {
                    text: qsTr("Clear station history")
                    onClicked: remorse.execute(qsTr("Clearing station history"), function() {
                        appWindow.persistentState.clearStationHistory()
                        appWindow.stationHistoryUpdated()
                    })
                }
                ActionPill {
                    text: qsTr("Clear cache")
                    onClicked: remorse.execute(qsTr("Clearing cache"), function() {
                        appWindow.persistentState.clearSearchCache()
                        // Station logos and album covers on disk (C++, see networkaccess.h)
                        imageCache.clear()
                    })
                }
            }

            Item { width: 1; height: Theme.paddingLarge }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("The detection of the home country and the automatic votes (radio-browser.info) are set under Discover.")
            }
        }

        VerticalScrollDecorator {}
    }
}
