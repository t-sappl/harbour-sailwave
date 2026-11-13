// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"
import "../RadioApi.js" as RadioApi

Page {
    id: page

    readonly property string apiBase: RadioApi.apiUrl("stations/")
    property string userCountry: ""
    property bool searchMode: false
    // The search field of the list header (set by the field itself)
    property var searchFieldItem: null

    // Error / empty states (shown below the list, see footer)
    property bool topLoadFailed: false   // top stations could not be loaded at all
    property bool searchFailed: false    // the last search could not reach the server
    property bool searchDone: false      // a search has finished (for "no results")
    property string searchFieldText: ""
    property int searchRequestId: 0
    property int minSearchLength: 2

    property int topLoadId: 0

    property bool historyCollapsed: true

    // --- Order frozen while the start page is on screen ---
    // Playing a station reorders the station history and re-scores the top
    // stations. While the page is visible (and the app in the foreground)
    // the order of these sections stays: new stations appear, stations that
    // became favourites (or were removed) disappear, but nothing moves under
    // the finger. The new order is applied as soon as the page is off screen
    // (another page on top, or the app in the background) - same principle
    // as the track history ("re-sorted on the next opening").
    readonly property bool orderFrozen: status !== PageStatus.Inactive
                                        && Qt.application.state === Qt.ApplicationActive
    property bool historyResortPending: false
    property bool topResortPending: false
    onOrderFrozenChanged: {
        if (orderFrozen) return
        if (historyResortPending) {
            historyResortPending = false
            refreshHistoryModel()
            rebuildMainList()
        }
        if (topResortPending) {
            topResortPending = false
            refreshTopStations(false)
        }
    }

    // Favourite groups (I1): collapsed state per group id (0 = favourites
    // without a group), stored like the other sections ("favGroup_<id>").
    // Plain JS object - favGroupVersion makes bindings re-evaluate.
    property var favGroupCollapsed: ({})
    property int favGroupVersion: 0

    function isFavGroupCollapsed(groupId) {
        if (favGroupVersion < 0) return false
        if (favGroupCollapsed[groupId] === undefined) {
            favGroupCollapsed[groupId] = appWindow.persistentState.getCollapseState("favGroup_" + groupId, false)
        }
        return favGroupCollapsed[groupId] === true
    }
    property bool topStationsCollapsed: false

    property int pageSize: 20
    property int displayedCount: 20
    // The current top station list, scored and sorted (all of it; the model
    // shows the first displayedCount entries)
    property var cachedSmartList: []

    // --- Station pool ---
    // All stations of the last top station requests (up to ~900), kept in
    // memory. Favourites, history or the current station changing only
    // re-score this pool locally; the network is only asked again when the
    // pool is older than the search cache lifetime (10 minutes) or when the
    // requests themselves would change (top country, language or tag of the
    // taste profile), or on "Try again".
    property var stationPool: []
    property double poolLoadedAt: 0
    property string poolQueryKey: ""

    // Snapshot for the next app start: only the first entries, shown
    // immediately while fresh data loads (up to a day old)
    readonly property int snapshotSize: 100
    readonly property double snapshotMaxAgeMs: 24 * 60 * 60 * 1000

    // Ring navigation (TopStations -> track history -> advanced search -> TopStations).
    // Only the three fixed ring instances from harbour-sailwave.qml have
    // ringMember: true. Copies of this page opened via push() behave like
    // normal stack pages.
    property bool ringMember: false

    onStatusChanged: {
        if (status === PageStatus.Active) {
            healStrictCheck()
        }
        if (ringMember && status === PageStatus.Active) {
            appWindow.ringPageActivated(page)
            longPressHintTimer.restart()
        }
        if (status !== PageStatus.Active) {
            sortMode = false
            longPressHintTimer.stop()
            longPressHint.dismiss()
        }
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        // Ends above the collapsed PlayerBar (see appWindow.playerBarBaseHeight),
        // in landscape left of the player panel
        anchors.bottomMargin: appWindow.playerBarBaseHeight
        anchors.rightMargin: appWindow.playerPanelWidth
        cacheBuffer: 800
        currentIndex: -1

        onAtYEndChanged: {
            if (atYEnd && !searchMode && !topStationsCollapsed) {
                loadMoreTopStations()
            }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                visible: appWindow.favoritesStore.favorites.length > 0
                text: qsTr("Manage favorites")
                onClicked: pageStack.push(Qt.resolvedUrl("FavoritesPage.qml"))
            }
            MenuItem {
                visible: page.searchMode ? page.searchFailed : page.topLoadFailed
                text: qsTr("Try again")
                onClicked: page.retry()
            }
        }

        header: Column {
            width: parent.width
            // (v129) The header grows after the start (rows that appear later):
            // keep a page that is at the top at the top of the header
            onHeightChanged: page.headerHeightChanged()

            PageHeader {
                title: qsTr("Sailwave")
            }

            RingNeighbours { ringPage: page }

            Row {
                width: parent.width
                spacing: Theme.paddingSmall

                SearchField {
                    id: searchField
                    // The Row places its children itself (x has no effect): the
                    // chip's pill ends at the page margin, like the star and the
                    // play disc below (the chip box is paddingSmall wider)
                    width: parent.width - advancedSearchButton.width - parent.spacing
                           - Theme.horizontalPageMargin + Theme.paddingSmall / 2
                    placeholderText: qsTr("Search stations")
                    EnterKey.iconSource: "image://theme/icon-m-search"
                    Component.onCompleted: page.searchFieldItem = searchField
                    EnterKey.onClicked: {
                        searchTimer.stop()
                        searchStations(searchField.text)
                    }

                    onTextChanged: {
                        page.searchFieldText = text
                        if (text.length === 0) {
                            searchTimer.stop()
                            cancelSearch()
                            searchMode = false
                            searchField.focus = false
                            rebuildMainList()
                        } else {
                            searchTimer.restart()
                        }
                    }

                    onActiveFocusChanged: {
                        if (!activeFocus && page.searchFieldText.length === 0) {
                            searchMode = false
                            rebuildMainList()
                        }
                    }
                }

                // Chip as "More options" in Sailcast; opens the advanced search
                FilterChip {
                    id: advancedSearchButton
                    anchors.verticalCenter: searchField.verticalCenter
                    text: qsTr("Advanced") + " \u203a"
                    onClicked: pageStack.push(Qt.resolvedUrl("AdvancedSearchPage.qml"), { initialSearchText: searchField.text })
                }
            }

            // Last heard: one row with the station to continue with
            BackgroundItem {
                id: lastHeardItem
                width: parent.width
                height: visible ? Math.max(Theme.itemSizeMedium, lastHeardColumn.height + 2 * Theme.paddingMedium) : 0
                visible: !page.searchMode && !page.sortMode && page.lastHeard !== null
                onClicked: {
                    var s = page.lastHeard
                    appWindow.playStation({
                        name: s.name, url: s.url, url_resolved: s.url_resolved, country: s.country,
                        codec: s.codec, bitrate: s.bitrate, stationuuid: s.stationuuid,
                        favicon: s.favicon, homepage: s.homepage, tags: s.tags,
                        language: s.language, countrycode: s.countrycode
                    })
                }

                StationIcon {
                    id: lastHeardIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    faviconUrl: page.lastHeard ? (page.lastHeard.favicon || "") : ""
                    homepageUrl: page.lastHeard ? (page.lastHeard.homepage || "") : ""
                    stationuuid: page.lastHeard ? (page.lastHeard.stationuuid || "") : ""
                    stationName: page.lastHeard ? (page.lastHeard.name || "") : ""
                    // as in the station rows below (text on one edge)
                    iconSize: Math.round(Theme.iconSizeSmall * 1.2)
                }

                Column {
                    id: lastHeardColumn
                    anchors.left: lastHeardIcon.right
                    anchors.leftMargin: Theme.paddingMedium
                    anchors.right: lastHeardPlay.left
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        width: parent.width
                        text: qsTr("Last heard")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryHighlightColor
                    }
                    Label {
                        width: parent.width
                        text: page.lastHeard ? RadioApi.displayName(page.lastHeard.name) : ""
                        truncationMode: TruncationMode.Fade
                        color: lastHeardItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                }

                // The same button as at the end of the episode rows in Sailcast
                RowPlayButton {
                    id: lastHeardPlay
                    anchors {
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin - lastHeardPlay.inset
                        verticalCenter: parent.verticalCenter
                    }
                    highlighted: lastHeardItem.highlighted || down
                    onClicked: lastHeardItem.clicked(null)
                }
            }

            // Sort mode of the favourites: "Done" right above the favourites,
            // as a text action (no Button - Silica style, like a header
            // action). It pushes the list down by its height - deliberately,
            // as visible feedback for entering and leaving the mode.
            BackgroundItem {
                id: doneItem
                width: parent.width
                height: Math.max(Theme.itemSizeSmall, doneLabel.height + 2 * Theme.paddingMedium)
                visible: page.sortMode
                onClicked: page.sortMode = false

                Label {
                    id: doneLabel
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Done")
                    font.pixelSize: Theme.fontSizeLarge
                    color: doneItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
            }

            // No favourites yet: a short hint where they will appear and how
            // to add one (only once the lists have content, not while loading)
            Column {
                width: parent.width
                visible: !page.searchMode && rawFavorites.count === 0 && mainListModel.count > 0

                SectionHeader { text: qsTr("Favorites") }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryHighlightColor
                    text: qsTr("Tap the heart next to a station to add it to your favorites.")
                }

                Item { width: 1; height: Theme.paddingLarge }
            }
        }

        model: mainListModel

        // Collapsing/expanding a section removes/inserts only that section's
        // rows (see toggleSection). These transitions animate just that
        // change; for normal list updates they are switched off, otherwise
        // every reload would fade in the whole list.
        add: Transition {
            enabled: page.sectionAnimating
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        }
        remove: Transition {
            enabled: page.sectionAnimating
            NumberAnimation { property: "opacity"; to: 0; duration: 150 }
        }
        displaced: Transition {
            enabled: page.sectionAnimating
            NumberAnimation { property: "y"; duration: 200; easing.type: Easing.InOutQuad }
        }

        // The view ends above the collapsed PlayerBar; the footer only adds
        // the part of the expanded bar that lies on top of the list. That
        // space is part of the footer instead of the list's bottomMargin:
        // with Qt 5.6, a ListView ignores bottomMargin while its content is
        // shorter than the view. The footer always counts as content.
        //
        // Error and empty states below the list: favourites and history stay
        // usable above it, even without a connection
        footer: Column {
            width: listView.width

            Column {
                width: parent.width
                visible: page.searchMode
                         ? (page.searchDone && rawSearch.count === 0)
                         : (page.topLoadFailed && rawTopStations.count === 0)
                height: visible ? implicitHeight : 0
                spacing: Theme.paddingMedium
                topPadding: Theme.paddingLarge
                bottomPadding: Theme.paddingLarge

                InfoLabel {
                    text: (page.searchMode ? page.searchFailed : page.topLoadFailed)
                          ? qsTr("Could not reach the station database")
                          : qsTr("No stations found")
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    text: (page.searchMode ? page.searchFailed : page.topLoadFailed)
                          ? qsTr("Check your internet connection and try again.")
                          : qsTr("Try a different search term.")
                }
                ActionPill {
                    kind: "secondary"
                    x: Theme.horizontalPageMargin
                    visible: page.searchMode ? page.searchFailed : page.topLoadFailed
                    text: qsTr("Try again")
                    onClicked: page.retry()
                }
            }

            Item {
                width: parent.width
                height: appWindow.playerBarOverlap
            }
        }

        delegate: Component {
            Item {
                id: rowItem
                width: listView.width
                height: model.isHeader ? headerItem.height : listItem.height

                readonly property bool isFavoriteRow: !model.isHeader && model.sectionType === "favorites"
                readonly property bool sortHandleShown: page.sortMode && isFavoriteRow

                BackgroundItem {
                    id: headerItem
                    width: parent.width
                    // Grows with the heading (large system font)
                    height: Math.max(Theme.itemSizeExtraSmall, sectionTitle.height + 2 * Theme.paddingSmall)
                    visible: model.isHeader === true
                    // While sorting, all favourite groups are shown expanded and
                    // their headers cannot be collapsed (they are drop targets)
                    readonly property bool favoriteHeaderInSort: page.sortMode && model.sectionType === "favorites"
                    // While sorting, a tap on any header ends the sort mode
                    // (tap "into an empty area", as known from other apps)
                    enabled: page.sortMode || model.collapsible === true

                    onClicked: {
                        if (page.sortMode) {
                            page.sortMode = false
                        } else {
                            page.toggleSection(model.sectionType, model.groupId)
                        }
                    }

                    // As the folders on the Podcasts page in Sailcast: right-aligned,
                    // a small chevron left of the name in the highlight colour
                    Row {
                        anchors {
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: Theme.paddingSmall

                        FoldChevron {
                            id: collapsibleIcon
                            anchors.verticalCenter: parent.verticalCenter
                            visible: model.collapsible === true && !headerItem.favoriteHeaderInSort
                            collapsed: model.sectionType === "history" ? page.historyCollapsed
                                       : model.sectionType === "top" ? page.topStationsCollapsed
                                       : page.isFavGroupCollapsed(model.groupId)
                            tint: headerItem.highlighted ? Theme.primaryColor : Theme.highlightColor
                        }

                        Label {
                            id: sectionTitle
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.headerTitle || ""
                            color: headerItem.highlighted ? Theme.primaryColor : Theme.highlightColor
                            truncationMode: TruncationMode.Fade
                            width: Math.min(implicitWidth, headerItem.width - 2 * Theme.horizontalPageMargin
                                            - (collapsibleIcon.visible ? collapsibleIcon.width + parent.spacing : 0)
                                            - (countBadge.visible ? countBadge.width + parent.spacing : 0))
                        }

                        // Number of stations, as the unplayed count of a folder in Sailcast
                        Rectangle {
                            id: countBadge
                            anchors.verticalCenter: parent.verticalCenter
                            // Not a field of the list model: a new role there
                            // is a risk (see sectionCount)
                            readonly property int count: model.isHeader === true
                                                         ? page.sectionCount(model.sectionType, model.groupId) : 0
                            visible: count > 0 && !page.sortMode
                            height: countLabel.height + Theme.paddingSmall / 2
                            width: Math.max(height, countLabel.width + Theme.paddingMedium)
                            radius: height / 2
                            color: "transparent"
                            border.color: Theme.rgba(Theme.secondaryHighlightColor, 0.6)
                            border.width: 1
                            Label {
                                id: countLabel
                                anchors.centerIn: parent
                                text: countBadge.count > 9999 ? "9999+" : countBadge.count
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryHighlightColor
                            }
                        }
                    }
                }

                StationDelegate {
                    id: listItem
                    width: parent.width
                    visible: !model.isHeader
                    // Favourites that radio-browser reports as not reachable
                    // or no longer listed (FavoritesStore.health)
                    readonly property string health: rowItem.isFavoriteRow
                                                     ? appWindow.favoritesStore.healthOf(model.url) : ""
                    buttonsHidden: rowItem.sortHandleShown
                    warningText: health === "broken" ? qsTr("Not reachable at the moment")
                               : health === "missing" ? qsTr("No longer listed at radio-browser.info") : ""

                    menu: model.isHistory ? historyContextMenu : stationContextMenu

                    Component {
                        id: stationContextMenu
                        ContextMenu {
                            MenuItem {
                                visible: listItem.health.length > 0
                                text: qsTr("Find alternative")
                                onClicked: appWindow.searchStationsFor(model.name)
                            }
                            MenuItem {
                                visible: rowItem.isFavoriteRow && !page.searchMode
                                text: qsTr("Move")
                                onClicked: page.sortMode = true
                            }
                            MenuItem {
                                visible: rowItem.isFavoriteRow && !page.searchMode
                                text: qsTr("Manage favorites")
                                onClicked: pageStack.push(Qt.resolvedUrl("FavoritesPage.qml"))
                            }
                            MenuItem {
                                text: appWindow.favoritesStore.isFavorite(model.url) ? qsTr("Remove from favorites") : qsTr("Add to favorites")
                                onClicked: {
                                    appWindow.favoritesStore.toggle({
                                        name: model.name,
                                        url: model.url,
                                        url_resolved: model.url_resolved,
                                        country: model.country,
                                        codec: model.codec,
                                        bitrate: model.bitrate,
                                        stationuuid: model.stationuuid,
                                        favicon: model.favicon,
                                        homepage: model.homepage,
                                        tags: model.tags,
                                        language: model.language,
                                        countrycode: model.countrycode
                                    })
                                }
                            }
                        }
                    }

                    Component {
                        id: historyContextMenu
                        ContextMenu {
                            MenuItem {
                                text: qsTr("Remove from history")
                                onClicked: {
                                    // Taken now: the menu's QML context is gone when
                                    // the countdown ends
                                    var url = model.url
                                    var target = page
                                    listItem.remorseAction(qsTr("Removing from history"), function() {
                                        target.removeHistoryItem(url)
                                    })
                                }
                            }
                        }
                    }
                }

                // While sorting, a tap on any other row (station history, top
                // stations) ends the sort mode instead of playing the station
                MouseArea {
                    anchors.fill: parent
                    enabled: page.sortMode && !model.isHeader && !rowItem.isFavoriteRow
                    onClicked: page.sortMode = false
                }

                // --- Sort mode: the whole favourite row is the drag handle ---
                // (Long press is the context menu in Silica lists, so sorting is
                // a separate mode, started via "Move" in the context menu.)
                // The row is moved in the model while dragging, so it stays
                // under the finger; the order is saved when released.
                Rectangle {
                    anchors.fill: parent
                    visible: rowItem.sortHandleShown
                    color: dragArea.pressed ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                                            : "transparent"

                    // Handle: three lines on the right
                    Column {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.paddingSmall
                        Repeater {
                            model: 3
                            Rectangle {
                                width: Theme.iconSizeSmall
                                height: Math.max(2, Math.round(Theme.paddingSmall / 2))
                                radius: height / 2
                                color: dragArea.pressed ? Theme.highlightColor : Theme.primaryColor
                            }
                        }
                    }

                    // While sorting, a tap on the row outside the handle ends
                    // the sort mode (no playing); dragging there still scrolls
                    MouseArea {
                        anchors.fill: parent
                        enabled: rowItem.sortHandleShown
                        onClicked: page.sortMode = false
                    }

                    // Only the handle on the right starts a drag (as on the
                    // favourites page), so the list stays scrollable
                    MouseArea {
                        id: dragArea
                        anchors.right: parent.right
                        width: Theme.itemSizeSmall + Theme.horizontalPageMargin
                        height: parent.height
                        enabled: rowItem.sortHandleShown
                        preventStealing: true
                        onPressed: {
                            listView.interactive = false
                            page.dragIndex = index
                            page.dragViewY = mapToItem(listView, mouse.x, mouse.y).y
                        }
                        onPositionChanged: page.moveDraggedTo(mapToItem(listView, mouse.x, mouse.y).y)
                        onReleased: page.finishDrag(rowItem.mapToItem(listView, 0, 0).y)
                        onCanceled: page.finishDrag(rowItem.mapToItem(listView, 0, 0).y)
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        id: busy
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: false
    }


    // Number of stations in a section header (the capsule). Counted from the
    // raw lists, NOT stored as a role in mainListModel; sectionRevision makes
    // the badges update after every rebuild (a station can move between
    // groups without the totals changing).
    property int sectionRevision: 0
    function sectionCount(sectionType, groupId) {
        var rev = sectionRevision
        if (sectionType === "history") {
            return rawHistory.count
        }
        if (sectionType === "top") {
            return rawTopStations.count
        }
        if (sectionType === "favorites") {
            var n = 0
            var gid = Number(groupId) || 0
            for (var i = 0; i < rawFavorites.count; i++) {
                if ((Number(rawFavorites.get(i).groupId) || 0) === gid) {
                    n++
                }
            }
            return n
        }
        return 0
    }

    ListModel { id: mainListModel }
    ListModel { id: rawFavorites }
    ListModel { id: rawHistory }

    // "Last heard" row at the top: the station that was loaded but is not
    // playing (paused or restored at start), otherwise the one heard before
    // the playing one - one tap to listen to it
    property var lastHeard: null
    function refreshLastHeard() {
        var current = appWindow.currentStation
        if (current && current.url && !appWindow.isPlaying) {
            lastHeard = current
            return
        }
        for (var i = 0; i < rawHistory.count; i++) {
            var h = rawHistory.get(i)
            if (h.url && !(current && current.url === h.url)) {
                lastHeard = helperStationObject(h, true, "history")
                return
            }
        }
        lastHeard = null
    }
    Connections {
        target: appWindow
        onIsPlayingChanged: page.refreshLastHeard()
        onCurrentStationChanged: page.refreshLastHeard()
        onStationHistoryUpdated: lastHeardTimer.restart()
    }
    // The history model is refreshed a moment after the signal
    Timer { id: lastHeardTimer; interval: 300; onTriggered: page.refreshLastHeard() }
    Connections {
        target: rawHistory
        onCountChanged: page.refreshLastHeard()
    }
    ListModel { id: rawTopStations }
    ListModel { id: rawSearch }

    property bool sectionAnimating: false

    // --- Sorting the favourites (context menu "Move") ---
    // Sorting covers all favourites, across groups (like the favourites
    // page): moving a favourite past a group header moves it into that
    // group. While sorting, all groups are expanded and empty groups are
    // shown too (as drop targets); leaving the mode restores the stored
    // collapse states.
    property bool sortMode: false
    onSortModeChanged: {
        longPressHint.dismiss()
        // First "Move": once, show where the other favourite options are
        if (sortMode && !appWindow.appSettings.moveHintShown) {
            moveHint.shown = true
            moveHintHideTimer.restart()
        } else if (!sortMode) {
            moveHint.dismiss()
        }
        // A drag may have been cut off by the rebuild: never leave the list
        // locked (it could no longer be scrolled after "Done")
        dragIndex = -1
        listView.interactive = true
        // Keep the view steady: the row at the top of the screen stays where
        // it is (the header shrinks/grows by "Done" and groups collapse or
        // expand, which would otherwise make the list jump)
        var anchor = sortMode ? captureAnchor() : leaveAnchor()
        if (sortMode) {
            lastMovedUrl = ""
        }
        rebuildMainList()
        pendingAnchor = anchor
        restoreAnchorTimer.restart()
    }

    property var pendingAnchor: null

    // All the way to the top INCLUDING the page header. "contentY = originY"
    // puts the first row at the top and pushes the header (title, neighbour
    // line) out of sight - which is what happened after every rebuild of the
    // list while the page was at the top.
    // Topmost allowed scroll position: the top of the page header. The
    // anchor restoring clamped to originY (the top of the first ROW), which
    // threw the header away whenever it was restored while the page was at
    // the top (e.g. the playing station was the anchor).
    function topY() {
        // the top edge of the header in content coordinates (originY already
        // includes the header, see the device log)
        return listView.headerItem ? listView.headerItem.y : listView.originY
    }

    function scrollToTop() {
        listView.contentY = topY()
        listView.returnToBounds()
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
            listView.forceLayout()
            listView.positionViewAtBeginning()
            if (listView.contentY > listView.headerItem.y + 3) {
                // wrong bound: set the position directly (no returnToBounds())
                listView.contentY = listView.headerItem.y
            }
        }
    }

    // (v129) Header height changes (e.g. a row that appears after the start):
    // the list keeps contentY, so the header top moves up out of the view by
    // the added height - the title was cut off and the 150 ms repair then
    // made the page jump. If the view was at the top of the header, it goes
    // to the new top at once (Timer 1 ms: the header's y is updated after
    // its height). _topPinned: the view is at (or above) the header top; it
    // is kept up to date on every scroll, and the growing header does not
    // change contentY, so the flag is still true when the header changes.
    property bool _topPinned: true
    function headerHeightChanged() {
        if (_topPinned) {
            pinTopTimer.restart()
        }
    }

    Timer {
        id: pinTopTimer
        interval: 1
        onTriggered: {
            if (page._topPinned && !listView.dragging && !listView.moving && listView.headerItem
                    && listView.contentY > listView.headerItem.y + 3) {
                listView.contentY = listView.headerItem.y
            }
        }
    }

    Connections {
        target: listView
        onContentYChanged: {
            if (listView.headerItem && !pinTopTimer.running) {
                page._topPinned = listView.contentY <= listView.headerItem.y + 3
            }
        }
    }

    Timer {
        id: healHeaderTimer
        interval: 150
        onTriggered: page.healHeader()
    }

    Connections {
        target: listView
        onMovementEnded: healHeaderTimer.restart()
    }

    // The favourite moved last (see finishDrag)
    property string lastMovedUrl: ""
    property real lastMovedViewY: -1
    property real lastMovedContentY: 0

    // Leaving the sort mode: if the favourite moved last is on screen, it
    // is the anchor - the view stays where it was dropped (e.g. at the
    // bottom after dragging it down), and its group stays expanded so it
    // does not disappear. Otherwise the topmost visible row (captureAnchor).
    function leaveAnchor() {
        if (lastMovedUrl.length > 0) {
            for (var i = 0; i < mainListModel.count; i++) {
                var row = mainListModel.get(i)
                if (!row.isHeader && row.sectionType === "favorites" && row.url === lastMovedUrl) {
                    // Position on screen where it was dropped (see finishDrag)
                    // (corrected if the list was scrolled since then)
                    var y = lastMovedViewY - (listView.contentY - lastMovedContentY)
                    if (y >= 0 && y < listView.height - appWindow.playerBarOverlap) {
                        var gid = row.groupId || 0
                        if (isFavGroupCollapsed(gid)) {
                            favGroupCollapsed[gid] = false
                            favGroupVersion++
                            appWindow.persistentState.setCollapseState("favGroup_" + gid, false)
                        }
                        return { top: false, key: rowKey(row), groupKey: "h:favorites:" + gid, offset: y }
                    }
                    break
                }
            }
        }
        return captureAnchor()
    }


    // Row at the top of the visible area: { top: true } if the page header
    // is visible, else { key, groupKey, offset } (offset = distance of the
    // row from the top of the view)
    function captureAnchor() {
        var y = listView.contentY + 1
        var index = listView.indexAt(Theme.horizontalPageMargin, y)
        if (index < 0) {
            return { top: true }
        }
        var item = listView.itemAt(Theme.horizontalPageMargin, y)
        var row = mainListModel.get(index)
        return {
            top: false,
            key: rowKey(row),
            groupKey: row.sectionType === "favorites" ? "h:favorites:" + (row.groupId || 0) : "",
            offset: item ? item.y - listView.contentY : 0,
            item: item
        }
    }

    // The row of the playing station, if it is on screen - after tapping a
    // station it is the anchor: it stays exactly where it was, and a new
    // entry in the station history extends the list upwards (the rows above
    // move up) instead of pushing the tapped row down
    function currentStationAnchor() {
        var station = appWindow.currentStation
        if (!station || !station.url) {
            return null
        }
        for (var y = 1; y < listView.height; y += Theme.paddingLarge) {
            var cy = listView.contentY + y
            var index = listView.indexAt(Theme.horizontalPageMargin, cy)
            if (index < 0) {
                continue
            }
            var row = mainListModel.get(index)
            if (!row.isHeader && row.url === station.url) {
                var item = listView.itemAt(Theme.horizontalPageMargin, cy)
                if (!item) {
                    return null
                }
                return { top: false, key: rowKey(row), groupKey: "",
                         offset: item.y - listView.contentY, item: item }
            }
        }
        return null
    }

    function rowKey(row) {
        return row.isHeader ? "h:" + row.sectionType + ":" + (row.groupId || 0)
                            : "r:" + row.sectionType + ":" + row.url
    }

    Timer {
        id: restoreAnchorTimer
        interval: 1
        onTriggered: {
            var anchor = page.pendingAnchor
            page.pendingAnchor = null
            healHeaderTimer.restart()
            if (!anchor || anchor.top) {
                page.scrollToTop()
                return
            }
            // The row's delegate still exists (rows are synced, not rebuilt):
            // put it back exactly where it was on screen
            if (anchor.item) {
                var itemY = 0
                var alive = false
                try {
                    alive = anchor.item.parent !== null && anchor.item.parent !== undefined
                    itemY = anchor.item.y
                } catch (e) {
                    alive = false
                }
                if (alive) {
                    listView.forceLayout()
                    itemY = anchor.item.y
                    listView.contentY = Math.max(page.topY(), itemY - anchor.offset)
                    listView.returnToBounds()
                    return
                }
            }
            // The same row, or (collapsed again) its group header
            var index = -1
            for (var i = 0; i < mainListModel.count && index < 0; i++) {
                if (page.rowKey(mainListModel.get(i)) === anchor.key) index = i
            }
            for (var j = 0; j < mainListModel.count && index < 0; j++) {
                if (anchor.groupKey && page.rowKey(mainListModel.get(j)) === anchor.groupKey) index = j
            }
            if (index < 0) {
                return
            }
            listView.positionViewAtIndex(index, ListView.Beginning)
            listView.contentY = Math.max(page.topY(), listView.contentY - anchor.offset)
            listView.returnToBounds()
        }
    }

    property int dragIndex: -1

    // Leave the sort mode when a search starts (and when the page is left,
    // see onStatusChanged)
    onSearchModeChanged: if (searchMode) sortMode = false

    // Collapsing/expanding a favourite group: only its rows are removed or
    // inserted (same principle as the other sections)
    function toggleFavoriteGroup(groupId) {
        var collapse = !isFavGroupCollapsed(groupId)
        favGroupCollapsed[groupId] = collapse
        favGroupVersion++
        appWindow.persistentState.setCollapseState("favGroup_" + groupId, collapse)

        var headerIndex = -1
        for (var i = 0; i < mainListModel.count; i++) {
            var row = mainListModel.get(i)
            if (row.isHeader && row.sectionType === "favorites" && row.groupId === groupId) {
                headerIndex = i
                break
            }
        }
        if (headerIndex < 0) {
            return
        }
        sectionAnimating = true
        sectionAnimationTimer.restart()

        if (collapse) {
            var count = 0
            while (headerIndex + 1 + count < mainListModel.count && !mainListModel.get(headerIndex + 1 + count).isHeader) {
                count++
            }
            if (count > 0) {
                mainListModel.remove(headerIndex + 1, count)
            }
        } else {
            var pos = headerIndex + 1
            for (var f = 0; f < rawFavorites.count; f++) {
                var fav = rawFavorites.get(f)
                if ((Number(fav.groupId) || 0) === groupId) {
                    mainListModel.insert(pos++, helperStationObject(fav, false, "favorites"))
                }
            }
        }
    }

    // Finger position while dragging, in view coordinates
    property real dragViewY: 0

    // Moves the dragged favourite to the row under the finger
    function moveDraggedTo(viewY) {
        dragViewY = viewY
        if (dragIndex < 0) {
            return
        }
        var target = listView.indexAt(Theme.horizontalPageMargin, viewY + listView.contentY)
        var range = favoritesRange()
        if (target < 0) {
            // Above the first row (page header) or below the last one
            target = viewY < listView.height / 2 ? range.first : range.last
        }
        target = Math.max(range.first, Math.min(range.last, target))
        if (target !== dragIndex) {
            sectionAnimating = true
            sectionAnimationTimer.restart()
            mainListModel.move(dragIndex, target, 1)
            dragIndex = target
        }
    }

    // While dragging, the list scrolls by itself when the finger is held
    // near the top edge or just above the PlayerBar - so a favourite can be
    // moved from the very bottom to the very top (as on the favourites page)
    readonly property real autoScrollZone: Theme.itemSizeMedium
    readonly property real dragAreaBottom: listView.height - appWindow.playerBarOverlap

    Timer {
        id: dragAutoScroll
        interval: 30
        repeat: true
        running: page.dragIndex >= 0
                 && (page.dragViewY < page.autoScrollZone
                     || page.dragViewY > page.dragAreaBottom - page.autoScrollZone)
        onTriggered: {
            var up = page.dragViewY < page.autoScrollZone
            var maxY = listView.originY + listView.contentHeight - listView.height
            var y = listView.contentY + (up ? -Theme.paddingLarge : Theme.paddingLarge)
            listView.contentY = Math.max(page.topY(), Math.min(maxY, y))
            page.moveDraggedTo(page.dragViewY)
        }
    }

    // Range a favourite may be moved in: from below the first favourites
    // header to the last row of the favourites block (which may be the
    // header of an empty group - moving onto it puts the favourite into it)
    function favoritesRange() {
        var firstHeader = -1
        var last = -1
        for (var i = 0; i < mainListModel.count; i++) {
            var row = mainListModel.get(i)
            if (row.sectionType === "favorites") {
                if (firstHeader < 0 && row.isHeader) firstHeader = i
                last = i
            }
        }
        return { first: firstHeader + 1, last: last }
    }

    // viewY: where the dragged row ended up on screen (from its delegate)
    function finishDrag(viewY) {
        listView.interactive = true
        if (dragIndex < 0) {
            return
        }
        lastMovedUrl = mainListModel.get(dragIndex).url || ""
        lastMovedViewY = viewY !== undefined ? viewY : -1
        lastMovedContentY = listView.contentY
        dragIndex = -1
        // Group of each favourite = the header above it
        var entries = []
        var currentGroup = 0
        for (var i = 0; i < mainListModel.count; i++) {
            var row = mainListModel.get(i)
            if (row.sectionType !== "favorites") {
                continue
            }
            if (row.isHeader) {
                currentGroup = row.groupId || 0
            } else {
                entries.push({ url: row.url, groupId: currentGroup })
            }
        }
        // The store reloads its list; the start page then takes over the
        // new order via favoritesChanged (refreshFavoritesModel)
        appWindow.favoritesStore.setLayout(entries)
    }

    Timer {
        id: sectionAnimationTimer
        interval: 300
        onTriggered: page.sectionAnimating = false
    }

    Timer {
        id: searchTimer
        interval: 400
        onTriggered: {
            if (page.searchFieldText.length > 0) {
                searchStations(page.searchFieldText)
            }
        }
    }

    Connections {
        target: appWindow.appSettings
        onHomeCountryChanged: page.scheduleTopRefresh()
    }

    Connections {
        target: appWindow.favoritesStore
        onFavoritesChanged: {
            // The station history includes favourites; refreshed anyway so
            // its rows show the new heart state with the rest of the list
            refreshHistoryModel()
            refreshFavoritesModel()
            page.scheduleTopRefresh()
        }
    }

    Connections {
        target: appWindow
        onStationHistoryUpdated: {
            refreshHistoryAndRebuild()
            page.scheduleTopRefresh()
        }
    }

    Connections {
        target: appWindow
        onCurrentStationChanged: {
            page.scheduleTopRefresh()
            // Closes the keyboard when a station starts (the search field
            // registers itself; looking it up by child index broke when the
            // neighbour line was added to the header)
            if (page.searchFieldItem) {
                page.searchFieldItem.focus = false
            }
        }
    }

    // Several triggers usually fire together (playing a station changes the
    // current station AND the station history) - collect them into one refresh
    Timer {
        id: topRefreshTimer
        interval: 500
        onTriggered: {
            // Frozen order (see orderFrozen): re-score later. The first fill
            // is never deferred.
            if (page.orderFrozen && rawTopStations.count > 0 && !page.searchMode) {
                page.topResortPending = true
                return
            }
            page.refreshTopStations(false)
        }
    }

    function scheduleTopRefresh() {
        topRefreshTimer.restart()
    }

    Component.onCompleted: {
        refreshLastHeard()
        if (appWindow && appWindow.persistentState) {
            if (typeof appWindow.persistentState.getCollapseState === "function") {
                historyCollapsed = appWindow.persistentState.getCollapseState("historyCollapsed", true)
                topStationsCollapsed = appWindow.persistentState.getCollapseState("topStationsCollapsed", false)
            }
        }
        refreshAllData()
    }

    function refreshAllData() {
        refreshFavoritesModel()
        refreshHistoryModel()
        showTopStationsSnapshot()
        refreshTopStations(false)
    }

    function refreshFavoritesModel() {
        rawFavorites.clear()
        var favs = appWindow.favoritesStore.favorites
        for (var i = 0; i < favs.length; i++) {
            rawFavorites.append(favs[i])
        }
        rebuildMainList()
    }

    function refreshHistoryModel() {
        var history = appWindow.persistentState.getStationHistory(50)
        var fresh = []
        var seenUrls = {}

        for (var i = 0; i < history.length && fresh.length < 5; i++) {
            var item = history[i]
            // Favourites are included: the history shows what was played
            // last, whether it is a favourite or not (wish Thomas, v79)
            if (item.url && !seenUrls[item.url]) {
                seenUrls[item.url] = true
                fresh.push(item)
            }
        }

        if (!orderFrozen || rawHistory.count === 0) {
            rawHistory.clear()
            for (var a = 0; a < fresh.length; a++) {
                rawHistory.append(fresh[a])
            }
            historyResortPending = false
            return
        }

        // Frozen (see orderFrozen): drop what is no longer there, keep the
        // order of the rest, new stations at the top of the section
        for (var r = rawHistory.count - 1; r >= 0; r--) {
            if (!seenUrls[rawHistory.get(r).url]) {
                rawHistory.remove(r)
            }
        }
        var present = {}
        for (var p = 0; p < rawHistory.count; p++) {
            present[rawHistory.get(p).url] = true
        }
        var inserted = 0
        for (var n = 0; n < fresh.length; n++) {
            if (!present[fresh[n].url]) {
                rawHistory.insert(inserted, fresh[n])
                inserted++
            }
        }
        for (var o = 0; o < rawHistory.count; o++) {
            if (rawHistory.get(o).url !== fresh[o].url) {
                historyResortPending = true
                break
            }
        }
    }

    function refreshHistoryAndRebuild() {
        refreshHistoryModel()
        rebuildMainList()
    }

    function helperStationObject(src, isHistory, sectionType) {
        var row = {
            sectionType: sectionType || "",
            name: src.name || "",
            country: src.country || "",
            language: src.language || "",
            countrycode: src.countrycode || "",
            codec: src.codec || "",
            bitrate: src.bitrate || 0,
            clickcount: src.clickcount || 0,
            url: src.url || "",
            url_resolved: src.url_resolved || "",
            tags: src.tags || "",
            stationuuid: src.stationuuid || "",
            favicon: src.favicon || "",
            homepage: src.homepage || "",
            isHeader: false,
            isHistory: isHistory || false,
            groupId: Number(src.groupId) || 0
        }
        // Rows inserted directly (expanding a section, loading more) get the
        // same id as in buildRows (see addRow)
        row.rowId = rowKey(row) + "#1"
        return normalizeRow(row)
    }

    function removeHistoryItem(stationUrl) {
        if (appWindow && appWindow.persistentState && typeof appWindow.persistentState.removeStationHistory === "function") {
            appWindow.persistentState.removeStationHistory(stationUrl)
            appWindow.stationHistoryUpdated()
            refreshHistoryAndRebuild()
        }
    }

    // Rebuilds the rows from the raw models. Except when switching into or
    // out of the search, the list model is NOT cleared: the new rows are
    // compared with the shown ones (rowId) and only differences are applied
    // (syncRows) - rows stay, logos are not reloaded, and the row at the
    // top of the screen stays in place (anchor). clear() made the page jump
    // twice when a station was played (history + top re-scoring).
    property bool lastBuildWasSearch: false

    function rebuildMainList() {
        var rows = []
        if (searchMode || lastBuildWasSearch) {
            buildRows(rows)
            lastBuildWasSearch = searchMode
            mainListModel.clear()
            for (var c = 0; c < rows.length; c++) {
                mainListModel.append(rows[c])
            }
            return
        }

        pruneTopStations()
        buildRows(rows)

        // Keep the topmost visible row in place (not while the list is being
        // dragged/flicked, and not if another anchor is already pending, e.g.
        // from the sort mode)
        var keep = !listView.moving && page.pendingAnchor === null && mainListModel.count > 0
        var anchor = keep ? (currentStationAnchor() || captureAnchor()) : null
        var changed = syncRows(rows)
        sectionRevision++
        if (changed && anchor && !anchor.top) {
            page.pendingAnchor = anchor
            restoreAnchorTimer.restart()
        }
    }

    // Top stations never show a favourite. A station of the shown station
    // history is removed only while the order is not frozen: a top station
    // that was just played stays where it is (wish Thomas) and moves to the
    // station history only once the page is off screen (see orderFrozen).
    function pruneTopStations() {
        var hist = {}
        if (!orderFrozen) {
            for (var h = 0; h < rawHistory.count; h++) {
                hist[rawHistory.get(h).url] = true
            }
        }
        for (var t = rawTopStations.count - 1; t >= 0; t--) {
            var url = rawTopStations.get(t).url
            if (hist[url] || appWindow.favoritesStore.isFavorite(url)) {
                rawTopStations.remove(t)
            }
        }
    }

    // Applies the differences between the shown rows and rows (rowId):
    // removes rows that are gone, moves/inserts the others into place and
    // updates changed values in place (set() keeps the delegate). Returns
    // whether rows were removed, moved or inserted.
    function syncRows(rows) {
        var changed = false
        var wanted = {}
        for (var w = 0; w < rows.length; w++) {
            wanted[rows[w].rowId] = true
        }
        for (var r = mainListModel.count - 1; r >= 0; r--) {
            if (!wanted[mainListModel.get(r).rowId]) {
                mainListModel.remove(r)
                changed = true
            }
        }
        for (var i = 0; i < rows.length; i++) {
            var id = rows[i].rowId
            if (i < mainListModel.count && mainListModel.get(i).rowId === id) {
                updateRow(i, rows[i])
                continue
            }
            var from = -1
            for (var k = i + 1; k < mainListModel.count; k++) {
                if (mainListModel.get(k).rowId === id) {
                    from = k
                    break
                }
            }
            if (from >= 0) {
                mainListModel.move(from, i, 1)
                updateRow(i, rows[i])
            } else {
                mainListModel.insert(i, rows[i])
            }
            changed = true
        }
        if (mainListModel.count > rows.length) {
            mainListModel.remove(rows.length, mainListModel.count - rows.length)
            changed = true
        }
        return changed
    }

    function updateRow(index, row) {
        var current = mainListModel.get(index)
        for (var key in row) {
            if (current[key] !== row[key]) {
                mainListModel.set(index, row)
                return
            }
        }
    }

    // Unique id per row: rowKey plus a counter for the (rare) case that the
    // same station URL appears twice in one section
    // Every row of the list model has the same roles (header rows and
    // station rows alike). A ListModel takes its roles from the rows it gets;
    // rows with other properties add roles later, and delegates that were
    // created before that never see them - on the device the station rows
    // were sometimes empty after the app start (name, logo, star missing)
    // until the page was opened again.
    function normalizeRow(row) {
        var defaults = {
            sectionType: "", name: "", country: "", language: "", countrycode: "",
            codec: "", bitrate: 0, clickcount: 0, url: "", url_resolved: "",
            tags: "", stationuuid: "", favicon: "", homepage: "",
            isHeader: false, isHistory: false, groupId: 0,
            headerTitle: "", collapsible: false, isCollapsed: false, rowId: ""
        }
        for (var k in defaults) {
            if (row[k] === undefined || row[k] === null) {
                row[k] = defaults[k]
            }
        }
        return row
    }

    function addRow(rows, seen, row) {
        normalizeRow(row)
        var key = rowKey(row)
        seen[key] = (seen[key] || 0) + 1
        row.rowId = key + "#" + seen[key]
        rows.push(row)
    }

    // The rows of the list in display order (see rebuildMainList)
    function buildRows(rows) {
        var seen = {}

        if (searchMode) {
            addRow(rows, seen, {
                isHeader: true,
                headerTitle: qsTr("Search results"),
                collapsible: false,
                sectionType: "search"
            })
            for (var s = 0; s < rawSearch.count; s++) {
                addRow(rows, seen, helperStationObject(rawSearch.get(s), false, "search"))
            }
            return
        }

        if (rawFavorites.count > 0) {
            // Without groups: one section "Favorites" as before. With groups:
            // one collapsible section per group (in group order), favourites
            // without a group last under "Other favorites". Empty groups are
            // not shown here (only on the favourites page).
            var groups = appWindow.favoritesStore.groups
            var sections = []
            if (groups.length === 0) {
                sections.push({ id: 0, title: qsTr("Favorites"), collapsible: false })
            } else {
                for (var g = 0; g < groups.length; g++) {
                    sections.push({ id: groups[g].id, title: groups[g].name, collapsible: true })
                }
                sections.push({ id: 0, title: qsTr("Other favorites"), collapsible: true })
            }
            for (var sec = 0; sec < sections.length; sec++) {
                // Not "rows" - that is the parameter (a var with the same
                // name would replace it: endless loop at start-up in v55)
                var groupFavs = []
                for (var f = 0; f < rawFavorites.count; f++) {
                    var fav = rawFavorites.get(f)
                    if ((Number(fav.groupId) || 0) === sections[sec].id) {
                        groupFavs.push(fav)
                    }
                }
                // Empty groups (and an empty "Other favorites") only while
                // sorting, as drop targets
                if (groupFavs.length === 0 && !(sortMode && groups.length > 0)) {
                    continue
                }
                addRow(rows, seen, {
                    isHeader: true,
                    headerTitle: sections[sec].title,
                    collapsible: sections[sec].collapsible,
                    sectionType: "favorites",
                    groupId: sections[sec].id
                })
                if (!sortMode && sections[sec].collapsible && isFavGroupCollapsed(sections[sec].id)) {
                    continue
                }
                for (var r = 0; r < groupFavs.length; r++) {
                    addRow(rows, seen, helperStationObject(groupFavs[r], false, "favorites"))
                }
            }
        }

        if (rawHistory.count > 0) {
            addRow(rows, seen, {
                isHeader: true,
                headerTitle: qsTr("Station history"),
                collapsible: true,
                sectionType: "history",
                isCollapsed: page.historyCollapsed
            })
            if (!page.historyCollapsed) {
                for (var h = 0; h < rawHistory.count; h++) {
                    addRow(rows, seen, helperStationObject(rawHistory.get(h), true, "history"))
                }
            }
        }

        if (rawTopStations.count > 0) {
            addRow(rows, seen, {
                isHeader: true,
                headerTitle: qsTr("Top stations for you"),
                collapsible: true,
                sectionType: "top",
                isCollapsed: page.topStationsCollapsed
            })
            if (!page.topStationsCollapsed) {
                for (var t = 0; t < rawTopStations.count; t++) {
                    addRow(rows, seen, helperStationObject(rawTopStations.get(t), false, "top"))
                }
            }
        }
    }

    // Collapsing/expanding a section: only that section's rows are removed
    // from or inserted into the list model (no rebuild), so everything above
    // stays in place. Collapsed sections have no rows in the model at all -
    // zero-height rows confused the ListView's content height (the list could
    // no longer be scrolled to the end), and rows that are not in the model
    // also load no logos.
    function toggleSection(sectionType, groupId) {
        if (sectionType === "favorites") {
            toggleFavoriteGroup(groupId || 0)
            return
        }
        var collapse
        if (sectionType === "history") {
            historyCollapsed = !historyCollapsed
            collapse = historyCollapsed
            appWindow.persistentState.setCollapseState("historyCollapsed", historyCollapsed)
        } else if (sectionType === "top") {
            topStationsCollapsed = !topStationsCollapsed
            collapse = topStationsCollapsed
            appWindow.persistentState.setCollapseState("topStationsCollapsed", topStationsCollapsed)
        } else {
            return
        }

        var headerIndex = -1
        for (var i = 0; i < mainListModel.count; i++) {
            var row = mainListModel.get(i)
            if (row.isHeader && row.sectionType === sectionType) {
                headerIndex = i
                break
            }
        }
        if (headerIndex < 0) {
            return
        }

        sectionAnimating = true
        sectionAnimationTimer.restart()

        if (collapse) {
            var count = 0
            while (headerIndex + 1 + count < mainListModel.count) {
                var next = mainListModel.get(headerIndex + 1 + count)
                if (next.isHeader || next.sectionType !== sectionType) {
                    break
                }
                count++
            }
            if (count > 0) {
                mainListModel.remove(headerIndex + 1, count)
            }
        } else {
            var source = sectionType === "history" ? rawHistory : rawTopStations
            for (var j = 0; j < source.count; j++) {
                mainListModel.insert(headerIndex + 1 + j,
                                     helperStationObject(source.get(j), sectionType === "history", sectionType))
            }
        }
    }

    // Shows the stored top stations of the last session right away (the
    // pool is still empty then; refreshTopStations fetches fresh data)
    function showTopStationsSnapshot() {
        var snapshot = appWindow.persistentState.loadTopStationsSnapshot(snapshotMaxAgeMs)
        if (!snapshot) {
            return
        }
        cachedSmartList = snapshot.stations
        displayedCount = Math.min(pageSize, cachedSmartList.length)
        populateRawModel(rawTopStations, cachedSmartList.slice(0, displayedCount))
        rebuildMainList()
    }

    // Input for scoring: the taste profile from favourites, the latest
    // station history and the current station
    function buildScoringContext() {
        var favorites = appWindow.favoritesStore.favorites || []
        var historyStations = appWindow.persistentState.getStationHistory(3)
        var currentStation = appWindow.currentStation ? appWindow.currentStation : null
        return {
            favorites: favorites,
            historyStations: historyStations,
            currentStation: currentStation,
            profile: buildUserTasteProfile(favorites, historyStations, currentStation),
            hasProfile: favorites.length > 0 || historyStations.length > 0 || currentStation !== null
        }
    }

    // The requests for the station pool: the global top list, plus stations
    // matching the top country + language and the top tag of the profile
    function buildTopQueries(ctx) {
        var queries = [apiBase + "topclick/500?hidebroken=true"]
        if (ctx.hasProfile) {
            var topCountry = pickTopKey(ctx.profile.countries)
            var topLanguage = pickTopKey(ctx.profile.languages)
            var topTag = pickTopKey(ctx.profile.tags)

            if (topCountry && topLanguage) {
                queries.push(apiBase + "search?countrycode=" + encodeURIComponent(topCountry.toUpperCase())
                             + "&language=" + encodeURIComponent(topLanguage)
                             + "&limit=200&hidebroken=true")
            }
            if (topTag) {
                queries.push(apiBase + "search?tag=" + encodeURIComponent(topTag)
                             + "&limit=200&hidebroken=true")
            }
        }
        return queries
    }

    // Updates the top station list. forceNetwork: always fetch the pool
    // again ("Try again"); otherwise the pool in memory is re-scored if it is
    // still fresh and matches the current requests.
    function refreshTopStations(forceNetwork) {
        topRefreshTimer.stop()
        topLoadId++
        var currentLoadId = topLoadId
        var ctx = buildScoringContext()

        appWindow.resolveUserCountry(function(countryCode) {
            if (currentLoadId !== topLoadId) {
                return
            }
            userCountry = countryCode || ""

            var queries = buildTopQueries(ctx)
            var queryKey = queries.join("|")
            var poolFresh = stationPool.length > 0
                    && queryKey === poolQueryKey
                    && Date.now() - poolLoadedAt < appWindow.persistentState.cacheTtlMs

            if (poolFresh && !forceNetwork) {
                applyTopScoring(ctx)
                return
            }

            // Only show the big busy indicator while there is nothing to see;
            // otherwise the current list stays and is replaced when done
            busy.running = rawTopStations.count === 0

            RadioApi.fetchAll(queries, appWindow.apiUserAgent,
                function() { return currentLoadId !== topLoadId },
                function(merged, failed) {
                    busy.running = false

                    // No request got through: keep what is shown, cache nothing,
                    // and offer "Try again"
                    topLoadFailed = (failed === queries.length)
                    if (topLoadFailed) {
                        rebuildMainList()
                        return
                    }

                    var allStations = []
                    for (var key in merged) {
                        allStations.push(merged[key])
                    }
                    stationPool = allStations
                    poolLoadedAt = Date.now()
                    poolQueryKey = queryKey

                    applyTopScoring(ctx)
                    // Written only after a real network load, and only the
                    // first entries (the snapshot for the next app start)
                    appWindow.persistentState.saveTopStationsSnapshot(cachedSmartList.slice(0, snapshotSize))
                })
        })
    }

    function applyTopScoring(ctx) {
        processTopStations(stationPool, userCountry, ctx.favorites, ctx.historyStations,
                           ctx.currentStation, ctx.profile, ctx.hasProfile)
        rebuildMainList()
    }

    function pickTopKey(counts) {
        var best = ""
        var bestCount = 0
        for (var k in counts) {
            if (counts[k] > bestCount) {
                best = k
                bestCount = counts[k]
            }
        }
        return best
    }

    function getTagsArray(station) {
        if (!station || !station.tags) return []
        if (Array.isArray(station.tags)) return station.tags
        return station.tags.split(",")
    }

    // The tag weights only depend on the station pool, not on the favourites
    // or history (those are removed afterwards), so they are computed once
    // per pool instead of at every re-scoring (3 times around the start-up,
    // 44-76 ms each in the profiler).
    property var idfPoolRef: null
    property var idfPoolValues: null

    function idfForPool(pool) {
        if (idfPoolRef !== pool || idfPoolValues === null) {
            idfPoolValues = calculateIdf(pool)
            idfPoolRef = pool
        }
        return idfPoolValues
    }

    function calculateIdf(stations) {
        var docCount = stations.length
        var tagDocFrequency = {}

        for (var i = 0; i < docCount; i++) {
            var tags = getTagsArray(stations[i])
            var uniqueTags = {}

            for (var t = 0; t < tags.length; t++) {
                var tag = tags[t].trim().toLowerCase()
                if (tag.length > 0 && !uniqueTags[tag]) {
                    uniqueTags[tag] = true
                    tagDocFrequency[tag] = (tagDocFrequency[tag] || 0) + 1
                }
            }
        }

        var idfValues = {}
        for (var tag in tagDocFrequency) {
            idfValues[tag] = Math.log(docCount / tagDocFrequency[tag])
        }
        return idfValues
    }

    function processTopStations(rawStations, userCountryCode, favorites, historyStations, currentStation, profile, hasProfile) {
        var excludeUrls = {}
        for (var f = 0; f < favorites.length; f++) {
            if (favorites[f].url) {
                excludeUrls[favorites[f].url] = true
            }
        }
        for (var e = 0; e < historyStations.length; e++) {
            if (historyStations[e].url) {
                excludeUrls[historyStations[e].url] = true
            }
        }

        var availableStations = []
        for (var i = 0; i < rawStations.length; i++) {
            var station = rawStations[i]
            if (!excludeUrls[station.url]) {
                availableStations.push(station)
            }
        }

        var idfMap = hasProfile ? idfForPool(rawStations) : null

        if (!hasProfile) {
            var fallbackList = []
            for (var j = 0; j < availableStations.length; j++) {
                if (userCountryCode && availableStations[j].countrycode && availableStations[j].countrycode.toUpperCase() === userCountryCode) {
                    fallbackList.push(availableStations[j])
                }
            }
            for (var k = 0; k < availableStations.length; k++) {
                if (fallbackList.indexOf(availableStations[k]) === -1) {
                    fallbackList.push(availableStations[k])
                }
            }
            cachedSmartList = fallbackList
        } else {
            for (var m = 0; m < availableStations.length; m++) {
                availableStations[m].calculatedScore = scoreStation(availableStations[m], profile, userCountryCode, idfMap)
            }
            availableStations.sort(function(a, b) {
                if (b.calculatedScore !== a.calculatedScore) {
                    return b.calculatedScore - a.calculatedScore
                }
                return (b.clickcount || 0) - (a.clickcount || 0)
            })
            cachedSmartList = availableStations
        }

        displayedCount = Math.min(pageSize, cachedSmartList.length)
        populateRawModel(rawTopStations, cachedSmartList.slice(0, displayedCount))
    }

    function loadMoreTopStations() {
        if (displayedCount >= cachedSmartList.length) return

        var nextBatchCount = Math.min(displayedCount + pageSize, cachedSmartList.length)
        var nextItems = cachedSmartList.slice(displayedCount, nextBatchCount)
        displayedCount = nextBatchCount

        var hadTopSection = rawTopStations.count > 0
        for (var i = 0; i < nextItems.length; i++) {
            rawTopStations.append(nextItems[i])
        }
        if (hadTopSection && topStationsCollapsed) {
            // Collapsed: the rows are inserted when the section is expanded
            return
        }
        if (hadTopSection) {
            // Top stations are the last section: just append the new rows
            // instead of rebuilding the list (keeps the scroll position)
            for (var j = 0; j < nextItems.length; j++) {
                mainListModel.append(helperStationObject(nextItems[j], false, "top"))
            }
        } else {
            rebuildMainList()
        }
    }

    function buildUserTasteProfile(favoritesList, historyList, currentStation) {
        var countryCounts = {}
        var languageCounts = {}
        var tagCounts = {}

        function addEntries(list, weightMultiplier) {
            for (var i = 0; i < list.length; i++) {
                var item = list[i]

                if (item.countrycode) {
                    var c = item.countrycode.toLowerCase()
                    countryCounts[c] = (countryCounts[c] || 0) + (1 * weightMultiplier)
                }

                var langs = RadioApi.splitList(item.language, true)
                for (var l = 0; l < langs.length; l++) {
                    languageCounts[langs[l]] = (languageCounts[langs[l]] || 0) + (1 * weightMultiplier)
                }

                var tags = RadioApi.splitList(item.tags, true)
                for (var t = 0; t < tags.length; t++) {
                    tagCounts[tags[t]] = (tagCounts[tags[t]] || 0) + (1 * weightMultiplier)
                }
            }
        }

        addEntries(favoritesList, 1.0)
        addEntries(historyList, 0.5)
        if (currentStation) {
            addEntries([currentStation], 2.0)
        }

        return { countries: countryCounts, languages: languageCounts, tags: tagCounts }
    }

    function scoreStation(station, profile, userCountryCode, idfMap) {
        var score = 0

        if (station.tags) {
            var tags = getTagsArray(station)
            for (var i = 0; i < tags.length; i++) {
                var tag = tags[i].trim().toLowerCase()
                if (tag && profile.tags[tag]) {
                    var idf = (idfMap && idfMap[tag]) ? idfMap[tag] : 1.0
                    score += profile.tags[tag] * idf * 20
                }
            }
        }

        if (station.language) {
            var stationLangs = station.language.toLowerCase()
            for (var lang in profile.languages) {
                if (stationLangs.indexOf(lang) !== -1) {
                    score += profile.languages[lang] * 10
                }
            }
        }

        if (station.countrycode && userCountryCode) {
            if (station.countrycode.toUpperCase() === userCountryCode.toUpperCase()) {
                score += 5
            }
        }

        return score
    }

    function populateRawModel(target, results) {
        target.clear()
        for (var i = 0; i < results.length; i++) {
            target.append(results[i])
        }
    }

    // Order of the quick search results: A-Z, then grouped by how the name
    // matches the phrase (RadioApi.groupByNameMatch - starts with / contains
    // / rest). Before, everything was A-Z only, so "Radio si" did not bring
    // Radio SI to the top.
    function rankSearchResults(list, phrase) {
        var sorted = list.slice().sort(function(a, b) {
            return String(a.name || "").localeCompare(String(b.name || ""))
        })
        return RadioApi.groupByNameMatch(sorted, phrase)
    }

    function searchStations(query) {
        var tokens = query.toLowerCase().split(/\s+/).filter(function(t) { return t.length > 0 })

        var anchor = tokens.reduce(function(longest, t) {
            return t.length > longest.length ? t : longest
        }, tokens.length > 0 ? tokens[0] : "")

        if (tokens.length === 0 || anchor.length < minSearchLength) {
            cancelSearch()
            if (searchMode) {
                searchMode = false
                rebuildMainList()
            }
            return
        }
        searchMode = true
        searchDone = false
        searchFailed = false

        var cacheKey = tokens.slice().sort().join(" ")
        var cached = appWindow.persistentState.getCachedResults(cacheKey)
        if (cached) {
            cancelSearch()
            // Cached unranked (the key ignores the word order); ranked for
            // the phrase as typed now
            populateRawModel(rawSearch, rankSearchResults(cached, tokens.join(" ")).slice(0, 50))
            searchDone = true
            rebuildMainList()
            return
        }

        fetchCombinedSearch(anchor, tokens, cacheKey)
    }

    // "Try again" after a failed load or search
    function retry() {
        if (searchMode) {
            searchStations(searchFieldText)
        } else {
            refreshTopStations(true)
        }
    }

    function cancelSearch() {
        searchRequestId++
        if (searchMode) {
            busy.running = false
        }
    }

    function fetchCombinedSearch(anchor, tokens, cacheKey) {
        searchRequestId++
        var currentRequestId = searchRequestId
        busy.running = true

        var urls = []
        // Only query valid text/tag search fields
        var fields = ["name", "tag"]
        for (var i = 0; i < fields.length; i++) {
            urls.push(apiBase + "search?" + fields[i] + "=" + encodeURIComponent(anchor) + "&limit=100&hidebroken=true")
        }
        // Several words: also the whole phrase as part of the name. The
        // longest word alone ("radio" for "radio kä") returns only the 100
        // most popular "radio" stations, and none of them had to contain the
        // word still being typed - "Radio Kärnten" only appeared once
        // "kärnten" was complete. radio-browser's name search matches the
        // phrase anywhere in the name, so "radio kä" finds it right away.
        if (tokens.length > 1) {
            urls.push(apiBase + "search?name=" + encodeURIComponent(tokens.join(" ")) + "&limit=100&hidebroken=true")
        }

        RadioApi.fetchAll(urls, appWindow.apiUserAgent,
            function() { return currentRequestId !== searchRequestId },
            function(merged, failed) {
                busy.running = false
                searchDone = true
                searchFailed = (failed === urls.length)
                if (searchFailed) {
                    populateRawModel(rawSearch, [])
                    rebuildMainList()
                    return
                }

                var results = []
                for (var key in merged) {
                    var station = merged[key]
                    var haystack = [station.name, station.tags, station.country, station.language]
                                  .join(" ").toLowerCase()
                    var matchesAll = tokens.every(function(t) { return haystack.indexOf(t) !== -1 })
                    if (matchesAll) {
                        results.push(station)
                    }
                }
                // Only complete results are kept (a failed part must not be
                // served from the cache for 10 minutes)
                if (cacheKey && failed === 0) {
                    appWindow.persistentState.setCachedResults(cacheKey, results)
                }
                populateRawModel(rawSearch, rankSearchResults(results, tokens.join(" ")).slice(0, 50))
                rebuildMainList()
            })
    }

    // --- One-time hint on the first "Move": the start page only offers
    // sorting, groups/backup/etc. live on the favourites page. Takes no
    // touches (dragging near the bottom must keep working); disappears after
    // 8 s or when the sort mode ends - and never comes back.
    InteractionHintLabel {
        id: moveHint
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.playerBarBaseHeight
        width: parent.width - appWindow.playerPanelWidth
        z: 10
        text: qsTr("Groups, backup and more: pull down and choose \"Manage favorites\"")
        property bool shown: false
        opacity: shown ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { FadeAnimation { duration: 400 } }

        function dismiss() {
            if (shown) {
                shown = false
                appWindow.appSettings.moveHintShown = true
            }
        }
    }

    Timer {
        id: moveHintHideTimer
        interval: 8000
        onTriggered: moveHint.dismiss()
    }

    // --- One-time hint: press and hold a station for its menu (find
    // alternative, move, ...). The last of the hints: only when the others
    // are done, the start page is open and there are favourites. Takes no
    // touches; disappears after 8 s, on tap-free leaving of the page, or when
    // the sort mode starts - and never comes back.
    InteractionHintLabel {
        id: longPressHint
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.playerBarBaseHeight
        width: parent.width - appWindow.playerPanelWidth
        z: 10
        text: qsTr("Press and hold a station for more options")
        property bool shown: false
        opacity: shown ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { FadeAnimation { duration: 400 } }

        function dismiss() {
            if (shown) {
                shown = false
                longPressHintHideTimer.stop()
                appWindow.appSettings.longPressHintShown = true
            }
        }
    }

    Timer {
        id: longPressHintTimer
        interval: 2500
        onTriggered: {
            var s = appWindow.appSettings
            if (!s.longPressHintShown && s.ringHintShown && s.playerBarHintShown
                    && s.playerBarExpandHintShown && !page.sortMode && !moveHint.shown
                    && page.status === PageStatus.Active
                    && appWindow.favoritesStore.favorites.length > 0) {
                longPressHint.shown = true
                longPressHintHideTimer.restart()
            }
        }
    }

    Timer {
        id: longPressHintHideTimer
        interval: 8000
        onTriggered: longPressHint.dismiss()
    }
}
