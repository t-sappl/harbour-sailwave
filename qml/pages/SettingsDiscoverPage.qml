// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"
import "../CountryData.js" as CountryData

// Settings -> Discover: home country (top stations, recommendations) and
// the automatic vote for new favourites.
Page {
    id: settingsPage
    objectName: "settingsDiscoverPage"

    function countryName(code) {
        var c = CountryData.findCountry(code)
        return c ? CountryData.getLocalizedName(c) : code
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Discover")
            }

            ValueButton {
                label: qsTr("Home country")
                value: appWindow.appSettings.homeCountry.length > 0
                       ? settingsPage.countryName(appWindow.appSettings.homeCountry)
                       : (appWindow.userCountry.length > 0
                          ? qsTr("Automatic (%1)").arg(settingsPage.countryName(appWindow.userCountry))
                          : qsTr("Automatic"))
                description: qsTr("Used for top stations and recommendations. "
                                  + "When set to automatic, the country is detected from the IP address via ipapi.co.")
                onClicked: pageStack.push(Qt.resolvedUrl("CountryPickerPage.qml"))
            }

            TextSwitch {
                text: qsTr("Vote when saving a favorite")
                description: qsTr("Automatically votes for the station on radio-browser.info when it is saved "
                                  + "as a favorite. This supports the Radio Browser community. "
                                  + "At most one vote per station and day.")
                checked: appWindow.appSettings.autoVoteOnFavorite
                automaticCheck: false
                onClicked: appWindow.appSettings.autoVoteOnFavorite = !appWindow.appSettings.autoVoteOnFavorite
            }
        }

        VerticalScrollDecorator {}
    }
}
