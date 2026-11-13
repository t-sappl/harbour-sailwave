// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// A small line below the page header of each ring page: the left neighbour
// at the left edge, the right neighbour at the right edge, the middle empty.
// It makes the pages visible that are otherwise only reached by swiping;
// a tap goes there, like the swipe. The ring decides who the neighbours are
// (the favorite tiles are only in it when switched on). Same design as in
// Sailcast. With a large font the names give way to the bare arrows.
Item {
    id: line

    // The ring page this line sits on
    property Page ringPage: null

    readonly property Page prevPage: ringPage ? appWindow.prevRingPage(ringPage) : null
    readonly property Page nextPage: ringPage ? appWindow.nextRingPage(ringPage) : null
    readonly property string prevName: appWindow.ringPageTitle(prevPage)
    readonly property string nextName: appWindow.ringPageTitle(nextPage)

    readonly property real half: (width - 2 * Theme.horizontalPageMargin) / 2
    // Large and in the highlight colour, so the line reads as navigation;
    // the names stay small
    readonly property real arrowSize: Theme.fontSizeLarge

    width: parent ? parent.width : Screen.width
    height: ringPage && prevPage && nextPage && prevPage !== ringPage ? Theme.itemSizeExtraSmall : 0
    visible: height > 0

    BackgroundItem {
        id: prevItem
        anchors.left: parent.left
        width: parent.width / 2
        height: parent.height
        onClicked: if (pageStack.depth > 1 && !pageStack.busy) pageStack.navigateBack()

        Row {
            anchors {
                left: parent.left
                leftMargin: Theme.horizontalPageMargin
                verticalCenter: parent.verticalCenter
            }
            spacing: Theme.paddingSmall
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "‹"
                font.pixelSize: line.arrowSize
                color: Theme.highlightColor
            }
            Label {
                // The name is shortened before it goes; only a sliver of
                // room drops it
                visible: line.half - line.arrowSize > Theme.paddingLarge * 2
                width: Math.min(implicitWidth, line.half - line.arrowSize - Theme.paddingSmall)
                truncationMode: TruncationMode.Fade
                anchors.verticalCenter: parent.verticalCenter
                text: line.prevName
                font.pixelSize: Theme.fontSizeExtraSmall
                color: prevItem.highlighted ? Theme.highlightColor : Theme.secondaryColor
            }
        }
    }

    BackgroundItem {
        id: nextItem
        anchors.right: parent.right
        width: parent.width / 2
        height: parent.height
        readonly property var curPage: pageStack.currentPage
        onClicked: if (curPage && curPage.canNavigateForward && !pageStack.busy) pageStack.navigateForward()

        Row {
            anchors {
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
                verticalCenter: parent.verticalCenter
            }
            spacing: Theme.paddingSmall
            Label {
                visible: line.half - line.arrowSize > Theme.paddingLarge * 2
                width: Math.min(implicitWidth, line.half - line.arrowSize - Theme.paddingSmall)
                truncationMode: TruncationMode.Fade
                anchors.verticalCenter: parent.verticalCenter
                text: line.nextName
                font.pixelSize: Theme.fontSizeExtraSmall
                color: nextItem.highlighted ? Theme.highlightColor : Theme.secondaryColor
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                font.pixelSize: line.arrowSize
                color: Theme.highlightColor
            }
        }
    }
}
