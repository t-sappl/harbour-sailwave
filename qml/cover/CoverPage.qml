import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"

CoverBackground {
    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingSmall

        // As in the MPRIS image: if there is an album cover (iTunes), it fills
        // the image and the station logo sits as a light badge in the bottom
        // right. Otherwise just the station logo, as before.
        Item {
            id: artBox
            anchors.horizontalCenter: parent.horizontalCenter
            visible: appWindow.currentStation !== null

            property string albumUrl: appWindow.currentTrackArtUrl || ""
            readonly property bool hasAlbum: albumUrl.length > 0 && albumImage.status === Image.Ready

            // Without an album cover the box has the fixed logo size. Not bound
            // to stationIcon.width: the icon size depends on the badge size,
            // which depends on this width - that was a binding loop.
            width: hasAlbum ? parent.width * 0.8 : Theme.iconSizeLarge
            height: width

            Image {
                id: albumImage
                anchors.fill: parent
                source: artBox.albumUrl
                sourceSize.width: 512
                sourceSize.height: 512
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                visible: opacity > 0
                opacity: artBox.hasAlbum ? 1.0 : 0.0
                Behavior on opacity { FadeAnimation { duration: 400 } }
            }

            Rectangle {
                id: logoBadge
                readonly property bool small: artBox.hasAlbum
                width: small ? artBox.width * 0.34 : Theme.iconSizeLarge
                height: width
                x: small ? artBox.width - width - artBox.width * 0.04 : 0
                y: small ? artBox.height - height - artBox.height * 0.04 : 0
                radius: small ? width * 0.2 : 0
                color: small ? "white" : "transparent"

                StationIcon {
                    id: stationIcon
                    anchors.centerIn: parent
                    faviconUrl: (appWindow.currentStation && appWindow.currentStation.favicon) || ""
                    homepageUrl: (appWindow.currentStation && appWindow.currentStation.homepage) || ""
                    stationuuid: (appWindow.currentStation && appWindow.currentStation.stationuuid) || ""
                    stationName: (appWindow.currentStation && appWindow.currentStation.name) || ""
                    iconSize: logoBadge.small ? Math.round(logoBadge.width * 0.76) : Theme.iconSizeLarge
                }
            }

            // Sleep timer active: moon + remaining time at the top left. With an
            // album cover it sits inside the corner; with the smaller station logo
            // it sticks out slightly so it does not cover the logo too much.
            SleepBadge {
                x: artBox.hasAlbum ? Theme.paddingSmall : -Theme.paddingMedium
                y: artBox.hasAlbum ? Theme.paddingSmall : -Theme.paddingMedium
                z: 2
            }
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: artBox.hasAlbum ? 1 : 2
            elide: Text.ElideRight
            font.pixelSize: artBox.hasAlbum ? Theme.fontSizeSmall : Theme.fontSizeMedium
            text: (appWindow.currentStation && appWindow.currentStation.name) || qsTr("Sailwave")
            color: Theme.primaryColor
        }

        Label {
            width: parent.width
            visible: text.length > 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: appWindow.currentTrackDisplay || ""
        }
    }

    // Play/pause, plus "next favourite" as a second action when there is a
    // favourite to switch to (CoverActionList cannot hide single actions,
    // so there are two lists and only one of them is enabled)
    CoverActionList {
        enabled: appWindow.canPlayNextFavorite
        CoverAction {
            iconSource: appWindow.isPlaying ? "image://theme/icon-cover-pause" : "image://theme/icon-cover-play"
            onTriggered: appWindow.togglePlayback()
        }
        CoverAction {
            iconSource: "image://theme/icon-cover-next"
            onTriggered: appWindow.playNextFavorite()
        }
    }

    CoverActionList {
        enabled: !appWindow.canPlayNextFavorite
        CoverAction {
            iconSource: appWindow.isPlaying ? "image://theme/icon-cover-pause" : "image://theme/icon-cover-play"
            onTriggered: appWindow.togglePlayback()
        }
    }
}
