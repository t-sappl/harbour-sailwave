// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

Rectangle {
    id: playerBar
    width: parent.width

    // Takes all touches on the bar that no control inside handles (e.g. the
    // title preview with fewer than 3 titles, which does not scroll) - they
    // must not reach the page behind the bar and scroll it
    MouseArea {
        anchors.fill: parent
        preventStealing: true
        onWheel: wheel.accepted = true
    }

    // Pages without a PlayerBar: Settings, About, the country picker, the
    // homepage dialog and the favourites management (editing pages)
    readonly property bool isHiddenPage: {
        var page = pageStack.currentPage
        return page && (page.objectName === "settingsPage"
                        || page.objectName === "aboutPage"
                        || page.objectName === "countryPickerPage"
                        || page.objectName === "homepageDialog"
                        || page.objectName === "favoritesPage"
                        || page.objectName === "groupNameDialog"
                        || page.objectName === "restorePage"
                        || page.objectName === "backupPage"
                        || page.objectName === "restoreConfirmDialog"
                        // Sailfish pickers (file picker for restoring)
                        || page.selectedContentProperties !== undefined
                        || page.objectName === "syncConflictPage")
    }

    // Smooth fade in/out via opacity and a Y offset
    opacity: isHiddenPage ? 0 : 1
    enabled: !isHiddenPage

    transform: Translate {
        y: isHiddenPage ? playerBar.height : 0
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    }

    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
    }

    // Background: adaptive colour from the ambience. Hue of the highlight colour, saturation capped (no
    // garish bar with very saturated accents), fixed lightness (the bar
    // stands out the same way with dark or pale accents), then the contrast
    // to the highlight-coloured icons (heart, moon, arrow) is ensured
    // (>= 3:1, pushing the lightness further away if needed). Opaque on
    // purpose: the bar lies on top of scrolling lists. Re-evaluated
    // automatically when the ambience changes.
    color: adaptiveBarColor(Theme.highlightColor, Theme.colorScheme === Theme.LightOnDark)

    readonly property real barMaxSaturation: 0.45
    readonly property real barLightnessDark: 0.17
    readonly property real barLightnessLight: 0.88
    readonly property real barMinIconContrast: 3.0

    function adaptiveBarColor(accent, dark) {
        // RGB (0..1) -> HSL
        var r = accent.r, g = accent.g, b = accent.b
        var max = Math.max(r, g, b), min = Math.min(r, g, b)
        var h = 0, sat = 0, d = max - min
        if (d > 0) {
            var l0 = (max + min) / 2
            sat = l0 > 0.5 ? d / (2 - max - min) : d / (max + min)
            h = max === r ? (g - b) / d + (g < b ? 6 : 0)
              : max === g ? (b - r) / d + 2
              : (r - g) / d + 4
            h /= 6
        }
        sat = Math.min(sat, barMaxSaturation)

        var light = dark ? barLightnessDark : barLightnessLight
        var color = hslToRgb(h, sat, light)
        for (var step = 0; step < 12 && contrast(color, [r, g, b]) < barMinIconContrast; step++) {
            light = dark ? Math.max(0.05, light - 0.02) : Math.min(0.97, light + 0.02)
            color = hslToRgb(h, sat, light)
        }
        return Qt.rgba(color[0], color[1], color[2], 1.0)
    }

    function hslToRgb(h, s, l) {
        if (s === 0) {
            return [l, l, l]
        }
        function channel(p, q, t) {
            if (t < 0) t += 1
            if (t > 1) t -= 1
            if (t < 1 / 6) return p + (q - p) * 6 * t
            if (t < 1 / 2) return q
            if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
            return p
        }
        var q = l < 0.5 ? l * (1 + s) : l + s - l * s
        var p = 2 * l - q
        return [channel(p, q, h + 1 / 3), channel(p, q, h), channel(p, q, h - 1 / 3)]
    }

    // Contrast ratio of two RGB colours (WCAG relative luminance)
    function contrast(a, b) {
        function luminance(c) {
            var lin = c.map(function(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) })
            return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
        }
        var x = luminance(a), y = luminance(b)
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
    }

    // Expanded state (kept when switching pages)
    property bool expanded: false

    // The expanded bar shows the latest titles of the current station and
    // "Open track history" (the same block as on the station info page).
    // The station history is not shown here: it is on the start page.
    // Titles loaded for the scrollable preview (3 visible, see TrackPreview)
    readonly property int previewCount: 30

    // The preview is only rebuilt while it can be seen: expanded and the
    // app in the foreground. Changes in between just mark it as outdated.
    readonly property bool listsOnScreen: expanded && Qt.application.state === Qt.ApplicationActive
    property bool trackListDirty: true

    onListsOnScreenChanged: refreshListsIfNeeded()

    function refreshListsIfNeeded() {
        if (!listsOnScreen || !trackListDirty) {
            return
        }
        trackListDirty = false
        historyModel.clear()
        if (!appWindow || !appWindow.currentStation || !appWindow.currentStation.name) {
            return
        }
        var history = appWindow.persistentState.getTrackHistoryForStation(appWindow.currentStation.name, previewCount)
        for (var i = 0; i < history.length; i++) {
            historyModel.append(history[i])
        }
    }

    ListModel { id: historyModel }

    Connections {
        target: appWindow ? appWindow : null
        ignoreUnknownSignals: true
        onTrackHistoryUpdated: {
            playerBar.trackListDirty = true
            playerBar.refreshListsIfNeeded()
        }
    }

    function openTrackHistory() {
        if (!appWindow || !appWindow.currentStation) {
            return
        }
        expanded = false
        pageStack.push(Qt.resolvedUrl("pages/TrackHistoryPage.qml"), {
            targetStationKey: appWindow.currentStation.stationuuid || appWindow.currentStation.name || ""
        })
    }

    // Sleep timer: the moon button opens a row of durations above the bar
    property bool sleepSelectorOpen: false

    // Collapsing the bar also closes the duration row
    onExpandedChanged: {
        if (!expanded) {
            sleepSelectorOpen = false
        }
    }
    readonly property real sleepRowHeight: Theme.itemSizeSmall
    readonly property var sleepOptions: [5, 10, 15, 30, 45, 60, 90]

    // Height of the collapsed bar (the sleep row only exists while expanded)
    readonly property real collapsedHeight: Theme.itemSizeLarge

    height: {
        var sleep = sleepSelectorOpen ? sleepRowHeight : 0
        if (!expanded) return sleep + collapsedHeight
        return sleep + collapsedHeight + expandedColumn.height
    }

    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    visible: appWindow !== null

    function checkIsFavorite() {
        if (!appWindow || !appWindow.currentStation || !appWindow.currentStation.url) {
            return false
        }
        if (!appWindow.favoritesStore || typeof appWindow.favoritesStore.isFavorite !== "function") {
            return false
        }
        return appWindow.favoritesStore.isFavorite(appWindow.currentStation.url)
    }

    property bool isCurrentFavorite: checkIsFavorite()

    Connections {
        target: (appWindow && appWindow.favoritesStore) ? appWindow.favoritesStore : null
        ignoreUnknownSignals: true
        onFavoritesChanged: {
            playerBar.isCurrentFavorite = playerBar.checkIsFavorite()
        }
    }

    Connections {
        target: appWindow ? appWindow : null
        ignoreUnknownSignals: true
        onCurrentStationChanged: {
            playerBar.isCurrentFavorite = playerBar.checkIsFavorite()
            playerBar.trackListDirty = true
            playerBar.refreshListsIfNeeded()
        }
    }

    Connections {
        target: appWindow ? appWindow.sleepTimer : null
        ignoreUnknownSignals: true
        onExpired: playerBar.sleepSelectorOpen = false
    }

    Separator {
        anchors.top: parent.top
        width: parent.width
        color: Theme.highlightColor
    }

    // --- Sleep timer durations (shown above the main bar) ---
    Item {
        id: sleepRow
        width: parent.width
        anchors.top: parent.top
        height: playerBar.sleepSelectorOpen ? playerBar.sleepRowHeight : 0
        clip: true
        opacity: playerBar.sleepSelectorOpen ? 1.0 : 0.0

        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
        Behavior on opacity { FadeAnimation { duration: 150 } }

        readonly property real cellWidth: (width - 2 * Theme.horizontalPageMargin) / (playerBar.sleepOptions.length + 1)

        Row {
            x: Theme.horizontalPageMargin
            height: playerBar.sleepRowHeight

            Repeater {
                model: playerBar.sleepOptions

                BackgroundItem {
                    id: sleepOption
                    width: sleepRow.cellWidth
                    height: parent.height
                    // Highlight the running duration
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
                        // Remembered as the last used duration
                        appWindow.appSettings.sleepTimerMinutes = modelData
                        appWindow.sleepTimer.start(modelData)
                        playerBar.sleepSelectorOpen = false
                    }
                }
            }

            // Last cell: unit label, or a stop button while the timer runs
            Item {
                width: sleepRow.cellWidth
                height: parent.height

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
                        playerBar.sleepSelectorOpen = false
                    }
                }
            }
        }
    }

    // --- Main bar (compact view) ---
    Item {
        id: mainBar
        width: parent.width
        height: Theme.itemSizeLarge
        anchors.top: sleepRow.bottom

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.horizontalPageMargin
            anchors.rightMargin: Theme.horizontalPageMargin
            spacing: Theme.paddingMedium

            BackgroundItem {
                width: parent.width - (sleepButton.visible ? sleepButton.width + parent.spacing : 0)
                       - expandIcon.width - favoriteButton.width - playButton.width - (parent.spacing * 3)
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                enabled: appWindow && appWindow.currentStation && (appWindow.currentStation.name || appWindow.currentStation.stationuuid)

                onClicked: {
                    if (appWindow && appWindow.currentStation) {
                        appWindow.openStationInfo(appWindow.currentStation)
                    }
                }

                Row {
                    anchors.fill: parent
                    spacing: Theme.paddingMedium

                    Item {
                        id: artBox
                        width: Theme.iconSizeMedium
                        height: Theme.iconSizeMedium
                        anchors.verticalCenter: parent.verticalCenter

                        property string albumUrl: (appWindow && appWindow.currentTrackArtUrl) ? appWindow.currentTrackArtUrl : ""
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
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            visible: opacity > 0
                            opacity: artBox.hasAlbum ? 1.0 : 0.0
                            Behavior on opacity { FadeAnimation { duration: 400 } }
                        }

                        Rectangle {
                            id: logoBadge
                            property real t: artBox.hasAlbum ? 1.0 : 0.0
                            Behavior on t { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }

                            readonly property real badgeFactor: 0.46
                            readonly property real overhang: t * Theme.paddingSmall / 2

                            width: artBox.width * (1.0 - t * (1.0 - badgeFactor))
                            height: width
                            x: artBox.width - width + overhang
                            y: artBox.height - height + overhang
                            radius: width * 0.22 * t
                            color: Qt.rgba(1, 1, 1, t)

                            StationIcon {
                                id: favicon
                                anchors.centerIn: parent
                                iconSize: Theme.iconSizeMedium
                                scale: (logoBadge.width * (1.0 - logoBadge.t * 0.22)) / Theme.iconSizeMedium
                                faviconUrl: (appWindow && appWindow.currentStation && appWindow.currentStation.favicon) ? appWindow.currentStation.favicon : ""
                                homepageUrl: (appWindow && appWindow.currentStation && appWindow.currentStation.homepage) ? appWindow.currentStation.homepage : ""
                                stationName: (appWindow && appWindow.currentStation && appWindow.currentStation.name) ? appWindow.currentStation.name : ""
                                stationuuid: (appWindow && appWindow.currentStation && appWindow.currentStation.stationuuid) ? appWindow.currentStation.stationuuid : ""
                            }
                        }

                        SleepBadge {
                            compact: true
                            x: -Theme.paddingSmall / 2
                            y: -Theme.paddingSmall / 2
                            z: 2
                        }
                    }

                    Column {
                        width: parent.width - artBox.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Label {
                            text: (appWindow && appWindow.currentStation && (appWindow.currentStation.name || appWindow.currentStation.stationuuid)) ? appWindow.currentStation.name : qsTr("No station selected")
                            width: parent.width
                            truncationMode: TruncationMode.Fade
                            color: (appWindow && appWindow.currentStation && (appWindow.currentStation.name || appWindow.currentStation.stationuuid)) ? Theme.primaryColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }

                        Item {
                            id: marqueeContainer
                            width: parent.width
                            height: Theme.fontSizeTiny + Theme.paddingSmall / 2
                            clip: true

                            property string trackText: (appWindow && appWindow.currentTrackDisplay) ? appWindow.currentTrackDisplay : ((appWindow && appWindow.currentStation) ? (appWindow.currentStation.country || "") : "")

                            Label {
                                id: scrollingLabel
                                text: marqueeContainer.trackText
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeTiny
                                x: 0

                                NumberAnimation on x {
                                    id: bounceAnimation
                                    // Paused while the app is in the background
                                    running: (appWindow && appWindow.isPlaying)
                                             && Qt.application.state === Qt.ApplicationActive
                                             && (scrollingLabel.width > marqueeContainer.width)
                                    from: 0
                                    to: -(scrollingLabel.width - marqueeContainer.width + Theme.paddingMedium)
                                    duration: Math.max(3000, (scrollingLabel.width * 30))
                                    loops: Animation.Infinite
                                    easing.type: Easing.InOutQuad
                                }

                                onTextChanged: {
                                    x = 0
                                }
                            }
                        }
                    }
                }
            }

            // Sleep timer button: a moon, highlighted while the timer runs.
            // Drawn like the SleepBadge (light circle + offset circle in the
            // bar colour), so it needs no extra icon file.
            // Only shown while the bar is expanded - in the compact bar the
            // space is needed for the song title.
            MouseArea {
                id: sleepButton
                visible: playerBar.expanded
                // Touch area of a regular IconButton; the moon itself stays small
                width: Theme.itemSizeSmall
                height: Theme.itemSizeSmall
                anchors.verticalCenter: parent.verticalCenter
                enabled: appWindow && appWindow.currentStation && (appWindow.currentStation.name || appWindow.currentStation.stationuuid)
                opacity: enabled ? 1.0 : 0.4
                onClicked: playerBar.sleepSelectorOpen = !playerBar.sleepSelectorOpen

                readonly property color moonColor: (pressed || playerBar.sleepSelectorOpen || appWindow.sleepTimer.active)
                                                   ? Theme.highlightColor : Theme.primaryColor

                Item {
                    anchors.centerIn: parent
                    width: Math.round(Theme.iconSizeSmall * 0.85)
                    height: width
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: sleepButton.moonColor
                    }
                    Rectangle {
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        color: playerBar.color
                        x: parent.width * 0.38
                        y: -parent.height * 0.22
                    }
                }
            }

            IconButton {
                id: expandIcon
                anchors.verticalCenter: parent.verticalCenter
                icon.source: playerBar.expanded ? "image://theme/icon-m-down" : "image://theme/icon-m-up"
                icon.color: playerBar.expanded ? Theme.highlightColor : Theme.secondaryColor
                enabled: appWindow && appWindow.currentStation && (appWindow.currentStation.name || appWindow.currentStation.stationuuid)
                opacity: enabled ? 1.0 : 0.4
                onClicked: playerBar.expanded = !playerBar.expanded
            }

            IconButton {
                id: favoriteButton
                anchors.verticalCenter: parent.verticalCenter
                icon.source: playerBar.isCurrentFavorite ? "image://theme/icon-m-favorite-selected" : "image://theme/icon-m-favorite"
                icon.color: playerBar.isCurrentFavorite ? Theme.highlightColor : Theme.primaryColor
                enabled: appWindow && appWindow.currentStation && (appWindow.currentStation.url || appWindow.currentStation.stationuuid)
                opacity: enabled ? 1.0 : 0.4

                onClicked: {
                    if (appWindow && appWindow.currentStation && appWindow.favoritesStore) {
                        var stationToToggle = {
                            name: appWindow.currentStation.name || "",
                            url: appWindow.currentStation.url || appWindow.currentStation.url_resolved || "",
                            stationuuid: appWindow.currentStation.stationuuid || "",
                            favicon: appWindow.currentStation.favicon || "",
                            country: appWindow.currentStation.country || "",
                            codec: appWindow.currentStation.codec || "",
                            bitrate: appWindow.currentStation.bitrate || 0,
                            votes: appWindow.currentStation.votes || 0,
                            homepage: appWindow.currentStation.homepage || ""
                        };

                        appWindow.favoritesStore.toggle(stationToToggle)
                        playerBar.isCurrentFavorite = playerBar.checkIsFavorite()
                    }
                }
            }

            IconButton {
                id: playButton
                anchors.verticalCenter: parent.verticalCenter
                icon.source: (appWindow && appWindow.isPlaying) ? "image://theme/icon-m-pause" : "image://theme/icon-m-play"
                icon.color: Theme.primaryColor
                enabled: appWindow && appWindow.currentStation && (appWindow.currentStation.name || appWindow.currentStation.stationuuid)
                opacity: enabled ? 1.0 : 0.4

                onClicked: {
                    if (appWindow && typeof appWindow.togglePlayback === "function") {
                        appWindow.togglePlayback()
                    }
                }
            }
        }
    }

    // --- Expandable area ---
    Item {
        id: expandedContent
        width: parent.width
        anchors.top: mainBar.bottom
        anchors.bottom: parent.bottom
        visible: opacity > 0
        opacity: playerBar.expanded ? 1.0 : 0.0
        clip: true

        Behavior on opacity {
            FadeAnimation { duration: 150 }
        }

        Column {
            id: expandedColumn
            width: parent.width

            Separator {
                width: parent.width
                color: Theme.highlightColor
                horizontalAlignment: Qt.AlignHCenter
            }

            SectionHeader {
                text: qsTr("Track history")
            }

            TrackPreview {
                width: parent.width
                visible: historyModel.count > 0
                model: historyModel
                onOpenClicked: playerBar.openTrackHistory()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Theme.itemSizeSmall
                visible: historyModel.count === 0
                verticalAlignment: Text.AlignVCenter
                text: qsTr("No tracks for this station")
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                truncationMode: TruncationMode.Fade
            }
        }
    }
}
