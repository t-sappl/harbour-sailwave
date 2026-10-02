import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"

// Managing favourites and favourite groups (I1/I2). A pure editing page:
// tapping a favourite does not play it.
//  - Groups: create (pulley), rename / move up / move down / delete via the
//    context menu of a group header. Deleting offers both: the group only
//    (its favourites move to "Other favorites") or the group with them.
//  - Favourites: drag the handle on the right to sort them or move them to
//    another group. The list scrolls by itself near the top/bottom edge.
//  - Selecting (pulley "Select"): tap favourites and groups, then delete
//    them together (with countdown). Selected groups are deleted without
//    their favourites, unless those are selected as well.
//  - Reachability (FavoritesStore.health) as on the start page.
Page {
    id: page
    objectName: "favoritesPage"

    RemorsePopup { id: remorse }

    property bool selecting: false
    // Selected favourites (url -> true) and groups (id -> true); plain JS
    // objects, selectionVersion makes bindings re-evaluate
    property var selectedUrls: ({})
    property var selectedGroups: ({})
    property int selectionVersion: 0

    readonly property int selectedCount: {
        var n = selectionVersion >= 0 ? 0 : 0
        for (var u in selectedUrls) n++
        for (var g in selectedGroups) n++
        return n
    }

    function isSelected(isHeader, groupId, url) {
        if (selectionVersion < 0) return false
        return isHeader ? selectedGroups[groupId] === true : selectedUrls[url] === true
    }

    function toggleSelected(isHeader, groupId, url) {
        if (isHeader) {
            if (selectedGroups[groupId]) delete selectedGroups[groupId]
            else selectedGroups[groupId] = true
        } else {
            if (selectedUrls[url]) delete selectedUrls[url]
            else selectedUrls[url] = true
        }
        selectionVersion++
    }

    function endSelection() {
        selecting = false
        selectedUrls = {}
        selectedGroups = {}
        selectionVersion++
    }

    // --- List model: group headers (also empty groups, as drop targets)
    // followed by their favourites; "Other favorites" last. Without any group
    // there are no headers at all.
    ListModel { id: favModel }

    property bool _ownChange: false

    function rebuild() {
        favModel.clear()
        var store = appWindow.favoritesStore
        var groups = store.groups
        var sections = []
        for (var g = 0; g < groups.length; g++) {
            sections.push({ id: groups[g].id, name: groups[g].name })
        }
        if (groups.length > 0) {
            // Same name as on the start page
            sections.push({ id: 0, name: qsTr("Other favorites") })
        }
        if (sections.length === 0) {
            sections.push({ id: 0, name: "", noHeader: true })
        }
        for (var s = 0; s < sections.length; s++) {
            var favs = store.favoritesOfGroup(sections[s].id)
            if (!sections[s].noHeader) {
                favModel.append(row(true, sections[s].id, sections[s].name, null, favs.length))
            }
            for (var f = 0; f < favs.length; f++) {
                favModel.append(row(false, sections[s].id, favs[f].name, favs[f], 0))
            }
        }
    }

    // All rows have the same roles (ListModel requirement)
    function row(isHeader, groupId, name, fav, count) {
        return {
            isHeader: isHeader,
            groupId: groupId,
            name: name || "",
            count: count,
            url: fav ? fav.url : "",
            favicon: fav ? (fav.favicon || "") : "",
            homepage: fav ? (fav.homepage || "") : "",
            stationuuid: fav ? (fav.stationuuid || "") : "",
            country: fav ? (fav.country || "") : "",
            codec: fav ? (fav.codec || "") : "",
            bitrate: fav ? (fav.bitrate || 0) : 0
        }
    }

    Component.onCompleted: rebuild()

    Connections {
        target: appWindow.favoritesStore
        onFavoritesChanged: if (!page._ownChange) page.rebuild()
    }

    // --- Dragging ---
    property int dragIndex: -1
    property real dragViewY: 0   // finger position in view coordinates

    // First index a favourite may be moved to (below the first header)
    function firstMovableIndex() {
        return (favModel.count > 0 && favModel.get(0).isHeader) ? 1 : 0
    }

    function moveDraggedTo(viewY) {
        dragViewY = viewY
        var contentY = viewY + listView.contentY
        var target = listView.indexAt(Theme.horizontalPageMargin, contentY)
        if (target < 0) {
            target = viewY < 0 ? firstMovableIndex() : favModel.count - 1
        }
        target = Math.max(firstMovableIndex(), Math.min(favModel.count - 1, target))
        if (target !== dragIndex && dragIndex >= 0) {
            favModel.move(dragIndex, target, 1)
            dragIndex = target
        }
    }

    // Scrolls while the finger is held near the top or bottom edge
    Timer {
        id: autoScroll
        interval: 30
        repeat: true
        running: page.dragIndex >= 0
                 && (page.dragViewY < Theme.itemSizeMedium
                     || page.dragViewY > listView.height - Theme.itemSizeMedium)
        onTriggered: {
            var step = page.dragViewY < Theme.itemSizeMedium ? -Theme.paddingLarge : Theme.paddingLarge
            var maxY = listView.originY + listView.contentHeight - listView.height
            listView.contentY = Math.max(listView.originY, Math.min(maxY, listView.contentY + step))
            page.moveDraggedTo(page.dragViewY)
        }
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
        for (var i = 0; i < favModel.count; i++) {
            var r = favModel.get(i)
            if (r.isHeader) {
                currentGroup = r.groupId
            } else {
                entries.push({ url: r.url, groupId: currentGroup })
            }
        }
        _ownChange = true
        appWindow.favoritesStore.setLayout(entries)
        _ownChange = false
        updateCounts()
    }

    // Number of favourites shown in the group headers
    function updateCounts() {
        var header = -1
        var n = 0
        for (var i = 0; i <= favModel.count; i++) {
            var r = i < favModel.count ? favModel.get(i) : null
            if (!r || r.isHeader) {
                if (header >= 0) favModel.setProperty(header, "count", n)
                header = i
                n = 0
            } else {
                n++
            }
        }
    }

    // --- Actions ---
    function newGroup() {
        var dialog = pageStack.push(Qt.resolvedUrl("GroupNameDialog.qml"), { title: qsTr("New group") })
        dialog.accepted.connect(function() {
            appWindow.favoritesStore.createGroup(dialog.groupName)
        })
    }

    function renameGroup(groupId, name) {
        var dialog = pageStack.push(Qt.resolvedUrl("GroupNameDialog.qml"),
                                    { title: qsTr("Rename group"), initialName: name })
        dialog.accepted.connect(function() {
            appWindow.favoritesStore.renameGroup(groupId, dialog.groupName)
        })
    }

    function deleteSelected() {
        var urls = []
        for (var u in selectedUrls) urls.push(u)
        var groupIds = []
        for (var g in selectedGroups) groupIds.push(Number(g))
        remorse.execute(qsTr("Deleting %n item(s)", "", urls.length + groupIds.length), function() {
            if (urls.length > 0) appWindow.favoritesStore.removeMany(urls)
            if (groupIds.length > 0) appWindow.favoritesStore.deleteGroups(groupIds, false)
        })
        endSelection()
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: favModel

        PullDownMenu {
            MenuItem {
                visible: !page.selecting && appWindow.favoritesBackup.webdavEnabled
                text: qsTr("Sync now")
                onClicked: appWindow.favoritesBackup.syncNow(false)
            }
            MenuItem {
                visible: !page.selecting
                text: qsTr("Restore favorites …")
                onClicked: pageStack.push(Qt.resolvedUrl("RestorePage.qml"))
            }
            MenuItem {
                visible: !page.selecting && favModel.count > 0
                text: qsTr("Back up favorites")
                onClicked: {
                    if (appWindow.favoritesBackup.save(true)) {
                        appWindow.showMessage(qsTr("Favorites saved in Documents/Sailwave"))
                    } else {
                        appWindow.showMessage(qsTr("Favorites could not be saved"))
                    }
                }
            }
            MenuItem {
                visible: !page.selecting && favModel.count > 0
                text: qsTr("Export as M3U playlist")
                onClicked: {
                    appWindow.showMessage(appWindow.favoritesBackup.exportM3u().length > 0
                                          ? qsTr("Playlist saved in Documents/Sailwave")
                                          : qsTr("Playlist could not be saved"))
                }
            }
            MenuItem {
                visible: !page.selecting
                text: qsTr("New group")
                onClicked: page.newGroup()
            }
            MenuItem {
                visible: !page.selecting && favModel.count > 0
                text: qsTr("Select")
                onClicked: page.selecting = true
            }
            MenuItem {
                visible: page.selecting
                text: qsTr("Cancel selection")
                onClicked: page.endSelection()
            }
            MenuItem {
                visible: page.selecting
                enabled: page.selectedCount > 0
                text: qsTr("Delete selected")
                onClicked: page.deleteSelected()
            }
        }

        header: PageHeader {
            title: page.selecting ? qsTr("%n selected", "", page.selectedCount) : qsTr("Manage favorites")
        }

        displaced: Transition {
            NumberAnimation { property: "y"; duration: 150; easing.type: Easing.InOutQuad }
        }

        delegate: ListItem {
            id: item
            width: listView.width
            contentHeight: model.isHeader ? Theme.itemSizeSmall : Theme.itemSizeMedium
            // No context menu while selecting or for "Other favorites"
            menu: page.selecting ? null
                  : model.isHeader ? (model.groupId > 0 ? groupMenu : null)
                  : favoriteMenu
            highlighted: down || menuOpen || page.dragIndex === index
                         || (page.selecting && page.isSelected(model.isHeader, model.groupId, model.url))

            readonly property string health: model.isHeader ? "" : appWindow.favoritesStore.healthOf(model.url)
            readonly property bool selectable: page.selecting && !(model.isHeader && model.groupId === 0)

            onClicked: {
                if (selectable) {
                    page.toggleSelected(model.isHeader, model.groupId, model.url)
                }
            }

            // Selection indicator
            Rectangle {
                id: selectMark
                visible: item.selectable
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSizeExtraSmall
                height: width
                radius: width / 2
                color: page.isSelected(model.isHeader, model.groupId, model.url) ? Theme.highlightColor : "transparent"
                border.width: Math.max(1, Math.round(Theme.pixelRatio * 2))
                border.color: Theme.highlightColor
            }

            // --- Group header ---
            Item {
                visible: model.isHeader
                anchors.fill: parent

                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: item.selectable ? Theme.horizontalPageMargin + selectMark.width + Theme.paddingMedium
                                                        : Theme.horizontalPageMargin
                    anchors.right: countLabel.left
                    anchors.rightMargin: Theme.paddingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    text: model.name
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeMedium
                    truncationMode: TruncationMode.Fade
                }
                Label {
                    id: countLabel
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: model.count
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // --- Favourite ---
            Item {
                visible: !model.isHeader
                anchors.fill: parent

                StationIcon {
                    id: icon
                    anchors.verticalCenter: parent.verticalCenter
                    x: item.selectable ? Theme.horizontalPageMargin + selectMark.width + Theme.paddingMedium
                                       : Theme.horizontalPageMargin
                    iconSize: Theme.iconSizeSmall
                    faviconUrl: model.favicon
                    homepageUrl: model.homepage
                    stationuuid: model.stationuuid
                    stationName: model.name
                }

                Column {
                    anchors.left: icon.right
                    anchors.leftMargin: Theme.paddingMedium
                    anchors.right: handle.left
                    anchors.rightMargin: Theme.paddingMedium
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        width: parent.width
                        text: model.name
                        color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                        truncationMode: TruncationMode.Fade
                    }
                    Label {
                        width: parent.width
                        text: item.health === "broken" ? qsTr("Not reachable at the moment")
                            : item.health === "missing" ? qsTr("No longer listed at radio-browser.info")
                            : (model.country || "") + (model.codec ? " · " + model.codec : "")
                              + (model.bitrate ? " · " + model.bitrate + " kbps" : "")
                        color: item.health.length > 0 ? Theme.highlightColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        truncationMode: TruncationMode.Fade
                    }
                }

                // Drag handle: three lines on the right; only here a drag
                // starts, so the list can still be scrolled everywhere else
                MouseArea {
                    id: handle
                    visible: !page.selecting
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.itemSizeSmall + Theme.horizontalPageMargin
                    height: parent.height
                    preventStealing: true

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.paddingSmall
                        Repeater {
                            model: 3
                            Rectangle {
                                width: Theme.iconSizeSmall
                                height: Math.max(2, Math.round(Theme.paddingSmall / 2))
                                radius: height / 2
                                color: handle.pressed ? Theme.highlightColor : Theme.primaryColor
                            }
                        }
                    }

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

            Component {
                id: groupMenu
                ContextMenu {
                    MenuItem {
                        text: qsTr("Rename")
                        onClicked: page.renameGroup(model.groupId, model.name)
                    }
                    MenuItem {
                        text: qsTr("Move up")
                        onClicked: appWindow.favoritesStore.moveGroup(model.groupId, -1)
                    }
                    MenuItem {
                        text: qsTr("Move down")
                        onClicked: appWindow.favoritesStore.moveGroup(model.groupId, 1)
                    }
                    MenuItem {
                        text: qsTr("Delete group")
                        onClicked: {
                            // The callback runs after the countdown - the context menu (and its
                            // QML context) is gone by then, so names like appWindow would no
                            // longer resolve: take the objects into local variables now
                            var id = model.groupId
                            var store = appWindow.favoritesStore
                            remorse.execute(qsTr("Deleting group"), function() {
                                store.deleteGroup(id, false)
                            })
                        }
                    }
                    MenuItem {
                        text: qsTr("Delete group and favorites")
                        onClicked: {
                            // Objects taken now, see "Delete group"
                            var id = model.groupId
                            var store = appWindow.favoritesStore
                            var backup = appWindow.favoritesBackup
                            remorse.execute(qsTr("Deleting group and favorites"), function() {
                                // Backup state first, so it can be restored
                                backup.save(true)
                                store.deleteGroup(id, true)
                            })
                        }
                    }
                }
            }

            Component {
                id: favoriteMenu
                ContextMenu {
                    MenuItem {
                        visible: item.health.length > 0
                        text: qsTr("Find alternative")
                        onClicked: appWindow.searchStationsFor(model.name)
                    }
                    MenuItem {
                        text: qsTr("Remove from favorites")
                        onClicked: {
                            // Objects taken now, see "Delete group"
                            var url = model.url
                            var store = appWindow.favoritesStore
                            item.remorseAction(qsTr("Removing favorite"), function() {
                                store.remove(url)
                            })
                        }
                    }
                }
            }
        }

        // Generous space below the last favourite: its drag handle must not
        // sit at the bottom screen edge, where a swipe starts the system
        // gesture (app grid) instead of the drag
        footer: Item {
            width: listView.width
            height: Theme.itemSizeLarge * 2
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: favModel.count === 0
            text: qsTr("No favorites yet")
            hintText: qsTr("Stations can be saved as favorites with the heart symbol.")
        }
    }
}
