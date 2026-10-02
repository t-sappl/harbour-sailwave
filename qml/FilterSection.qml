import QtQuick 2.6
import Sailfish.Silica 1.0

// Collapsible filter of the advanced search: a row with the name and the
// current selection (like a Silica ValueButton) that expands its selection
// right below it, on the same page - no extra page, no accept step.
// The content is only created while the section is open (or closing).
Column {
    id: section

    property string title
    property string value
    property bool expanded: false
    property Component contentComponent

    // The ListView whose header contains this section. A ListView header is
    // attached to the first list item, i.e. it grows UPWARDS: when this
    // section gets taller, everything above its lower edge - including its
    // own header row and filter field - moves up and seemed to "open
    // upwards". Each change of the expanded area's height is therefore
    // compensated by moving the view by the same amount, as long as the
    // lower edge of the area is on screen. The row that was tapped and the
    // filter field stay where they are, only the content below moves.
    // Changes completely above the visible area need no compensation.
    property Flickable flickable

    // true while this filter has a selection: shows a clear button in the
    // row (the same clear symbol as "reset all filters" and search fields)
    property bool clearable: false

    signal clicked()
    signal clearClicked()

    width: parent ? parent.width : 0

    property bool _loaded: false
    onExpandedChanged: if (expanded) _loaded = true

    BackgroundItem {
        id: headerItem
        width: parent.width
        height: Theme.itemSizeSmall
        onClicked: section.clicked()

        Label {
            id: titleLabel
            anchors.left: parent.left
            anchors.leftMargin: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            text: section.title
            color: headerItem.highlighted ? Theme.highlightColor : Theme.primaryColor
        }

        Label {
            anchors.left: titleLabel.right
            anchors.leftMargin: Theme.paddingMedium
            anchors.right: section.clearable ? clearButton.left : arrow.left
            anchors.rightMargin: section.clearable ? 0 : Theme.paddingSmall
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            truncationMode: TruncationMode.Fade
            text: section.value
            color: Theme.highlightColor
        }

        // Clears only this filter; does not expand or collapse the row
        IconButton {
            id: clearButton
            anchors.right: arrow.left
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.itemSizeSmall
            height: Theme.itemSizeSmall
            visible: section.clearable
            icon.source: "image://theme/icon-m-clear"
            onClicked: section.clearClicked()
        }

        // Same arrows as the other collapsible headers of the app
        Image {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: Theme.horizontalPageMargin - Theme.paddingMedium
            anchors.verticalCenter: parent.verticalCenter
            source: (section.expanded ? "image://theme/icon-m-down" : "image://theme/icon-m-right")
                    + "?" + (headerItem.highlighted ? Theme.highlightColor : Theme.primaryColor)
        }
    }

    Item {
        id: panel
        width: parent.width
        height: section.expanded ? contentLoader.height : 0
        clip: true

        property real lastHeight: 0
        onHeightChanged: {
            var delta = height - lastHeight
            var oldHeight = lastHeight
            lastHeight = height
            if (!section.flickable || delta === 0) {
                return
            }
            // Lower edge before the change, in view coordinates (the column
            // is laid out again only afterwards, so this is still the old
            // position)
            var lowerEdge = panel.mapToItem(section.flickable, 0, oldHeight).y
            if (lowerEdge >= 0) {
                section.flickable.contentY -= delta
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
                onRunningChanged: if (!running && !section.expanded) section._loaded = false
            }
        }

        Loader {
            id: contentLoader
            width: parent.width
            active: section._loaded
            sourceComponent: section.contentComponent
        }
    }
}
