import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"

ListItem {
    id: delegateItem
    contentHeight: Theme.itemSizeMedium

    // true in the "Similar stations" of an info page: the (i) button then
    // replaces that info page instead of stacking a new one on top
    property bool replaceInfoPage: false

    // Shown instead of country/codec in the second line, e.g. for a
    // favourite whose stream is not reachable (see FavoritesStore.health)
    property string warningText: ""

    // Sort mode of the favourites: the info and heart buttons make room for
    // the drag handle
    property bool buttonsHidden: false

    StationIcon {
        id: stationIcon
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.horizontalPageMargin
        faviconUrl: model.favicon || ""
        homepageUrl: model.homepage || ""
        stationuuid: model.stationuuid || ""
        stationName: model.name || ""
        iconSize: Theme.iconSizeSmall
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: stationIcon.right
        anchors.right: infoButton.left
        anchors.leftMargin: Theme.paddingMedium
        anchors.rightMargin: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall / 2

        Label {
            width: parent.width
            text: model.name || ""
            truncationMode: TruncationMode.Fade
            color: delegateItem.highlighted ? Theme.highlightColor : Theme.primaryColor
        }
        Label {
            width: parent.width
            text: delegateItem.warningText.length > 0
                  ? delegateItem.warningText
                  : (model.country || "") + (model.codec ? " · " + model.codec : "") + (model.bitrate ? " · " + model.bitrate + " kbps" : "")
            font.pixelSize: Theme.fontSizeExtraSmall
            color: delegateItem.warningText.length > 0 ? Theme.highlightColor : Theme.secondaryColor
            truncationMode: TruncationMode.Fade
        }
        Label {
            width: parent.width
            visible: text.length > 0
            text: model.tags ? model.tags.split(",").slice(0, 3).join(" · ") : ""
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.secondaryHighlightColor
            truncationMode: TruncationMode.Fade
        }
    }

    IconButton {
        id: infoButton
        visible: !delegateItem.buttonsHidden
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: favoriteButton.left
        icon.source: "image://theme/icon-m-about"
        onClicked: appWindow.openStationInfo({
            name: model.name,
            url: model.url,
            url_resolved: model.url_resolved,
            country: model.country,
            codec: model.codec,
            bitrate: model.bitrate,
            stationuuid: model.stationuuid,
            favicon: model.favicon,
            homepage: model.homepage,
            tags: model.tags,
            language: model.language,
            countrycode: model.countrycode
        }, delegateItem.replaceInfoPage)
    }

    IconButton {
        id: favoriteButton
        visible: !delegateItem.buttonsHidden
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Theme.horizontalPageMargin
        icon.source: appWindow.favoritesStore.isFavorite(model.url)
                     ? "image://theme/icon-m-favorite-selected"
                     : "image://theme/icon-m-favorite"
        onClicked: appWindow.favoritesStore.toggle({
            name: model.name,
            url: model.url,
            url_resolved: model.url_resolved,
            country: model.country,
            codec: model.codec,
            bitrate: model.bitrate,
            stationuuid: model.stationuuid,
            favicon: model.favicon,
            homepage: model.homepage,
            tags: model.tags,
            language: model.language,
            countrycode: model.countrycode
        })
    }

    onClicked: {
        // Pass all fields (the same as for the heart button): the current station
        // feeds into the recommendation taste profile (tags, language, country),
        // and the station history stores country, codec and bitrate for the list.
        appWindow.playStation({
            name: model.name,
            url: model.url,
            url_resolved: model.url_resolved,
            country: model.country,
            codec: model.codec,
            bitrate: model.bitrate,
            stationuuid: model.stationuuid,
            favicon: model.favicon,
            homepage: model.homepage,
            tags: model.tags,
            language: model.language,
            countrycode: model.countrycode
        })
    }
}
