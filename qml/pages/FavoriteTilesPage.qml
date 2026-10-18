// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"

// Favorite tiles (1.1): the favourites as large tiles (logo + name), e.g.
// for the car. An extra ring page left of the start page, shown according
// to the setting "Favorite tiles" (always / only in landscape) - see
// appWindow.tilesInRing. Tap plays, press and hold opens a menu with
// "Station info". Groups as on the start page: a heading per group,
// favourites without a group last under "Other favorites".
// In landscape the player panel is on the right (appWindow.playerPanelWidth),
// in portrait the PlayerBar at the bottom.
Page {
    id: page

    property bool ringMember: false

    onStatusChanged: {
        if (ringMember && status === PageStatus.Active) {
            appWindow.ringPageActivated(page)
        }
        // Built the first time the page is shown (no logo downloads for a
        // page that is never opened), then kept up to date
        if (status !== PageStatus.Inactive && !built) {
            rebuild()
        }
    }

    // [{ name, items: [favourite, ...] }] in start page order
    property var sections: []
    property bool built: false

    function rebuild() {
        built = true
        var favs = appWindow.favoritesStore.favorites
        var groups = appWindow.favoritesStore.groups
        var result = []
        if (groups.length === 0) {
            if (favs.length > 0) {
                result.push({ name: "", items: favs })
            }
        } else {
            for (var i = 0; i < groups.length; i++) {
                var inGroup = appWindow.favoritesStore.favoritesOfGroup(groups[i].id)
                if (inGroup.length > 0) {
                    result.push({ name: groups[i].name, items: inGroup })
                }
            }
            var ungrouped = appWindow.favoritesStore.favoritesOfGroup(0)
            if (ungrouped.length > 0) {
                result.push({ name: qsTr("Other favorites"), items: ungrouped })
            }
        }
        sections = result
    }

    Connections {
        target: appWindow.favoritesStore
        ignoreUnknownSignals: true
        onFavoritesChanged: if (page.built) page.rebuild()
    }

    // playStation() tidies up the passed object - hand over a copy, not the
    // store's own entry
    function play(fav) {
        var st = {}
        for (var key in fav) {
            st[key] = fav[key]
        }
        appWindow.playStation(st)
    }

    // Width left for the tiles (left of the player panel in landscape)
    readonly property real areaWidth: width - appWindow.playerPanelWidth - 2 * Theme.paddingLarge
    // Tile size from the portrait width as a fixed unit: 3 tiles side by
    // side in portrait on a phone, about 4 in landscape next to the panel,
    // more on tablets
    readonly property int columns: Math.max(2, Math.floor(areaWidth / (Screen.width / 3.3)))
    readonly property real tileSize: Math.floor(areaWidth / columns)

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        anchors.bottomMargin: appWindow.playerBarBaseHeight
        anchors.rightMargin: appWindow.playerPanelWidth
        contentHeight: column.height + appWindow.playerBarOverlap + Theme.paddingLarge

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
        }

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Favorites")
            }

            Repeater {
                model: page.sections

                Column {
                    width: column.width

                    SectionHeader {
                        visible: modelData.name.length > 0
                        text: modelData.name
                    }

                    Flow {
                        x: Theme.paddingLarge
                        width: page.columns * page.tileSize

                        Repeater {
                            model: modelData.items

                            ListItem {
                                id: tile
                                width: page.tileSize
                                contentHeight: page.tileSize

                                readonly property var fav: modelData
                                readonly property bool playing: appWindow.currentStation
                                                                && appWindow.currentStation.url === fav.url
                                readonly property string health: appWindow.favoritesStore.healthOf(fav.url)

                                onClicked: page.play(fav)

                                menu: Component {
                                    ContextMenu {
                                        MenuItem {
                                            text: qsTr("Station info")
                                            onClicked: appWindow.openStationInfo(tile.fav)
                                        }
                                    }
                                }

                                // Tile background; the playing station is highlighted
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Theme.paddingSmall
                                    radius: Theme.paddingMedium
                                    color: Theme.rgba(Theme.highlightBackgroundColor,
                                                      tile.playing ? Theme.highlightBackgroundOpacity : 0.1)
                                    border.width: tile.playing ? Math.max(2, Math.round(Theme.pixelRatio * 2)) : 0
                                    border.color: Theme.highlightColor
                                }

                                StationIcon {
                                    id: logo
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Math.round(page.tileSize * 0.12)
                                    iconSize: Math.round(page.tileSize * 0.5)
                                    // Not reachable at the moment / no longer listed: dimmed
                                    opacity: tile.health.length > 0 ? 0.4 : 1.0
                                    faviconUrl: tile.fav.favicon || ""
                                    homepageUrl: tile.fav.homepage || ""
                                    stationName: tile.fav.name || ""
                                    stationuuid: tile.fav.stationuuid || ""
                                }

                                Label {
                                    anchors.top: logo.bottom
                                    anchors.topMargin: Theme.paddingSmall
                                    x: Theme.paddingMedium
                                    width: parent.width - 2 * Theme.paddingMedium
                                    horizontalAlignment: Text.AlignHCenter
                                    text: tile.fav.name
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: tile.playing
                                    color: (tile.playing || tile.highlighted) ? Theme.highlightColor : Theme.primaryColor
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }

        ViewPlaceholder {
            enabled: page.built && appWindow.favoritesStore.favorites.length === 0
            text: qsTr("No favorites yet")
            hintText: qsTr("Tap the heart next to a station to add it to your favorites.")
        }

        VerticalScrollDecorator {}
    }
}
