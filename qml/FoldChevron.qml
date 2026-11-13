// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// The handle of a collapsible header, as in Sailcast's folders: a small
// chevron in the highlight colour that turns from "right" (collapsed) to
// "down" (expanded). It replaces the grey disc with a large arrow.
Image {
    id: chevron

    property bool collapsed: false
    property color tint: Theme.highlightColor

    width: Theme.iconSizeExtraSmall
    height: width
    sourceSize.width: width
    sourceSize.height: height
    source: "image://theme/icon-m-right?" + tint
    rotation: collapsed ? 0 : 90
    Behavior on rotation { NumberAnimation { duration: 150 } }
}
