import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"
import "../CountryData.js" as CountryData

Page {
    id: settingsPage

    // WebDAV connection test (favourites sync)
    property bool webdavTesting: false
    property string webdavStatus: ""
    objectName: "settingsPage"

    readonly property var historyOptions: [50, 100, 200]

    function countryName(code) {
        var c = CountryData.findCountry(code)
        return c ? CountryData.getLocalizedName(c) : code
    }

    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Settings")
            }

            // ---------------------------------------------------------
            SectionHeader { text: qsTr("Playback") }

            TextSwitch {
                text: qsTr("Play last station on start")
                description: qsTr("Starts playing the most recently heard station as soon as the app opens.")
                checked: appWindow.appSettings.autoplayLastStation
                automaticCheck: false
                onClicked: appWindow.appSettings.autoplayLastStation = !appWindow.appSettings.autoplayLastStation
            }

            TextSwitch {
                text: qsTr("Fade out")
                description: qsTr("Lowers the volume slowly during the last 30 seconds of the sleep timer.")
                checked: appWindow.appSettings.sleepFadeOut
                automaticCheck: false
                onClicked: appWindow.appSettings.sleepFadeOut = !appWindow.appSettings.sleepFadeOut
            }

            // ---------------------------------------------------------
            SectionHeader { text: qsTr("Discover") }

            ValueButton {
                label: qsTr("Home country")
                value: appWindow.appSettings.homeCountry.length > 0
                       ? settingsPage.countryName(appWindow.appSettings.homeCountry)
                       : (appWindow.userCountry.length > 0
                          ? qsTr("Automatic (%1)").arg(settingsPage.countryName(appWindow.userCountry))
                          : qsTr("Automatic"))
                description: qsTr("Used for top stations and recommendations.")
                onClicked: pageStack.push(Qt.resolvedUrl("CountryPickerPage.qml"))
            }

            TextSwitch {
                text: qsTr("Vote when saving a favorite")
                description: qsTr("Automatically votes for the station on radio-browser.info when it is saved "
                                  + "as a favorite. This supports the Radio Browser community. "
                                  + "At most one vote per station and day.")
                checked: appWindow.appSettings.autoVoteOnFavorite
                automaticCheck: false
                onClicked: appWindow.appSettings.autoVoteOnFavorite = !appWindow.appSettings.autoVoteOnFavorite
            }

            // ---------------------------------------------------------
            // Favourites backup and WebDAV sync (I3, I4). The fields only
            // appear when WebDAV is chosen.
            SectionHeader { text: qsTr("Favorites") }

            ComboBox {
                id: storageCombo
                width: parent.width
                label: qsTr("Save favorites")
                description: qsTr("Always also in Documents/Sailwave, with the last 5 states as automatic backups.")
                currentIndex: appWindow.appSettings.favoritesStorage === "webdav" ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Only on this device") }
                    MenuItem { text: qsTr("Device and WebDAV (e.g. Nextcloud)") }
                }
                onCurrentIndexChanged: appWindow.appSettings.favoritesStorage = currentIndex === 1 ? "webdav" : "local"
            }

            Column {
                width: parent.width
                visible: appWindow.appSettings.favoritesStorage === "webdav"

                TextField {
                    width: parent.width
                    text: appWindow.appSettings.webdavUrl
                    label: qsTr("WebDAV URL")
                    placeholderText: "https://example.com/remote.php/dav/files/USER/"
                    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    EnterKey.iconSource: "image://theme/icon-m-enter-next"
                    EnterKey.onClicked: userField.focus = true
                    onTextChanged: {
                        if (text !== appWindow.appSettings.webdavUrl) {
                            appWindow.appSettings.webdavUrl = text
                            // Another server: the next sync checks again
                            appWindow.appSettings.webdavEtag = ""
                            settingsPage.webdavStatus = ""
                        }
                    }
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    wrapMode: Text.Wrap
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: qsTr("Compatible with Nextcloud, ownCloud and standard WebDAV storage.")
                }

                TextField {
                    id: userField
                    width: parent.width
                    text: appWindow.appSettings.webdavUser
                    label: qsTr("User name")
                    placeholderText: qsTr("User name")
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    EnterKey.iconSource: "image://theme/icon-m-enter-next"
                    EnterKey.onClicked: passwordField.focus = true
                    onTextChanged: {
                        if (text !== appWindow.appSettings.webdavUser) {
                            appWindow.appSettings.webdavUser = text
                            appWindow.appSettings.webdavEtag = ""
                            settingsPage.webdavStatus = ""
                        }
                    }
                }

                PasswordField {
                    id: passwordField
                    width: parent.width
                    text: appWindow.appSettings.webdavPassword
                    EnterKey.iconSource: "image://theme/icon-m-enter-close"
                    EnterKey.onClicked: focus = false
                    onTextChanged: {
                        if (text !== appWindow.appSettings.webdavPassword) {
                            appWindow.appSettings.webdavPassword = text
                            settingsPage.webdavStatus = ""
                        }
                    }
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    wrapMode: Text.Wrap
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: qsTr("Recommended: a separate app password from the security settings of "
                               + "Nextcloud instead of the login password.")
                }

                Item { width: parent.width; height: Theme.paddingLarge }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Test connection")
                    enabled: appWindow.appSettings.webdavUrl.length > 0 && !settingsPage.webdavTesting
                    onClicked: {
                        settingsPage.webdavTesting = true
                        settingsPage.webdavStatus = qsTr("Connecting …")
                        appWindow.favoritesBackup.testConnection(function(ok, status) {
                            settingsPage.webdavTesting = false
                            settingsPage.webdavStatus = ok ? qsTr("Connection successful")
                                : (status === 401 || status === 403) ? qsTr("Sign-in failed – check user name and password")
                                : status === 0 ? qsTr("Server not reachable")
                                : qsTr("Connection failed – check the URL")
                            // First successful connection: sync right away
                            if (ok) appWindow.favoritesBackup.syncNow(true)
                        })
                    }
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    visible: settingsPage.webdavStatus.length > 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    text: settingsPage.webdavStatus
                }
            }

            // ---------------------------------------------------------
            SectionHeader { text: qsTr("Privacy") }

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

            ButtonLayout {
                Button {
                    text: qsTr("Clear track history")
                    onClicked: remorse.execute(qsTr("Clearing track history"), function() {
                        appWindow.persistentState.clearTrackHistory()
                        appWindow.trackHistoryUpdated()
                    })
                }
                Button {
                    text: qsTr("Clear station history")
                    onClicked: remorse.execute(qsTr("Clearing station history"), function() {
                        appWindow.persistentState.clearStationHistory()
                        appWindow.stationHistoryUpdated()
                    })
                }
                Button {
                    text: qsTr("Clear cache")
                    onClicked: remorse.execute(qsTr("Clearing cache"), function() {
                        appWindow.persistentState.clearSearchCache()
                        // Station logos and album covers on disk (C++, see networkaccess.h)
                        imageCache.clear()
                    })
                }
            }

            // ---------------------------------------------------------
            // At the very bottom: entry to the separate "About" page
            Item { width: 1; height: Theme.paddingLarge }

            BackgroundItem {
                id: aboutItem
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    text: qsTr("About Sailwave")
                    color: aboutItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                }

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    source: "image://theme/icon-m-right?" + (aboutItem.highlighted ? Theme.highlightColor : Theme.primaryColor)
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
