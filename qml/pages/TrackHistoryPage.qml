import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"
import "../TrackText.js" as TrackText

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

    onStatusChanged: {
        if (ringMember && status === PageStatus.Active) {
            appWindow.ringPageActivated(trackHistoryPage)
        }
        // Scroll while the page slides in
        if (status === PageStatus.Activating && targetStationKey.length > 0 && !_scrolledToTarget) {
            _scrolledToTarget = true
            scrollToStation(targetStationKey)
        }
    }

    function scrollToStation(key) {
        var index = headerIndex(key)
        if (index >= 0) {
            listView.positionViewAtIndex(index, ListView.Beginning)
        }
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
        model: mainListModel
        // No current item: otherwise every rebuild of the model (each search
        // letter) moves the current item and the search field loses focus
        // (same fix as on the advanced search page)
        currentIndex: -1

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

        // Space for the PlayerBar as part of the content (not bottomMargin -
        // see TopStationsPage for the Qt 5.6 reason)
        footer: Item {
            width: listView.width
            height: appWindow.playerBarHeight + Theme.paddingLarge
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

            // Station header
            BackgroundItem {
                id: headerItem
                width: parent.width
                height: Theme.itemSizeSmall
                visible: model.isHeader === true

                onClicked: trackHistoryPage.toggleStation(model.stationKey)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.rightMargin: Theme.horizontalPageMargin
                    spacing: Theme.paddingMedium

                    StationIcon {
                        id: stationIcon
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: Theme.iconSizeSmall
                        stationuuid: model.stationuuid || ""
                        faviconUrl: model.favicon || ""
                        homepageUrl: model.homepage || ""
                        stationName: model.stationName || ""
                    }

                    SectionHeader {
                        text: model.stationName || qsTr("Unknown station")
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - stationIcon.width - collapsibleIcon.width - (parent.spacing * 2)
                    }

                    IconButton {
                        id: collapsibleIcon
                        anchors.verticalCenter: parent.verticalCenter
                        icon.source: trackHistoryPage.isStationCollapsed(model.stationKey) ? "image://theme/icon-m-right" : "image://theme/icon-m-down"
                        enabled: false
                    }
                }
            }

            // Track entry
            ListItem {
                id: trackItem
                width: parent.width
                contentHeight: Math.max(Theme.itemSizeSmall, textColumn.height + 2 * Theme.paddingMedium)
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
                    appWindow.playStation({
                        stationuuid: model.stationuuid || "",
                        name: model.stationName || "",
                        url: model.url || "",
                        url_resolved: model.url_resolved || "",
                        favicon: model.favicon || "",
                        homepage: model.homepage || ""
                    })
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.horizontalPageMargin + Theme.iconSizeSmall + Theme.paddingMedium
                    anchors.rightMargin: Theme.horizontalPageMargin
                    spacing: Theme.paddingMedium

                    Item {
                        id: trackArt
                        width: Theme.iconSizeSmall
                        height: width
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
                        width: parent.width - trackArt.width - parent.spacing
                        spacing: Theme.paddingSmall / 2

                        readonly property var parts: TrackText.parts({
                            title: model.trackTitle,
                            itunesArtist: model.itunesArtist,
                            itunesTitle: model.itunesTitle
                        })

                        Label {
                            width: parent.width
                            text: textColumn.parts.title || qsTr("Unknown track")
                            color: trackItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
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

    // --- Updates while the page is visible ---
    // Compares the stored history with the one shown (by station name +
    // timestamp) and changes only the affected rows: new titles go to the
    // top of their station's group, a new station gets a group at the very
    // top, found covers update their row, dropped entries are removed. The
    // order of the groups stays as it is; it is sorted again the next time
    // the page is opened (loadHistory). An emptied history is rebuilt.
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
