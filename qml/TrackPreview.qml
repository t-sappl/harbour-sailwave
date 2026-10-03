// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "TrackText.js" as TrackText

// The latest titles of a station plus the entry "Open track history" -
// used on the station info page and in the expanded PlayerBar, so both look
// and behave the same. Rows are styled like the track history page: title
// in the primary colour, "Artist · Genre · Time" below it.
//
// visibleRows titles are visible at once; further titles can be scrolled
// within that area. "Open track history" stays fixed below it (it does not
// scroll along) and is kept deliberately quiet: small icon and the same
// text size as the titles, so it does not dominate the list.
Column {
    id: preview

    // ListModel with track history entries (title, itunesArtist,
    // itunesTitle, genre, timestamp)
    property alias model: listView.model
    property int visibleRows: 3

    signal openClicked()

    width: parent ? parent.width : 0

    readonly property real rowHeight: Theme.itemSizeSmall

    SilicaListView {
        id: listView
        width: parent.width
        height: Math.min(count, preview.visibleRows) * preview.rowHeight
        clip: true
        interactive: count > preview.visibleRows

        delegate: Item {
            width: listView.width
            height: preview.rowHeight

            readonly property var parts: TrackText.parts({
                title: model.title,
                itunesArtist: model.itunesArtist,
                itunesTitle: model.itunesTitle
            })

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    // One line here (fixed row height), see TrackText.clean
                    text: TrackText.oneLine(parent.parent.parts.title)
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    text: TrackText.details(parent.parent.parts.artist, model.genre, preview.formatTime(model.timestamp))
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }
        }

        VerticalScrollDecorator {}
    }

    // Navigation entry: small icon + label in the size of the titles, in the
    // primary colour, highlighted while pressed; full itemSizeSmall touch area
    BackgroundItem {
        id: openItem
        width: parent.width
        height: Theme.itemSizeSmall
        onClicked: preview.openClicked()

        Image {
            id: openIcon
            x: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconSizeSmall
            height: Theme.iconSizeSmall
            sourceSize.width: width
            sourceSize.height: height
            source: "image://theme/icon-m-history?" + (openItem.highlighted ? Theme.highlightColor : Theme.primaryColor)
        }
        Label {
            anchors.left: openIcon.right
            anchors.leftMargin: Theme.paddingMedium
            anchors.right: parent.right
            anchors.rightMargin: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            truncationMode: TruncationMode.Fade
            text: qsTr("Open track history")
            font.pixelSize: Theme.fontSizeSmall
            color: openItem.highlighted ? Theme.highlightColor : Theme.primaryColor
        }
    }

    function formatTime(ms) {
        if (!ms) return ""
        var d = new Date(ms)
        return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2)
    }
}
