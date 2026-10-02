import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"
import "../RadioApi.js" as RadioApi

Page {
    id: page

    readonly property string apiBase: RadioApi.apiUrl("stations/")
    property string userCountry: ""
    property bool searchMode: false

    // Error / empty states (shown below the list, see footer)
    property bool topLoadFailed: false   // top stations could not be loaded at all
    property bool searchFailed: false    // the last search could not reach the server
    property bool searchDone: false      // a search has finished (for "no results")
    property string searchFieldText: ""
    property int searchRequestId: 0
    property int minSearchLength: 2

    property int topLoadId: 0

    property bool historyCollapsed: true

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
        if (ringMember && status === PageStatus.Active) {
            appWindow.ringPageActivated(page)
        }
        if (status !== PageStatus.Active) {
            sortMode = false
        }
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
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

            PageHeader {
                title: qsTr("Sailwave")
            }

            Row {
                width: parent.width
                spacing: Theme.paddingSmall

                SearchField {
                    id: searchField
                    width: parent.width - advancedSearchButton.width - parent.spacing - (2 * Theme.horizontalPageMargin)
                    x: Theme.horizontalPageMargin
                    placeholderText: qsTr("Search stations")
                    EnterKey.iconSource: "image://theme/icon-m-search"
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

                IconButton {
                    id: advancedSearchButton
                    anchors.verticalCenter: searchField.verticalCenter
                    icon.source: "image://theme/icon-m-levels"
                    onClicked: pageStack.push(Qt.resolvedUrl("AdvancedSearchPage.qml"), { initialSearchText: searchField.text })
                }
            }

            // Sort mode of the favourites: "Done" right above the favourites,
            // as a text action (no Button - Silica style, like a header
            // action). It pushes the list down by its height - deliberately,
            // as visible feedback for entering and leaving the mode.
            BackgroundItem {
                id: doneItem
                width: parent.width
                height: Theme.itemSizeSmall
                visible: page.sortMode
                onClicked: page.sortMode = false

                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Done")
                    font.pixelSize: Theme.fontSizeLarge
                    color: doneItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
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

        // The space for the PlayerBar is part of the footer instead of the
        // list's bottomMargin: with Qt 5.6, a ListView ignores bottomMargin
        // while its content is shorter than the view, so the last rows could
        // end up hidden behind the PlayerBar without the list being
        // scrollable (e.g. start page with station history expanded and
        // top stations collapsed). The footer always counts as content.
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
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: page.searchMode ? page.searchFailed : page.topLoadFailed
                    text: qsTr("Try again")
                    onClicked: page.retry()
                }
            }

            Item {
                width: parent.width
                height: appWindow.playerBarHeight
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
                    height: Theme.itemSizeSmall
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

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.rightMargin: Theme.horizontalPageMargin
                        spacing: Theme.paddingMedium

                        SectionHeader {
                            text: model.headerTitle || ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (collapsibleIcon.visible ? collapsibleIcon.width : 0)
                        }

                        IconButton {
                            id: collapsibleIcon
                            anchors.verticalCenter: parent.verticalCenter
                            visible: model.collapsible === true && !headerItem.favoriteHeaderInSort
                            icon.source: (model.sectionType === "history" ? page.historyCollapsed
                                          : model.sectionType === "top" ? page.topStationsCollapsed
                                          : page.isFavGroupCollapsed(model.groupId)) ? "image://theme/icon-m-right" : "image://theme/icon-m-down"
                            enabled: false
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
                        onReleased: page.finishDrag()
                        onCanceled: page.finishDrag()
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


    ListModel { id: mainListModel }
    ListModel { id: rawFavorites }
    ListModel { id: rawHistory }
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
        // A drag may have been cut off by the rebuild: never leave the list
        // locked (it could no longer be scrolled after "Done")
        dragIndex = -1
        listView.interactive = true
        // Keep the view steady: the row at the top of the screen stays where
        // it is (the header shrinks/grows by "Done" and groups collapse or
        // expand, which would otherwise make the list jump)
        var anchor = captureAnchor()
        rebuildMainList()
        pendingAnchor = anchor
        restoreAnchorTimer.restart()
    }

    property var pendingAnchor: null

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
            offset: item ? item.y - listView.contentY : 0
        }
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
            if (!anchor || anchor.top) {
                listView.positionViewAtBeginning()
                listView.contentY = listView.originY
                return
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
            listView.contentY = Math.max(listView.originY, listView.contentY - anchor.offset)
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
    readonly property real dragAreaBottom: listView.height - appWindow.playerBarHeight

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
            listView.contentY = Math.max(listView.originY, Math.min(maxY, y))
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

    function finishDrag() {
        listView.interactive = true
        if (dragIndex < 0) {
            return
        }
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
            if (listView.headerItem && listView.headerItem.children[1] && listView.headerItem.children[1].children[0]) {
                var field = listView.headerItem.children[1].children[0]
                if (field && typeof field.focus !== "undefined") {
                    field.focus = false
                }
            }
        }
    }

    // Several triggers usually fire together (playing a station changes the
    // current station AND the station history) - collect them into one refresh
    Timer {
        id: topRefreshTimer
        interval: 500
        onTriggered: page.refreshTopStations(false)
    }

    function scheduleTopRefresh() {
        topRefreshTimer.restart()
    }

    Component.onCompleted: {
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
        rawHistory.clear()
        var history = appWindow.persistentState.getStationHistory(50)
        var shown = 0
        var seenUrls = {}

        for (var i = 0; i < history.length && shown < 5; i++) {
            var item = history[i]
            if (item.url && !seenUrls[item.url] && !appWindow.favoritesStore.isFavorite(item.url)) {
                seenUrls[item.url] = true
                rawHistory.append(item)
                shown++
            }
        }
    }

    function refreshHistoryAndRebuild() {
        refreshHistoryModel()
        rebuildMainList()
    }

    function helperStationObject(src, isHistory, sectionType) {
        return {
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
    }

    function removeHistoryItem(stationUrl) {
        if (appWindow && appWindow.persistentState && typeof appWindow.persistentState.removeStationHistory === "function") {
            appWindow.persistentState.removeStationHistory(stationUrl)
            appWindow.stationHistoryUpdated()
            refreshHistoryAndRebuild()
        }
    }

    function rebuildMainList() {
        mainListModel.clear()

        if (searchMode) {
            mainListModel.append({
                isHeader: true,
                headerTitle: qsTr("Search results"),
                collapsible: false,
                sectionType: "search"
            })
            for (var s = 0; s < rawSearch.count; s++) {
                mainListModel.append(helperStationObject(rawSearch.get(s), false, "search"))
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
                var rows = []
                for (var f = 0; f < rawFavorites.count; f++) {
                    var fav = rawFavorites.get(f)
                    if ((Number(fav.groupId) || 0) === sections[sec].id) {
                        rows.push(fav)
                    }
                }
                // Empty groups (and an empty "Other favorites") only while
                // sorting, as drop targets
                if (rows.length === 0 && !(sortMode && groups.length > 0)) {
                    continue
                }
                mainListModel.append({
                    isHeader: true,
                    headerTitle: sections[sec].title,
                    collapsible: sections[sec].collapsible,
                    sectionType: "favorites",
                    groupId: sections[sec].id
                })
                if (!sortMode && sections[sec].collapsible && isFavGroupCollapsed(sections[sec].id)) {
                    continue
                }
                for (var r = 0; r < rows.length; r++) {
                    mainListModel.append(helperStationObject(rows[r], false, "favorites"))
                }
            }
        }

        if (rawHistory.count > 0) {
            mainListModel.append({
                isHeader: true,
                headerTitle: qsTr("Station history"),
                collapsible: true,
                sectionType: "history",
                isCollapsed: page.historyCollapsed
            })
            if (!page.historyCollapsed) {
                for (var h = 0; h < rawHistory.count; h++) {
                    mainListModel.append(helperStationObject(rawHistory.get(h), true, "history"))
                }
            }
        }

        if (rawTopStations.count > 0) {
            mainListModel.append({
                isHeader: true,
                headerTitle: qsTr("Top stations"),
                collapsible: true,
                sectionType: "top",
                isCollapsed: page.topStationsCollapsed
            })
            if (!page.topStationsCollapsed) {
                for (var t = 0; t < rawTopStations.count; t++) {
                    mainListModel.append(helperStationObject(rawTopStations.get(t), false, "top"))
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

        var idfMap = calculateIdf(availableStations)

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
            populateRawModel(rawSearch, cached)
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
                results.sort(function(a, b) { return a.name.localeCompare(b.name) })
                results = results.slice(0, 50)

                populateRawModel(rawSearch, results)
                rebuildMainList()
                if (cacheKey) {
                    appWindow.persistentState.setCachedResults(cacheKey, results)
                }
            })
    }
}
