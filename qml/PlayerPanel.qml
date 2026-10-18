// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// Player in landscape (1.1): a column on the right instead of the PlayerBar
// at the bottom - in landscape the height is short and the bar would cover a
// large part of it. Always "expanded": big cover, station and song, large
// previous / play / next buttons (also useful in the car), favourite heart,
// sleep timer and the latest titles of the station. The pages end left of
// it (appWindow.playerPanelWidth), the ring swiping stays on the left.
//
// Prototype: the logic is duplicated from PlayerBar.qml (favourite state,
// sleep durations, track preview, cover with logo badge). If the panel is
// kept, the shared parts move into a common component.
Rectangle {
    id: panel

    // Shown in landscape with a station, not on the pages that hide the
    // player (settings, favourites page, ...) - see appWindow.playerPanelWidth
    property bool shown: false
    // Same adaptive colour as the PlayerBar
    property color barColor: Theme.highlightDimmerColor

    color: barColor
    visible: shown || slide.x < width

    // Slides in from the right edge
    transform: Translate {
        id: slide
        x: panel.shown ? 0 : panel.width
        Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    }

    // Takes all touches no control inside handles (they must not reach the
    // page behind the panel)
    MouseArea {
        anchors.fill: parent
        preventStealing: true
        onWheel: wheel.accepted = true
    }

    readonly property bool hasStation: appWindow && appWindow.currentStation
                                       && (appWindow.currentStation.name || appWindow.currentStation.stationuuid)

    // --- Favourite state (as in PlayerBar) ---
    function checkIsFavorite() {
        if (!appWindow || !appWindow.currentStation || !appWindow.currentStation.url) {
            return false
        }
        return appWindow.favoritesStore.isFavorite(appWindow.currentStation.url)
    }

    property bool isCurrentFavorite: checkIsFavorite()

    Connections {
        target: appWindow.favoritesStore
        ignoreUnknownSignals: true
        onFavoritesChanged: panel.isCurrentFavorite = panel.checkIsFavorite()
    }

    Connections {
        target: appWindow
        ignoreUnknownSignals: true
        onCurrentStationChanged: {
            panel.isCurrentFavorite = panel.checkIsFavorite()
            panel.trackListDirty = true
            panel.refreshListsIfNeeded()
        }
        onTrackHistoryUpdated: {
            panel.trackListDirty = true
            panel.refreshListsIfNeeded()
        }
    }

    function toggleFavorite() {
        var st = appWindow.currentStation
        if (!st) {
            return
        }
        appWindow.favoritesStore.toggle({
            name: st.name || "",
            url: st.url || st.url_resolved || "",
            stationuuid: st.stationuuid || "",
            favicon: st.favicon || "",
            country: st.country || "",
            codec: st.codec || "",
            bitrate: st.bitrate || 0,
            votes: st.votes || 0,
            homepage: st.homepage || ""
        })
        isCurrentFavorite = checkIsFavorite()
    }

    // --- Latest titles: only rebuilt while the panel can be seen ---
    readonly property int previewCount: 30
    readonly property bool listsOnScreen: shown && Qt.application.state === Qt.ApplicationActive
    property bool trackListDirty: true

    onListsOnScreenChanged: refreshListsIfNeeded()

    function refreshListsIfNeeded() {
        if (!listsOnScreen || !trackListDirty) {
            return
        }
        trackListDirty = false
        historyModel.clear()
        if (!appWindow.currentStation || !appWindow.currentStation.name) {
            return
        }
        var history = appWindow.persistentState.getTrackHistoryForStation(appWindow.currentStation.name, previewCount)
        for (var i = 0; i < history.length; i++) {
            historyModel.append(history[i])
        }
    }

    ListModel { id: historyModel }

    function openTrackHistory() {
        if (!appWindow.currentStation) {
            return
        }
        pageStack.push(Qt.resolvedUrl("pages/TrackHistoryPage.qml"), {
            targetStationKey: appWindow.currentStation.stationuuid || appWindow.currentStation.name || ""
        })
    }

    // --- Sleep timer durations ---
    property bool sleepSelectorOpen: false
    readonly property var sleepOptions: [5, 10, 15, 30, 45, 60, 90]

    onShownChanged: if (!shown) sleepSelectorOpen = false

    Connections {
        target: appWindow.sleepTimer
        ignoreUnknownSignals: true
        onExpired: panel.sleepSelectorOpen = false
    }

    // Thin highlight line on the left edge (the PlayerBar has one on top)
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(1, Math.round(Theme.pixelRatio))
        color: Theme.highlightColor
        opacity: 0.6
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge
        clip: true

        Column {
            id: column
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            spacing: Theme.paddingMedium

            Item { width: 1; height: Theme.paddingLarge }

            // --- Cover: album cover with the logo as a badge, otherwise the
            // logo (same behaviour as the PlayerBar, just larger) ---
            Item {
                id: artBox
                // Large, but leaves room for title and buttons below
                width: Math.min(column.width, Math.round(panel.height * 0.36))
                height: width
                anchors.horizontalCenter: parent.horizontalCenter

                property string albumUrl: appWindow.currentTrackArtUrl ? appWindow.currentTrackArtUrl : ""
                property string shownAlbumUrl: ""
                property bool hasAlbum: false

                onAlbumUrlChanged: {
                    if (albumUrl.length === 0) {
                        hasAlbum = false
                    } else if (albumUrl === shownAlbumUrl && albumImage.status === Image.Ready) {
                        hasAlbum = true
                    } else {
                        shownAlbumUrl = albumUrl
                    }
                }

                BackgroundItem {
                    anchors.fill: parent
                    enabled: panel.hasStation
                    onClicked: appWindow.openStationInfo(appWindow.currentStation)
                }

                Image {
                    id: albumImage
                    anchors.fill: parent
                    source: artBox.shownAlbumUrl
                    onStatusChanged: {
                        if (status === Image.Ready) {
                            artBox.hasAlbum = artBox.albumUrl.length > 0
                        } else if (status === Image.Error) {
                            artBox.hasAlbum = false
                        }
                    }
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    visible: opacity > 0
                    opacity: artBox.hasAlbum ? 1.0 : 0.0
                    Behavior on opacity { FadeAnimation { duration: 400 } }
                }

                // Logo: fills the box without a cover, light badge bottom
                // right with a cover (animated like in the PlayerBar)
                Rectangle {
                    id: logoBadge
                    property real t: artBox.hasAlbum ? 1.0 : 0.0
                    Behavior on t { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }

                    readonly property real badgeFactor: 0.3
                    readonly property real overhang: t * Theme.paddingSmall

                    width: artBox.width * (1.0 - t * (1.0 - badgeFactor))
                    height: width
                    x: artBox.width - width + overhang
                    y: artBox.height - height + overhang
                    radius: width * 0.22 * t
                    color: Qt.rgba(1, 1, 1, t)

                    StationIcon {
                        anchors.centerIn: parent
                        // Fixed size, scaled (as in the PlayerBar): a changing
                        // iconSize would reload the logo during the animation
                        iconSize: artBox.width
                        scale: (logoBadge.width * (1.0 - logoBadge.t * 0.22)) / artBox.width
                        faviconUrl: (appWindow.currentStation && appWindow.currentStation.favicon) ? appWindow.currentStation.favicon : ""
                        homepageUrl: (appWindow.currentStation && appWindow.currentStation.homepage) ? appWindow.currentStation.homepage : ""
                        stationName: (appWindow.currentStation && appWindow.currentStation.name) ? appWindow.currentStation.name : ""
                        stationuuid: (appWindow.currentStation && appWindow.currentStation.stationuuid) ? appWindow.currentStation.stationuuid : ""
                    }
                }

                SleepBadge {
                    x: -Theme.paddingSmall
                    y: -Theme.paddingSmall
                    z: 2
                }
            }

            // --- Station (tap: station info) and current song ---
            BackgroundItem {
                width: parent.width
                height: titleColumn.height + Theme.paddingSmall
                enabled: panel.hasStation
                onClicked: appWindow.openStationInfo(appWindow.currentStation)

                Column {
                    id: titleColumn
                    width: parent.width

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: panel.hasStation ? appWindow.currentStation.name : ""
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        truncationMode: TruncationMode.Fade
                        color: Theme.primaryColor
                    }

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: appWindow.currentTrackDisplay ? appWindow.currentTrackDisplay
                              : (appWindow.currentStation ? (appWindow.currentStation.country || "") : "")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }

            // --- Buttons: heart, previous, play/pause, next, moon ---
            Row {
                id: controls
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.max(0, Math.min(Theme.paddingLarge,
                                             (column.width - favoriteButton.width - prevButton.width - playButton.width
                                              - nextButton.width - moonButton.width) / 4))

                IconButton {
                    id: favoriteButton
                    anchors.verticalCenter: parent.verticalCenter
                    icon.source: panel.isCurrentFavorite ? "image://theme/icon-m-favorite-selected" : "image://theme/icon-m-favorite"
                    icon.color: panel.isCurrentFavorite ? Theme.highlightColor : Theme.primaryColor
                    enabled: panel.hasStation
                    onClicked: panel.toggleFavorite()
                }

                // Previous/next favourite - same rule as the cover action and
                // the lock screen (appWindow.canPlayNextFavorite)
                IconButton {
                    id: prevButton
                    anchors.verticalCenter: parent.verticalCenter
                    icon.source: "image://theme/icon-m-previous"
                    enabled: appWindow.canPlayNextFavorite
                    opacity: enabled ? 1.0 : 0.4
                    onClicked: appWindow.playPrevFavorite()
                }

                IconButton {
                    id: playButton
                    anchors.verticalCenter: parent.verticalCenter
                    icon.source: appWindow.isPlaying ? "image://theme/icon-l-pause" : "image://theme/icon-l-play"
                    enabled: panel.hasStation
                    onClicked: appWindow.togglePlayback()
                }

                IconButton {
                    id: nextButton
                    anchors.verticalCenter: parent.verticalCenter
                    icon.source: "image://theme/icon-m-next"
                    enabled: appWindow.canPlayNextFavorite
                    opacity: enabled ? 1.0 : 0.4
                    onClicked: appWindow.playNextFavorite()
                }

                // Sleep timer: moon drawn like in the PlayerBar
                MouseArea {
                    id: moonButton
                    width: Theme.itemSizeSmall
                    height: Theme.itemSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: panel.hasStation
                    onClicked: panel.sleepSelectorOpen = !panel.sleepSelectorOpen

                    readonly property color moonColor: (pressed || panel.sleepSelectorOpen || appWindow.sleepTimer.active)
                                                       ? Theme.highlightColor : Theme.primaryColor

                    Item {
                        anchors.centerIn: parent
                        width: Math.round(Theme.iconSizeSmall * 0.85)
                        height: width
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: moonButton.moonColor
                        }
                        Rectangle {
                            width: parent.width
                            height: parent.height
                            radius: width / 2
                            color: panel.color
                            x: parent.width * 0.38
                            y: -parent.height * 0.22
                        }
                    }
                }
            }

            // --- Sleep durations (below the buttons while open) ---
            Flow {
                width: parent.width
                visible: panel.sleepSelectorOpen
                spacing: 0

                Repeater {
                    model: panel.sleepOptions

                    BackgroundItem {
                        id: sleepOption
                        width: Theme.itemSizeSmall * 1.2
                        height: Theme.itemSizeSmall
                        readonly property bool current: appWindow.sleepTimer.active
                                                        && modelData === appWindow.appSettings.sleepTimerMinutes

                        Label {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: sleepOption.current
                            color: (sleepOption.current || sleepOption.highlighted) ? Theme.highlightColor : Theme.primaryColor
                        }

                        onClicked: {
                            appWindow.appSettings.sleepTimerMinutes = modelData
                            appWindow.sleepTimer.start(modelData)
                            panel.sleepSelectorOpen = false
                        }
                    }
                }

                Item {
                    width: Theme.itemSizeSmall * 1.2
                    height: Theme.itemSizeSmall

                    Label {
                        anchors.centerIn: parent
                        visible: !appWindow.sleepTimer.active
                        text: qsTr("min")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }

                    IconButton {
                        anchors.centerIn: parent
                        visible: appWindow.sleepTimer.active
                        icon.source: "image://theme/icon-m-clear"
                        onClicked: {
                            appWindow.sleepTimer.cancel()
                            panel.sleepSelectorOpen = false
                        }
                    }
                }
            }

            // --- Latest titles of the station ---
            SectionHeader {
                // SectionHeader brings its own page margins - undo them here
                x: -Theme.horizontalPageMargin
                width: column.width + 2 * Theme.horizontalPageMargin
                text: qsTr("Track history")
            }

            TrackPreview {
                x: -Theme.horizontalPageMargin
                width: column.width + 2 * Theme.horizontalPageMargin
                visible: historyModel.count > 0
                model: historyModel
                onOpenClicked: panel.openTrackHistory()
            }

            Label {
                width: parent.width
                height: Theme.itemSizeSmall
                visible: historyModel.count === 0
                verticalAlignment: Text.AlignVCenter
                text: qsTr("No tracks for this station")
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                truncationMode: TruncationMode.Fade
            }
        }

        VerticalScrollDecorator {}
    }
}
