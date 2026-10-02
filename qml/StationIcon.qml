import QtQuick 2.6
import Sailfish.Silica 1.0
import "StationLogo.js" as StationLogo

Item {
    id: root

    property string faviconUrl: ""
    property string homepageUrl: ""
    property string stationName: ""
    property string stationuuid: ""
    property int iconSize: Theme.iconSizeMedium

    property string homepageOverride: ""

    function refreshHomepageOverride() {
        if (!root.stationuuid) {
            homepageOverride = ""
            return
        }
        homepageOverride = appWindow.persistentState.getHomepageOverride(root.stationuuid)
    }

    onStationuuidChanged: refreshHomepageOverride()

    // Qt 5.6 compatible Connections block
    Connections {
        target: root.visible ? appWindow : null
        onHomepageOverridesUpdated: root.refreshHomepageOverride()
    }

    // Logo sources come from StationLogo.js - the same logic CoverArtCache uses
    // for the lock screen image, so both always show the same logo.
    readonly property string resolvedHomepage: StationLogo.resolveHomepage(root.homepageUrl, root.homepageOverride)
    readonly property string googleFaviconUrl: StationLogo.googleFaviconUrl(root.resolvedHomepage, 64)

    readonly property bool primaryUsable: root.faviconUrl.length > 0 && !appWindow.isIconUrlBroken(root.faviconUrl)
    readonly property bool fallbackUsable: !primaryUsable && root.googleFaviconUrl.length > 0 && !appWindow.isIconUrlBroken(root.googleFaviconUrl)

    width: iconSize
    height: iconSize

    // Level 3: letter avatar - only when there is no logo to show, NOT while
    // a logo is still loading. Otherwise the avatar flashes up briefly on
    // every page that shows a logo in a different size than the list (e.g.
    // the station info page: the image cache keeps one entry per size, so
    // the larger logo is fetched again). While loading, the area stays empty.
    readonly property bool imageLoading: primaryImg.status === Image.Loading
                                         || fallbackImg.status === Image.Loading
    readonly property bool imageReady: primaryImg.status === Image.Ready
                                       || fallbackImg.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        radius: width / 5
        color: paletteColor(root.stationName)
        visible: !root.imageReady && !root.imageLoading

        Label {
            anchors.centerIn: parent
            text: fallbackLetters(root.stationName)
            color: "white"
            font.pixelSize: root.iconSize * 0.42
            font.bold: true
        }
    }

    // Level 1: primary favicon
    Image {
        id: primaryImg
        anchors.fill: parent
        // FIX 1: URL encoding prevents HTTP 400 (Bad Request) with special characters
        source: root.primaryUsable ? encodeURI(root.faviconUrl) : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: root.iconSize
        sourceSize.height: root.iconSize
        visible: status === Image.Ready
        onStatusChanged: {
            if (status === Image.Error && root.faviconUrl) {
                appWindow.markIconUrlBroken(root.faviconUrl)
            }
        }
    }

    // Level 2: fallback favicon (Google)
    Image {
        id: fallbackImg
        anchors.fill: parent
        // FIX 2: encode fallback URLs as well
        source: root.fallbackUsable ? encodeURI(root.googleFaviconUrl) : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: root.iconSize
        sourceSize.height: root.iconSize
        visible: status === Image.Ready
        onStatusChanged: {
            if (status === Image.Error && root.googleFaviconUrl) {
                appWindow.markIconUrlBroken(root.googleFaviconUrl)
            }
        }
    }

    function fallbackLetters(name) {
        if (!name) return "?"
        var trimmed = name.trim()
        if (trimmed.length === 0) return "?"
        var spaceIdx = trimmed.indexOf(" ")
        if (spaceIdx !== -1 && spaceIdx < trimmed.length - 1) {
            return (trimmed.charAt(0) + trimmed.charAt(spaceIdx + 1)).toUpperCase()
        }
        return trimmed.substring(0, 2).toUpperCase()
    }

    function paletteColor(name) {
        if (!name) return "#1C71D8"
        var hash = 0
        for (var i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash)
        }
        var colors = [
            "#1C71D8", "#26A269", "#E5A50A", "#C64600",
            "#A51D2D", "#9141AC", "#C9184A", "#0891A6",
            "#813D9C", "#3A944A", "#1A5FB4", "#E66100"
        ]
        return colors[Math.abs(hash) % 12]
    }
}
