// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"

Page {
    id: aboutPage
    objectName: "aboutPage"

    // --- Fill in before publishing. Empty entries are
    // not shown.
    property string licenseName: "GPL 3.0 or later"
    property string sourceCodeUrl: "https://github.com/t-sappl/harbour-sailwave/"
    property string privacyPolicyUrl: "https://github.com/t-sappl/harbour-sailwave/blob/main/PRIVACY.md"
    property string issuesUrl: "https://github.com/t-sappl/harbour-sailwave/issues"
    // Not translated (name)
    property string copyright: "\u00A9 2026 Thomas Sappl"

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge * 2

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("About Sailwave")
            }

            // App icon (standard path for installed Sailfish apps);
            // if it is missing, the space simply collapses
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "/usr/share/icons/hicolor/172x172/apps/harbour-sailwave-radio.png"
                width: Theme.iconSizeExtraLarge
                height: width
                sourceSize.width: width
                sourceSize.height: height
                visible: status === Image.Ready

                // Hidden: double tap shows all one-time hints again (as in
                // Sailcast)
                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: {
                        appWindow.appSettings.resetHints()
                        appWindow.showMessage(qsTr("Hints will be shown again"))
                    }
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Sailwave"
                font.pixelSize: Theme.fontSizeExtraLarge
                color: Theme.highlightColor
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Version %1").arg(appWindow.appVersion)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
                text: qsTr("Internet radio for Sailfish OS \u2013 thousands of stations from all over the world: stations for you, search by genre, language and country, favorites with groups and tiles, track history with covers, sleep timer and backup.")
            }

            SectionHeader { text: qsTr("License and source code") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: aboutPage.copyright + ". " + qsTr("Free software under the GNU General Public License, version 3 or later.")
            }

            ActionPill {
                visible: aboutPage.sourceCodeUrl.length > 0
                kind: "secondary"
                x: Theme.horizontalPageMargin
                text: qsTr("Source code")
                onClicked: Qt.openUrlExternally(aboutPage.sourceCodeUrl)
            }

            ActionPill {
                visible: aboutPage.privacyPolicyUrl.length > 0
                kind: "secondary"
                x: Theme.horizontalPageMargin
                text: qsTr("Privacy policy")
                onClicked: Qt.openUrlExternally(aboutPage.privacyPolicyUrl)
            }

            ActionPill {
                visible: aboutPage.issuesUrl.length > 0
                kind: "secondary"
                x: Theme.horizontalPageMargin
                text: qsTr("Report a problem")
                onClicked: Qt.openUrlExternally(aboutPage.issuesUrl)
            }

            SectionHeader { text: qsTr("Thanks") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                linkColor: Theme.highlightColor
                textFormat: Text.StyledText
                text: qsTr("Station data: the community database %1. Covers and genres: iTunes Search API. Logos: the stations' websites. What is sent to whom can be checked and switched off in the settings under Privacy.")
                .arg("<a href=\"https://www.radio-browser.info\">radio-browser.info</a>")
                onLinkActivated: Qt.openUrlExternally(link)
            }

            SectionHeader { text: qsTr("Development") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: qsTr("Developed with the assistance of an AI model (Claude by Anthropic). "
                + "All changes are reviewed and tested by the developer on a Jolla Phone (2026).")
            }
        }

        VerticalScrollDecorator {}
    }
}
