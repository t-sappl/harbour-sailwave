// SPDX-License-Identifier: GPL-3.0-or-later
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
    // Soft shadow under the tile (logo badge on an album cover)
    property bool shadow: false

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
    // Google fallback only if allowed in the settings (privacy)
    readonly property bool fallbackUsable: !primaryUsable && appWindow.appSettings.googleLogoFallback
                                           && root.googleFaviconUrl.length > 0 && !appWindow.isIconUrlBroken(root.googleFaviconUrl)

    width: iconSize
    height: iconSize

    readonly property bool imageLoading: primaryImg.status === Image.Loading
                                         || fallbackImg.status === Image.Loading
    // Google answers with a 16 px placeholder globe for hosts without a
    // favicon: that is not a logo, show the letter avatar instead
    readonly property bool fallbackOk: fallbackImg.status === Image.Ready
                                       && fallbackImg.implicitWidth >= 24
    readonly property bool imageReady: primaryImg.status === Image.Ready
                                       || fallbackOk
    readonly property Item activeImage: primaryImg.status === Image.Ready ? primaryImg : fallbackImg
    // URL of the logo actually shown (key for the per-URL analysis)
    readonly property string activeUrl: primaryImg.status === Image.Ready ? root.faviconUrl
                                        : (root.fallbackOk ? root.googleFaviconUrl : "")

    // Level 3: letter avatar - only when there is no logo to show, NOT while
    // a logo is still loading (see the comment in the earlier versions: it
    // flashed up on every page that shows a logo in a different size).

    // (v128l) One look for every logo, on every ambience and on every album
    // cover - the tile brings its own contrast:
    //  - a logo with transparent edges (or a wide one) gets a tile: light
    //    (#f2f2f2) for dark and coloured logos, dark (#2b2b2b) only for very
    //    bright logos (brightness of the opaque pixels > 0.8), with a hairline
    //    so that the tile does not melt into a similar background;
    //  - a logo that fills its square (opaque edges, e.g. SRF) gets no tile
    //    and fills the whole box;
    //  - everything is clipped with the same rounded corners.
    // Drawn with plain Items (Rectangle + Image). The decision comes from a
    // 16x16 pixel check per URL (Canvas below), cached in appWindow. Until it
    // is known - or if the check does not work - the logo gets the light
    // tile: never black, never empty. (128h-k composed the logo in a custom
    // shader; on the device some logos arrived there without texture.)
    readonly property var look: appWindow.logoLook(root.activeUrl)
    readonly property bool hasTile: root.look ? root.look.tile : true
    readonly property bool darkTile: root.look ? root.look.dark : false
    readonly property int logoMargin: root.hasTile ? Math.round(root.iconSize * 0.12) : 0

    Rectangle {
        // soft shadow, outside the clipped content
        visible: root.shadow && (root.imageReady || (!root.imageLoading))
        x: 0
        y: Math.max(1, root.iconSize * 0.02)
        width: root.iconSize
        height: root.iconSize
        radius: root.iconSize * 0.2
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    // Pixel check, once per logo URL. It decides tile / no tile and the tile
    // colour, and recognises empty images (fully transparent, or opaque and
    // one-coloured - Google answers like that for hosts without a favicon):
    // such a URL is marked as broken -> next level (Google, letter avatar).
    // opacity 0 instead of visible: false, so that the Canvas still paints.
    Canvas {
        id: logoCheck
        width: 16; height: 16
        opacity: 0
        enabled: false
        renderTarget: Canvas.Image
        property string checkUrl: root.imageReady && root.activeUrl.length > 0 && !root.look
                                  ? root.activeUrl : ""
        property string loadUrl: checkUrl.length > 0 ? encodeURI(checkUrl) : ""
        onLoadUrlChanged: {
            if (loadUrl === "") return
            loadImage(loadUrl)
            if (isImageLoaded(loadUrl)) requestPaint()
        }
        onImageLoaded: requestPaint()
        onPaint: {
            var key = checkUrl
            var src = loadUrl
            if (src === "" || !isImageLoaded(src)) return
            var c = getContext("2d")
            c.clearRect(0, 0, 16, 16)
            c.drawImage(src, 0, 0, 16, 16)
            var d = c.getImageData(0, 0, 16, 16).data
            var n = 0, mn = 255, mx = 0, sumL = 0, cntL = 0, edgeTop = 0, edgeBottom = 0
            for (var y = 0; y < 16; y++) {
                for (var x = 0; x < 16; x++) {
                    var i = (y * 16 + x) * 4
                    var a = d[i + 3]
                    if (y === 0) edgeTop += a
                    if (y === 15) edgeBottom += a
                    if (a > 40) {
                        n++
                        var l = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]
                        if (l < mn) mn = l
                        if (l > mx) mx = l
                        if (a > 128) { sumL += l; cntL++ }
                    }
                }
            }
            if (n < 10 || (n > 240 && mx - mn < 12)) {
                // empty image: no logo
                appWindow.markIconUrlBroken(key)
                return
            }
            var img = root.activeImage
            var wide = img && img.implicitHeight > 0
                       && img.implicitWidth > img.implicitHeight * 1.05
            var opaqueEdges = Math.min(edgeTop, edgeBottom) / 16 > 153
            var lum = cntL > 0 ? sumL / cntL / 255 : 0.5
            appWindow.setLogoLook(key, { tile: wide || !opaqueEdges, dark: lum > 0.8 })
        }
    }

    Item {
        id: content
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: ShaderEffect {
            property real corner: 0.2
            fragmentShader: "
                varying highp vec2 qt_TexCoord0;
                uniform lowp float qt_Opacity;
                uniform sampler2D source;
                uniform highp float corner;
                void main() {
                    highp vec2 p = abs(qt_TexCoord0 - vec2(0.5)) - vec2(0.5 - corner);
                    highp float d = length(max(p, vec2(0.0))) - corner;
                    lowp float mask = 1.0 - smoothstep(-0.01, 0.01, d);
                    gl_FragColor = texture2D(source, qt_TexCoord0) * mask * qt_Opacity;
                }"
        }

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

        // Tile behind logos with transparent edges
        Rectangle {
            anchors.fill: parent
            radius: width / 5
            visible: root.imageReady && root.hasTile
            color: root.darkTile ? "#2b2b2b" : "#f2f2f2"
            border.width: Math.max(1, Math.round(root.iconSize / 60))
            border.color: root.darkTile ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.14)
        }

        // Level 1: primary favicon
        Image {
            id: primaryImg
            anchors.fill: parent
            anchors.margins: root.logoMargin
            // FIX 1: URL encoding prevents HTTP 400 (Bad Request) with special characters
            source: root.primaryUsable ? encodeURI(root.faviconUrl) : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
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
            anchors.margins: root.logoMargin
            // FIX 2: encode fallback URLs as well
            source: root.fallbackUsable ? encodeURI(root.googleFaviconUrl) : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            sourceSize.width: root.iconSize
            sourceSize.height: root.iconSize
            visible: primaryImg.status !== Image.Ready && root.fallbackOk
            onStatusChanged: {
                if (status === Image.Error && root.googleFaviconUrl) {
                    appWindow.markIconUrlBroken(root.googleFaviconUrl)
                }
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
