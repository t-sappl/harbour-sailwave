import QtQuick 2.6
import Sailfish.Silica 1.0

// A selectable chip for the filters of the advanced search. The touch area
// is a full Theme.itemSizeSmall high (Sailfish minimum); the visible pill
// inside is smaller. Selected: highlight background and colour; pressed:
// highlight colour.
BackgroundItem {
    id: chip

    property alias text: label.text
    property bool selected: false

    width: label.implicitWidth + 2 * Theme.paddingLarge
    height: Theme.itemSizeSmall
    // The pill shows the pressed state itself
    highlightedColor: "transparent"

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Theme.paddingSmall
        x: Theme.paddingSmall / 2
        height: Theme.itemSizeExtraSmall
        radius: height / 2
        color: chip.selected ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                             : "transparent"
        border.width: Math.max(1, Math.round(Theme.pixelRatio))
        border.color: chip.selected || chip.highlighted ? Theme.highlightColor
                                                        : Theme.rgba(Theme.primaryColor, 0.3)
    }

    Label {
        id: label
        anchors.centerIn: parent
        font.pixelSize: Theme.fontSizeSmall
        color: chip.selected || chip.highlighted ? Theme.highlightColor : Theme.primaryColor
    }
}
