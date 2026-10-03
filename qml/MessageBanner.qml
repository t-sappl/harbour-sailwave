// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0

// Short, self-hiding message at the bottom of the screen (above the
// PlayerBar), e.g. when a station cannot be reached. Show it with
// appWindow.showMessage(text).
Rectangle {
    id: banner

    function show(text) {
        bannerLabel.text = text
        opacity = 1
        hideTimer.restart()
    }

    width: Math.min(bannerLabel.implicitWidth + 2 * Theme.paddingLarge,
                    parent.width - 2 * Theme.horizontalPageMargin)
    height: bannerLabel.height + 2 * Theme.paddingMedium
    radius: Theme.paddingSmall
    color: Theme.rgba(Theme.highlightBackgroundColor, 0.9)
    opacity: 0
    visible: opacity > 0

    Behavior on opacity { FadeAnimation {} }

    Label {
        id: bannerLabel
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontSizeSmall
    }

    Timer {
        id: hideTimer
        interval: 4000
        onTriggered: banner.opacity = 0
    }

    // Tapping dismisses the message early
    MouseArea {
        anchors.fill: parent
        onClicked: banner.opacity = 0
    }
}
