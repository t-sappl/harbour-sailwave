// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"
import "RadioApi.js" as RadioApi
import "CountryData.js" as CountryData

ListItem {
    id: delegateItem
    // Grows with the text (large system font), never smaller than before
    contentHeight: Math.max(Theme.itemSizeMedium, textColumn.height + 2 * Theme.paddingMedium)

    // true in the "Similar stations" of an info page: the (i) button then
    // replaces that info page instead of stacking a new one on top
    property bool replaceInfoPage: false

    // Shown instead of country/codec in the second line, e.g. for a
    // favourite whose stream is not reachable (see FavoritesStore.health)
    property string warningText: ""

    // Sort mode of the favourites: the info and heart buttons make room for
    // the drag handle
    property bool buttonsHidden: false

    // This is the station that is playing (or paused) now: name in the accent
    // colour on a light band, like the current chapter in Sailcast
    readonly property bool isCurrent: appWindow.currentStation !== null
                                      && appWindow.currentStation !== undefined
                                      && !!model.url
                                      && appWindow.currentStation.url === model.url

    Rectangle {
        anchors.fill: parent
        visible: delegateItem.isCurrent
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.18)
    }

    StationIcon {
        id: stationIcon
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.horizontalPageMargin
        faviconUrl: model.favicon || ""
        homepageUrl: model.homepage || ""
        stationuuid: model.stationuuid || ""
        stationName: model.name || ""
        // 48 px on a 40 px iconSizeSmall: easier to recognise, the row stays
        // as high as before (TEST-PROTOCOL 37.14)
        iconSize: Math.round(Theme.iconSizeSmall * 1.2)
    }

    Column {
        id: textColumn
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: stationIcon.right
        anchors.right: infoButton.left
        anchors.leftMargin: Theme.paddingMedium
        anchors.rightMargin: Theme.horizontalPageMargin
        spacing: Theme.paddingSmall / 2

        Label {
            width: parent.width
            // Cleaned here too: favourites and history entries stored by
            // older versions may still contain the raw name
            text: RadioApi.displayName(model.name)
            truncationMode: TruncationMode.Fade
            color: (delegateItem.highlighted || delegateItem.isCurrent) ? Theme.highlightColor : Theme.primaryColor
        }
        Label {
            width: parent.width
            text: delegateItem.warningText.length > 0
                  ? delegateItem.warningText
                  : CountryData.displayName(model.countrycode, model.country) + (model.codec ? " · " + model.codec : "") + (model.bitrate ? " · " + model.bitrate + " kbps" : "")
            font.pixelSize: Theme.fontSizeExtraSmall
            color: delegateItem.warningText.length > 0 ? Theme.highlightColor : Theme.secondaryColor
            truncationMode: TruncationMode.Fade
        }
        Label {
            width: parent.width
            visible: text.length > 0
            text: RadioApi.displayTags(model.tags, 3, !model.bitrate).join(" · ")
            font.pixelSize: Theme.fontSizeTiny
            // Plain secondary text, not the blue of tappable things: the
            // tags are no links (as the categories on the Sailcast podcast page)
            color: Theme.rgba(Theme.secondaryColor, 0.75)
            truncationMode: TruncationMode.Fade
        }
    }

    IconButton {
        id: infoButton
        visible: !delegateItem.buttonsHidden
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: favoriteButton.left
        icon.source: "image://theme/icon-m-about"
        // Quieter than the favourite star: the name is the main thing in the
        // row, the (i) is a side path
        icon.color: Theme.rgba(Theme.primaryColor, 0.4)
        scale: 0.8
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
        // As in the player bar: smaller and dimmer, the highlight colour
        // marks a favourite (two bright icons per row were too loud)
        readonly property bool isFav: appWindow.favoritesStore.isFavorite(model.url)
        icon.color: isFav ? Theme.highlightColor : Theme.primaryColor
        scale: 0.85
        opacity: isFav ? 1.0 : 0.75
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
