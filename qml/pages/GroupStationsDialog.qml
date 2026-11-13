// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"

// Choose the stations of a group at once (as the podcasts of a folder in
// Sailcast): every favourite with a switch, on = in this group. Accepting
// moves the switched-on stations here (out of their previous group - one
// group per favourite) and the switched-off former members to "Other
// favorites". Shown after "New group"; stations that are in another group
// say so ("now in ...").
// Order: the members of the group on top (none for a new group), then the
// stations without a group, then the others - each alphabetical.
Dialog {
    id: page
    objectName: "groupStationsDialog"

    property int groupId: 0
    property string groupName: ""
    // url -> true/false where the user changed something
    property var changes: ({})

    // Fixed when the group is known, not re-sorted while switching
    property var stations: []
    onGroupIdChanged: {
        var list = appWindow.favoritesStore.favorites.slice()
        function rank(f) {
            return f.groupId === page.groupId ? 0 : (f.groupId === 0 ? 1 : 2)
        }
        list.sort(function(a, b) {
            var d = rank(a) - rank(b)
            if (d !== 0) return d
            var an = (a.name || "").toLowerCase()
            var bn = (b.name || "").toLowerCase()
            return an < bn ? -1 : (an > bn ? 1 : 0)
        })
        stations = list
    }

    function isChecked(station) {
        return changes.hasOwnProperty(station.url) ? changes[station.url] : station.groupId === groupId
    }

    function toggle(station) {
        var copy = {}
        for (var k in changes) {
            copy[k] = changes[k]
        }
        copy[station.url] = !isChecked(station)
        changes = copy
    }

    function setAll(on) {
        var copy = {}
        for (var i = 0; i < stations.length; i++) {
            copy[stations[i].url] = on
        }
        changes = copy
    }

    readonly property int checkedCount: {
        var n = 0
        for (var i = 0; i < stations.length; i++) {
            if (changes.hasOwnProperty(stations[i].url) ? changes[stations[i].url]
                                                        : stations[i].groupId === groupId) {
                n++
            }
        }
        return n
    }

    onAccepted: {
        var toGroup = []
        var toNone = []
        for (var i = 0; i < stations.length; i++) {
            var s = stations[i]
            if (!changes.hasOwnProperty(s.url)) continue
            var inside = s.groupId === groupId
            if (changes[s.url] && !inside) toGroup.push(s.url)
            else if (!changes[s.url] && inside) toNone.push(s.url)
        }
        appWindow.favoritesStore.moveManyToGroup(toGroup, groupId)
        appWindow.favoritesStore.moveManyToGroup(toNone, 0)
    }

    SilicaListView {
        id: list
        anchors.fill: parent
        currentIndex: -1
        model: page.stations

        header: Column {
            width: list.width
            DialogHeader {
                title: page.groupName
                acceptText: qsTr("Save")
            }
            Flow {
                visible: page.stations.length > 1
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                FilterChip {
                    text: qsTr("All")
                    selected: page.checkedCount === page.stations.length
                    onClicked: page.setAll(true)
                }
                FilterChip {
                    text: qsTr("None")
                    selected: page.checkedCount === 0
                    onClicked: page.setAll(false)
                }
            }
            Item { width: 1; height: Theme.paddingMedium }
        }

        delegate: TextSwitch {
            width: list.width
            text: modelData.name
            description: modelData.groupId > 0 && modelData.groupId !== page.groupId
                         ? qsTr("now in %1").arg(appWindow.favoritesStore.groupName(modelData.groupId)) : ""
            checked: page.isChecked(modelData)
            automaticCheck: false
            onClicked: page.toggle(modelData)
        }

        VerticalScrollDecorator {}
    }
}
