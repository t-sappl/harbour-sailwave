// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"
import "../TrackText.js" as TrackText
import "../RadioApi.js" as RadioApi

Page {
    id: trackHistoryPage

    RemorsePopup { id: clearRemorse }

    property var rawHistory: []
    property var collapsedStations: ({})
    // collapsedStations is a plain JS object, so bindings do not notice when a
    // key changes. Bumping this counter makes them re-evaluate.
    property int collapseVersion: 0

    // While searching, all matching stations are shown expanded; collapsing
    // one only applies to this search (filterCollapsed), the normal states
    // stay as they were
    property var filterCollapsed: ({})

    function isStationCollapsed(key) {
        if (collapseVersion < 0) return false
        return filterText.length > 0 ? filterCollapsed[key] === true : collapsedStations[key] === true
    }

    // --- Search ---
    // filterInput: text of the search field; filterText: the lowercased,
    // trimmed text actually applied (short delay while typing)
    property string filterInput: ""
    property string filterText: ""
    signal filterApplied()

    Timer {
        id: filterTimer
        interval: 250
        onTriggered: {
            var text = trackHistoryPage.filterInput.replace(/^\s+|\s+$/g, "").toLowerCase()
            if (text !== trackHistoryPage.filterText) {
                trackHistoryPage.filterText = text
                trackHistoryPage.filterCollapsed = {}
                trackHistoryPage.rebuildModel()
                trackHistoryPage.filterApplied()
            }
        }
    }
    onFilterInputChanged: filterTimer.restart()

    // A track matches by its title/artist (stream text and iTunes spelling),
    // its genre, or the name of its station
    function trackMatches(track, stationName) {
        if (filterText.length === 0) {
            return true
        }
        var fields = [track.title, track.itunesArtist, track.itunesTitle, track.genre, stationName]
        for (var i = 0; i < fields.length; i++) {
            if (fields[i] && String(fields[i]).toLowerCase().indexOf(filterText) !== -1) {
                return true
            }
        }
        return false
    }

    function visibleTracks(key) {
        var group = groups[key]
        if (!group) {
            return []
        }
        if (filterText.length === 0) {
            return group.tracks
        }
        return group.tracks.filter(function(t) { return trackHistoryPage.trackMatches(t, group.stationName) })
    }

    // Ring navigation (TopStations -> track history -> advanced search -> TopStations).
    // Only the three fixed ring instances from harbour-sailwave.qml have
    // ringMember: true. Copies of this page opened via push() behave like
    // normal stack pages.
    property bool ringMember: false

    // Set when opened from a station's info page ("Open track history"):
    // key of that station's group (stationuuid, or the name for old entries).
    // The page then scrolls to that group and expands it. Such a copy is a
    // normal sub-page on top of the info page, not part of the ring.
    property string targetStationKey: ""
    property bool _scrolledToTarget: false

    // Station logo size: 48 px like the station rows of the other pages
    readonly property real logoSize: Math.round(Theme.iconSizeSmall * 1.2)

    onStatusChanged: {
        if (status === PageStatus.Active) {
            healStrictCheck()
        }
        if (ringMember && status === PageStatus.Active) {
            appWindow.ringPageActivated(trackHistoryPage)
        }
        if (status === PageStatus.Activating) {
            keepTop()
        }
        // Scroll while the page slides in, and once more when it is fully
        // shown: while sliding in, the rows around the target are created and
        // laid out only then (two-line titles get their final height late),
        // so the first position can be off and cut the station header in half
        if (targetStationKey.length > 0 && !_scrolledToTarget) {
            if (status === PageStatus.Activating) {
                scrollToStation(targetStationKey)
            } else if (status === PageStatus.Active) {
                _scrolledToTarget = true
                scrollToStation(targetStationKey)
            }
        }
    }

    // All the way to the top INCLUDING the page header (title, neighbour
    // line, search field). positionViewAtBeginning() and contentY = originY
    // put the first row at the top and push the header out of sight (the
    // title was missing after playing a station from this page).
    function scrollToTop() {
        var headerHeight = listView.headerItem ? listView.headerItem.height : 0
        listView.contentY = listView.headerItem ? listView.headerItem.y : listView.originY - headerHeight
        listView.returnToBounds()
    }

    // The page header grows after the page was created (neighbour line,
    // search field appear when the data and the ring are there) and the view
    // then stayed where it was: the title was scrolled out of sight. As long
    // as the user has not scrolled, the top stays at the top.
    function keepTop() {
        if (!listView.userScrolled && !listView.moving) {
            scrollToTop()
        }
    }

    // Self-healing: with the page header scrolled out by exactly its own
    // height (contentY == originY, the first row at the very top, nobody
    // scrolls there to the pixel) the title is missing. This happened after
    // swiping back to the page (the page stack is rebuilt, the anchor
    // restore ran with stale values) and then stuck, because a list taller
    // than the view regards the position as valid. Checked after activation,
    // restoring the anchor and every end of a movement.
    // After activation (swiping to the page) and after restoring the anchor
    // the first checks are strict: if the title is partly scrolled out
    // (the view is inside the header area) the position goes to the top of
    // the header. Nobody stops there on purpose; this makes the page
    // independent of the exact fault state. Movement ends only use the
    // "stuck" rule below.
    property int healStrictLeft: 0
    function healStrictCheck() {
        healStrictLeft = 3
        healHeaderTimer.restart()
    }

    function healHeader() {
        if (listView.moving || listView.dragging || !listView.headerItem
                || listView.headerItem.height <= 0) {
            return
        }
        // The top of the page is the top edge of the header item (its y in
        // content coordinates) - independent of how originY is defined.
        // The device log showed contentY == originY == -header height at the
        // normal top, so that comparison is no sign of a missing title. The
        // faulty state: the list thinks it is at its beginning
        // (atYBeginning, so it cannot be pulled down) although the header
        // top lies above the view - seen after swiping between the pages.
        var headerTop = listView.headerItem.y
        var strict = healStrictLeft > 0
        if (strict) {
            healStrictLeft--
            if (healStrictLeft > 0) {
                healHeaderTimer.restart()
            }
            if (listView.contentY > headerTop + 3
                    && listView.contentY < headerTop + listView.headerItem.height - 3) {
                console.warn("Sailwave scroll: title partly hidden after activation/restore (contentY "
                             + listView.contentY + ", headerTop " + headerTop + ", header "
                             + listView.headerItem.height + ") - back to the top of the header")
                listView.contentY = headerTop
                return
            }
        }
        if (listView.atYBeginning && listView.contentY > headerTop + 3) {
            console.warn("Sailwave scroll: header was hidden (stuck, contentY " + listView.contentY
                         + ", headerTop " + headerTop + ", originY " + listView.originY
                         + ", header " + listView.headerItem.height
                         + ", topMargin " + listView.topMargin
                         + ", height " + listView.height
                         + ", contentHeight " + listView.contentHeight
                         + ") - scrolling to the top")
            listView.userScrolled = false
            listView.forceLayout()
            listView.positionViewAtBeginning()
            if (listView.contentY > listView.headerItem.y + 3) {
                // wrong bound: set the position directly (no returnToBounds())
                listView.contentY = listView.headerItem.y
            }
        }
    }

    Timer {
        id: healHeaderTimer
        interval: 150
        onTriggered: trackHistoryPage.healHeader()
    }


    // The station's header at the top, with a little space above it so the
    // name is not cut off at the edge. The same for the first station (going
    // to the very top including the search field jerked).
    function scrollToStation(key) {
        var index = headerIndex(key)
        if (index < 0) {
            return
        }
        if (index === 0) {
            // The first station is right below the search field anyway:
            // stay at the top so the page title stays visible
            scrollToTop()
            return
        }
        listView.positionViewAtIndex(index, ListView.Beginning)
        listView.contentY = Math.max(listView.originY, listView.contentY - Theme.paddingLarge)
    }

    // A station started from this page moves to the very top, is expanded
    // and shown (the list scrolls to the top). Only for a tap on a track:
    // new titles arriving while the page is visible still do not re-sort the
    // groups (applyHistoryChanges).
    function moveStationToTop(key) {
        var index = headerIndex(key)
        if (index < 0 || !groups[key]) {
            return
        }
        groupOrder = [key].concat(groupOrder.filter(function(k) { return k !== key }))

        // Rows of this station: its header plus its visible tracks
        var count = 1
        while (index + count < mainListModel.count && !mainListModel.get(index + count).isHeader) {
            count++
        }
        if (index > 0) {
            mainListModel.move(index, 0, count)
        }
        if (isStationCollapsed(key)) {
            if (filterText.length > 0) {
                filterCollapsed[key] = false
            } else {
                collapsedStations[key] = false
            }
            collapseVersion++
            var tracks = visibleTracks(key)
            for (var t = 0; t < tracks.length; t++) {
                mainListModel.insert(1 + t, trackRow(key, tracks[t]))
            }
        }
        scrollToTop()
    }

    // A SilicaListView only creates the rows that are on screen. The former
    // Column + Repeater created every row of the whole history at once
    // (~0.5 s at app start and when swiping here, measured with the QML
    // profiler). Collapsed stations have no track rows in the model at all;
    // expanding/collapsing inserts/removes just that station's rows (the
    // same principle as the sections of the start page).
    SilicaListView {
        id: listView
        anchors.fill: parent
        // Ends above the collapsed PlayerBar (see appWindow.playerBarBaseHeight),
        // in landscape left of the player panel
        anchors.bottomMargin: appWindow.playerBarBaseHeight
        anchors.rightMargin: appWindow.playerPanelWidth
        model: mainListModel
        // No current item: otherwise every rebuild of the model (each search
        // letter) moves the current item and the search field loses focus
        // (same fix as on the advanced search page)
        currentIndex: -1

        property bool userScrolled: false
        onMovementStarted: userScrolled = true
        onMovementEnded: {
            userScrolled = !atYBeginning
            healHeaderTimer.restart()
        }
        Connections {
            target: listView.headerItem
            onHeightChanged: trackHistoryPage.keepTop()
        }

        // Hidden while the history is empty (a pulley menu with only a
        // disabled entry is not allowed by the Sailfish guidelines)
        PullDownMenu {
            visible: rawHistory.length > 0

            MenuItem {
                text: qsTr("Clear track history")
                onClicked: clearRemorse.execute(qsTr("Clearing track history"), function() {
                    appWindow.persistentState.clearTrackHistory()
                    appWindow.trackHistoryUpdated()
                })
            }
        }

        header: Column {
            width: listView.width

            PageHeader {
                title: qsTr("Track history")
            }

            RingNeighbours { ringPage: trackHistoryPage }

            // Filters by title, artist, genre and station
            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search track history")
                inputMethodHints: Qt.ImhNoAutoUppercase
                visible: trackHistoryPage.rawHistory.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: {
                    wasFocused = false
                    focus = false
                }
                onTextChanged: trackHistoryPage.filterInput = text

                // Safety net: if a rebuild of the list still takes the focus
                // while typing, give it back
                property bool wasFocused: false
                onActiveFocusChanged: if (activeFocus) wasFocused = true
                Connections {
                    target: trackHistoryPage
                    onFilterApplied: if (searchField.wasFocused && !searchField.activeFocus) searchField.forceActiveFocus()
                }
            }
        }

        // Space for the expanded part of the PlayerBar as part of the content
        // (not bottomMargin - see TopStationsPage for the Qt 5.6 reason)
        footer: Item {
            width: listView.width
            height: appWindow.playerBarOverlap + Theme.paddingLarge
        }

        // Only while expanding/collapsing a station, see toggleStation
        add: Transition {
            enabled: trackHistoryPage.sectionAnimating
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        }
        remove: Transition {
            enabled: trackHistoryPage.sectionAnimating
            NumberAnimation { property: "opacity"; to: 0; duration: 150 }
        }
        displaced: Transition {
            enabled: trackHistoryPage.sectionAnimating
            NumberAnimation { property: "y"; duration: 200; easing.type: Easing.InOutQuad }
        }

        delegate: Item {
            id: rowItem
            width: listView.width
            height: model.isHeader ? headerItem.height : trackItem.height

            // Station header (press and hold: show the station / delete its tracks)
            ListItem {
                id: headerItem
                width: parent.width
                // Grows with the heading (large system font)
                // paddingLarge of air above: separates the stations from each other
                contentHeight: Math.max(Theme.itemSizeSmall, stationTitle.height + Theme.paddingSmall) + Theme.paddingLarge
                visible: model.isHeader === true

                onClicked: trackHistoryPage.toggleStation(model.stationKey)

                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Play")
                        onClicked: {
                            var pg = trackHistoryPage.groups[model.stationKey]
                            var pt = pg && pg.tracks.length > 0 ? pg.tracks[0] : {}
                            appWindow.playStation({
                                stationuuid: model.stationuuid || "",
                                name: model.stationName || "",
                                url: pt.url || "",
                                url_resolved: pt.url_resolved || "",
                                favicon: model.favicon || "",
                                homepage: model.homepage || ""
                            })
                        }
                    }
                    MenuItem {
                        text: qsTr("Show station")
                        onClicked: {
                            // The stream addresses are in the station's tracks
                            var g = trackHistoryPage.groups[model.stationKey]
                            var tr = g && g.tracks.length > 0 ? g.tracks[0] : {}
                            appWindow.openStationInfo({
                                stationuuid: model.stationuuid || "",
                                name: model.stationName || "",
                                url: tr.url || "",
                                url_resolved: tr.url_resolved || "",
                                favicon: model.favicon || "",
                                homepage: model.homepage || ""
                            })
                        }
                    }
                    MenuItem {
                        // Stations that only send text (news): no recording
                        text: appWindow.isRecordingOff(trackHistoryPage.stationOf(model.stationKey))
                              ? qsTr("Record this station again")
                              : qsTr("Do not record this station")
                        onClicked: {
                            var st = trackHistoryPage.stationOf(model.stationKey)
                            appWindow.setRecordingOff(st, !appWindow.isRecordingOff(st))
                        }
                    }
                    MenuItem {
                        text: qsTr("Delete tracks of this station")
                        onClicked: {
                            // Captured now: the delegate may be gone before the countdown ends
                            var key = model.stationKey
                            var target = trackHistoryPage
                            headerItem.remorseAction(qsTr("Deleting tracks"), function() {
                                target.deleteStationTracks(key)
                            })
                        }
                    }
                }

                Row {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: headerItem.contentHeight - Theme.paddingLarge
                    anchors.topMargin: Theme.paddingLarge
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.rightMargin: Theme.horizontalPageMargin
                    spacing: Theme.paddingMedium

                    StationIcon {
                        id: stationIcon
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: trackHistoryPage.logoSize
                        stationuuid: model.stationuuid || ""
                        faviconUrl: model.favicon || ""
                        homepageUrl: model.homepage || ""
                        stationName: model.stationName || ""
                    }

                    // Left-aligned right next to the logo (a SectionHeader is
                    // right-aligned and pulled the name far away from it)
                    Label {
                        id: stationTitle
                        // Display only: stationName stays the stored key
                        text: RadioApi.displayName(model.stationName) || qsTr("Unknown station")
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - stationIcon.width - collapsibleIcon.width - (parent.spacing * 2)
                        horizontalAlignment: Text.AlignLeft
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeMedium
                        color: headerItem.highlighted ? Theme.primaryColor : Theme.highlightColor
                    }

                    FoldChevron {
                        id: collapsibleIcon
                        anchors.verticalCenter: parent.verticalCenter
                        collapsed: trackHistoryPage.isStationCollapsed(model.stationKey)
                        tint: headerItem.highlighted ? Theme.primaryColor : Theme.highlightColor
                    }
                }
            }

            // Track entry
            ListItem {
                id: trackItem
                width: parent.width
                contentHeight: Math.max(Theme.itemSizeSmall, textColumn.height + 2 * Theme.paddingMedium,
                                         trackContent.hasArt ? trackContent.artSize + 2 * Theme.paddingSmall : 0)
                visible: model.isHeader === false

                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Delete")
                        onClicked: {
                            // Capture now: the delegate may be gone before the countdown ends
                            var stationKey = model.stationKey
                            var stationName = model.stationName
                            var timestamp = model.timestamp
                            var target = trackHistoryPage
                            trackItem.remorseAction(qsTr("Deleting entry"), function() {
                                target.deleteTrack(stationKey, stationName, timestamp)
                            })
                        }
                    }
                }

                onClicked: {
                    // Captured first: moving the rows recreates this delegate
                    var stationKey = model.stationKey
                    appWindow.playStation({
                        stationuuid: model.stationuuid || "",
                        name: model.stationName || "",
                        url: model.url || "",
                        url_resolved: model.url_resolved || "",
                        favicon: model.favicon || "",
                        homepage: model.homepage || ""
                    })
                    trackHistoryPage.moveStationToTop(stationKey)
                }

                // The text starts exactly under the station name (one edge for
                // all rows, with or without cover); the cover, if there is one,
                // sits at the right edge.
                Item {
                    id: trackContent
                    anchors {
                        fill: parent
                        leftMargin: Theme.horizontalPageMargin + trackHistoryPage.logoSize + Theme.paddingMedium
                        rightMargin: Theme.horizontalPageMargin
                    }

                    // Space is reserved as soon as the track has a cover URL
                    // (no jumping while the image loads)
                    readonly property bool hasArt: !model.isHeader && !!model.artUrl
                    readonly property real artSize: Math.round(Theme.iconSizeMedium * 1.25)

                    Item {
                        id: trackArt
                        visible: trackContent.hasArt
                        width: trackContent.artSize
                        height: width
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.fill: parent
                            // Small iTunes variant for the list thumbnail; only
                            // rows on screen exist, so only their covers load
                            source: model.isHeader ? "" : trackHistoryPage.thumbnailUrl(model.artUrl)
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            opacity: status === Image.Ready ? 1.0 : 0.0
                            Behavior on opacity { FadeAnimation {} }
                        }
                    }

                    Column {
                        id: textColumn
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (trackContent.hasArt ? trackArt.width + Theme.paddingMedium : 0)
                        spacing: Theme.paddingSmall / 2

                        readonly property var parts: TrackText.parts({
                            title: model.trackTitle,
                            itunesArtist: model.itunesArtist,
                            itunesTitle: model.itunesTitle
                        })

                        Label {
                            id: titleLabel
                            width: parent.width
                            text: textColumn.parts.title || qsTr("Unknown track")
                            color: trackItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            // Explicit height from the line count: in Qt 5.6 a
                            // wrapped + elided Text does not reliably update its
                            // implicitHeight when the text changes later (iTunes
                            // title via setProperty), so a two-line title
                            // overlapped the row below
                            height: Math.max(1, Math.min(lineCount, 2)) * titleMetrics.height
                            FontMetrics {
                                id: titleMetrics
                                font: titleLabel.font
                            }
                        }

                        Label {
                            width: parent.width
                            // "Artist · Genre · Time"
                            text: TrackText.details(textColumn.parts.artist, model.genre,
                                                    formatRelativeTime(model.timestamp))
                            color: trackItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            truncationMode: TruncationMode.Fade
                        }
                    }
                }

            }
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: mainListModel.count === 0 && rawHistory.length > 0 && trackHistoryPage.filterText.length > 0
            text: qsTr("No matching tracks")
        }

        ViewPlaceholder {
            enabled: mainListModel.count === 0 && rawHistory.length === 0
            text: qsTr("No track history available")
            hintText: appWindow.appSettings.trackHistoryEnabled
                      ? qsTr("Played tracks will be automatically saved here.")
                      : qsTr("Saving the track history is turned off in Settings.")
        }
    }

    property bool sectionAnimating: false

    Timer {
        id: sectionAnimationTimer
        interval: 300
        onTriggered: trackHistoryPage.sectionAnimating = false
    }

    ListModel {
        id: mainListModel
    }

    Component.onCompleted: {
        // Opened for a specific station: its group starts expanded
        if (targetStationKey.length > 0) {
            collapsedStations[targetStationKey] = false
        }
        loadHistory()
    }

    // The history changes with every new song. While the page is not on
    // screen, only remember that and rebuild the list when it is shown
    // again (the page lives for the whole session as part of the ring).
    property bool historyDirty: false

    readonly property bool onScreen: status === PageStatus.Active || status === PageStatus.Activating

    onOnScreenChanged: {
        if (onScreen && historyDirty) {
            loadHistory()
        }
    }

    Connections {
        target: appWindow
        onTrackHistoryUpdated: {
            if (trackHistoryPage._ownUpdate) {
                return
            }
            if (trackHistoryPage.onScreen) {
                // Visible: only apply what changed - a rebuild would jump to
                // the top and move the playing station's group up
                trackHistoryPage.applyHistoryChanges()
            } else {
                trackHistoryPage.historyDirty = true
            }
        }
    }

    // iTunes cover URLs are stored in 600x600 (PlayerBar, app cover and lock
    // screen use that size). The list thumbnails only need a small image,
    // and iTunes serves other sizes under the same URL pattern.
    function thumbnailUrl(url) {
        return url ? String(url).replace("600x600bb", "200x200bb") : ""
    }

    function loadHistory() {
        historyDirty = false
        if (appWindow && appWindow.persistentState && typeof appWindow.persistentState.getTrackHistory === "function") {
            rawHistory = appWindow.persistentState.getTrackHistory(appWindow.appSettings.trackHistoryLimit)
        } else {
            rawHistory = []
        }
        rebuildModel()
    }

    // Grouped history: stationKey -> { stationName, stationuuid, favicon,
    // homepage, tracks: [...] }, plus the order of the groups. Kept so that
    // expanding a station can insert its rows without rebuilding the list.
    property var groups: ({})
    property var groupOrder: []

    function rebuildModel() {
        var newGroups = {}
        var order = []

        for (var i = 0; i < rawHistory.length; i++) {
            var item = rawHistory[i]
            var key = item.stationuuid || item.stationName || "unknown"
            if (!newGroups[key]) {
                newGroups[key] = {
                    stationName: item.stationName || qsTr("Unknown station"),
                    stationuuid: item.stationuuid || "",
                    favicon: item.favicon || "",
                    homepage: item.homepage || "",
                    tracks: []
                }
                order.push(key)
            }

            // The same title twice in a row (stream re-sent its metadata)
            var stationTracks = newGroups[key].tracks
            if (stationTracks.length === 0 || stationTracks[stationTracks.length - 1].title !== item.title) {
                stationTracks.push(item)
            }
        }

        groups = newGroups
        groupOrder = order

        mainListModel.clear()
        for (var g = 0; g < order.length; g++) {
            var k = order[g]
            // Default: the first two stations expanded, the others collapsed
            if (collapsedStations[k] === undefined) {
                collapsedStations[k] = (g >= 2)
            }
            var tracks = visibleTracks(k)
            // While searching, stations without a matching track are hidden
            if (filterText.length > 0 && tracks.length === 0) {
                continue
            }
            mainListModel.append(headerRow(k))
            if (!isStationCollapsed(k)) {
                for (var t = 0; t < tracks.length; t++) {
                    mainListModel.append(trackRow(k, tracks[t]))
                }
            }
        }
        collapseVersion++
    }

    // All rows have the same roles (ListModel requirement)
    function headerRow(key) {
        var group = groups[key]
        return {
            isHeader: true,
            stationKey: key,
            stationName: group.stationName,
            stationuuid: group.stationuuid,
            favicon: group.favicon,
            homepage: group.homepage,
            trackTitle: "",
            artUrl: "",
            genre: "",
            itunesArtist: "",
            itunesTitle: "",
            timestamp: 0,
            url: "",
            url_resolved: ""
        }
    }

    function trackRow(key, track) {
        var group = groups[key]
        return {
            isHeader: false,
            stationKey: key,
            stationName: group.stationName,
            stationuuid: group.stationuuid,
            favicon: group.favicon,
            homepage: track.homepage || group.homepage,
            trackTitle: track.title || "",
            artUrl: track.artUrl || "",
            genre: track.genre || "",
            itunesArtist: track.itunesArtist || "",
            itunesTitle: track.itunesTitle || "",
            timestamp: track.timestamp || 0,
            url: track.url || "",
            url_resolved: track.url_resolved || ""
        }
    }

    function headerIndex(key) {
        for (var i = 0; i < mainListModel.count; i++) {
            var row = mainListModel.get(i)
            if (row.isHeader && row.stationKey === key) {
                return i
            }
        }
        return -1
    }

    // Expanding/collapsing: inserts or removes only this station's rows
    function toggleStation(key) {
        var index = headerIndex(key)
        if (index < 0 || !groups[key]) {
            return
        }
        var collapse = !isStationCollapsed(key)
        if (filterText.length > 0) {
            filterCollapsed[key] = collapse
        } else {
            collapsedStations[key] = collapse
        }
        collapseVersion++

        sectionAnimating = true
        sectionAnimationTimer.restart()

        if (collapse) {
            var count = 0
            while (index + 1 + count < mainListModel.count && !mainListModel.get(index + 1 + count).isHeader) {
                count++
            }
            if (count > 0) {
                mainListModel.remove(index + 1, count)
            }
        } else {
            var tracks = visibleTracks(key)
            for (var t = 0; t < tracks.length; t++) {
                mainListModel.insert(index + 1 + t, trackRow(key, tracks[t]))
            }
        }
    }

    // Deleting one entry: removes just that row (and the station header if
    // it was the station's last entry) instead of rebuilding the list, so the
    // scroll position stays where it is
    property bool _ownUpdate: false

    function deleteTrack(key, stationName, timestamp) {
        appWindow.persistentState.deleteTrackHistoryItem(stationName, timestamp)

        for (var i = 0; i < mainListModel.count; i++) {
            var row = mainListModel.get(i)
            if (!row.isHeader && row.stationKey === key && row.timestamp === timestamp) {
                mainListModel.remove(i)
                break
            }
        }
        rawHistory = rawHistory.filter(function(h) {
            return !(h.stationName === stationName && h.timestamp === timestamp)
        })
        var group = groups[key]
        if (group) {
            group.tracks = group.tracks.filter(function(tr) { return tr.timestamp !== timestamp })
            if (group.tracks.length === 0) {
                var index = headerIndex(key)
                if (index >= 0) {
                    mainListModel.remove(index)
                }
                delete groups[key]
                groupOrder = groupOrder.filter(function(k) { return k !== key })
            }
        }

        // Tell the PlayerBar, the info page and other copies of this page,
        // but do not rebuild this list again
        _ownUpdate = true
        appWindow.trackHistoryUpdated()
        _ownUpdate = false
    }

    // Deleting all tracks of one station: the station's group disappears
    // from the list (as the last single entry does); other stations and the
    // scroll position stay as they are
    // The station of a group as an object (id and stream address of its newest track)
    function stationOf(key) {
        var g = groups[key]
        var t = g && g.tracks.length > 0 ? g.tracks[0] : {}
        return { stationuuid: (g && g.stationuuid) || "", url: t.url || "" }
    }

    function deleteStationTracks(key) {
        var group = groups[key]
        if (!group) {
            return
        }
        var names = {}
        for (var t = 0; t < group.tracks.length; t++) {
            names[group.tracks[t].stationName || ""] = true
        }
        for (var n in names) {
            appWindow.persistentState.deleteTrackHistoryOfStation(n)
        }
        // Rows of the group (header and tracks) from the end
        for (var i = mainListModel.count - 1; i >= 0; i--) {
            if (mainListModel.get(i).stationKey === key) {
                mainListModel.remove(i)
            }
        }
        rawHistory = rawHistory.filter(function(h) { return groupKeyOf(h) !== key })
        delete groups[key]
        groupOrder = groupOrder.filter(function(k) { return k !== key })

        _ownUpdate = true
        appWindow.trackHistoryUpdated()
        _ownUpdate = false
    }

    // --- Updates while the page is visible ---
    // Compares the stored history with the one shown (by station name +
    // timestamp) and changes only the affected rows: new titles go to the
    // top of their station's group, a new station gets a group at the very
    // top, found covers update their row, dropped entries are removed. The
    // order of the groups stays as it is; it is sorted again the next time
    // the page is opened (loadHistory). An emptied history is rebuilt.
    // Exception: a station started from this page moves to the top right
    // away (moveStationToTop).
    function historyKey(h) {
        return (h.stationName || "") + "|" + h.timestamp
    }

    function applyHistoryChanges() {
        var fresh = appWindow.persistentState.getTrackHistory(appWindow.appSettings.trackHistoryLimit)
        if (fresh.length === 0 || rawHistory.length === 0) {
            loadHistory()
            return
        }

        var oldByKey = {}
        for (var i = 0; i < rawHistory.length; i++) {
            oldByKey[historyKey(rawHistory[i])] = rawHistory[i]
        }
        var freshByKey = {}
        for (var j = 0; j < fresh.length; j++) {
            freshByKey[historyKey(fresh[j])] = fresh[j]
        }

        sectionAnimating = true
        sectionAnimationTimer.restart()

        // Removed (deleted elsewhere, or dropped by the history length)
        for (var r = 0; r < rawHistory.length; r++) {
            if (!freshByKey[historyKey(rawHistory[r])]) {
                removeTrackFromView(rawHistory[r])
            }
        }
        // Added: oldest first, so the newest ends up on top
        for (var a = fresh.length - 1; a >= 0; a--) {
            var entry = fresh[a]
            var old = oldByKey[historyKey(entry)]
            if (!old) {
                addTrackToView(entry)
            } else if ((old.artUrl || "") !== (entry.artUrl || "")
                       || (old.genre || "") !== (entry.genre || "")
                       || (old.itunesTitle || "") !== (entry.itunesTitle || "")) {
                updateTrackArt(entry)
            }
        }
        rawHistory = fresh
    }

    function groupKeyOf(h) {
        return h.stationuuid || h.stationName || "unknown"
    }

    function addTrackToView(h) {
        var key = groupKeyOf(h)
        var group = groups[key]
        if (!group) {
            groups[key] = {
                stationName: h.stationName || qsTr("Unknown station"),
                stationuuid: h.stationuuid || "",
                favicon: h.favicon || "",
                homepage: h.homepage || "",
                tracks: [h]
            }
            groupOrder.unshift(key)
            // The station that is playing right now: open
            collapsedStations[key] = false
            collapseVersion++
            // While searching, only shown if the track matches
            if (trackMatches(h, groups[key].stationName)) {
                mainListModel.insert(0, headerRow(key))
                mainListModel.insert(1, trackRow(key, h))
            }
            return
        }
        // The same title again (stream re-sent its metadata): not shown twice
        if (group.tracks.length > 0 && group.tracks[0].title === h.title) {
            return
        }
        group.tracks.unshift(h)
        if (!trackMatches(h, group.stationName) || isStationCollapsed(key)) {
            return
        }
        var index = headerIndex(key)
        if (index < 0) {
            // Station hidden by the search so far: now it has a match
            mainListModel.insert(0, headerRow(key))
            mainListModel.insert(1, trackRow(key, h))
        } else {
            mainListModel.insert(index + 1, trackRow(key, h))
        }
    }

    function removeTrackFromView(h) {
        var key = groupKeyOf(h)
        for (var i = 0; i < mainListModel.count; i++) {
            var row = mainListModel.get(i)
            if (!row.isHeader && row.stationKey === key && row.timestamp === h.timestamp) {
                mainListModel.remove(i)
                break
            }
        }
        var group = groups[key]
        if (!group) {
            return
        }
        group.tracks = group.tracks.filter(function(tr) { return tr.timestamp !== h.timestamp })
        if (group.tracks.length === 0) {
            var index = headerIndex(key)
            if (index >= 0) {
                mainListModel.remove(index)
            }
            delete groups[key]
            groupOrder = groupOrder.filter(function(k) { return k !== key })
        }
    }

    function updateTrackArt(h) {
        var key = groupKeyOf(h)
        var group = groups[key]
        if (group) {
            for (var t = 0; t < group.tracks.length; t++) {
                if (group.tracks[t].timestamp === h.timestamp) {
                    group.tracks[t].artUrl = h.artUrl
                    group.tracks[t].genre = h.genre
                    group.tracks[t].itunesArtist = h.itunesArtist
                    group.tracks[t].itunesTitle = h.itunesTitle
                }
            }
        }
        for (var i = 0; i < mainListModel.count; i++) {
            var row = mainListModel.get(i)
            if (!row.isHeader && row.stationKey === key && row.timestamp === h.timestamp) {
                mainListModel.setProperty(i, "artUrl", h.artUrl || "")
                mainListModel.setProperty(i, "genre", h.genre || "")
                mainListModel.setProperty(i, "itunesArtist", h.itunesArtist || "")
                mainListModel.setProperty(i, "itunesTitle", h.itunesTitle || "")
                break
            }
        }
    }

    function formatRelativeTime(ms) {
        if (!ms) return ""
        var diffSec = Math.floor((Date.now() - ms) / 1000)

        if (diffSec < 60) {
            return qsTr("Just now")
        }
        var diffMin = Math.floor(diffSec / 60)
        if (diffMin < 60) {
            return diffMin === 1 ? qsTr("1 minute ago") : qsTr("%1 minutes ago").arg(diffMin)
        }
        var diffHours = Math.floor(diffMin / 60)
        if (diffHours < 24) {
            return diffHours === 1 ? qsTr("1 hour ago") : qsTr("%1 hours ago").arg(diffHours)
        }
        var diffDays = Math.floor(diffHours / 24)
        return diffDays === 1 ? qsTr("1 day ago") : qsTr("%1 days ago").arg(diffDays)
    }
}
