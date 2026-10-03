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
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("About Sailwave")
            }

            // App icon (standard path for installed Sailfish apps);
            // if it is missing, the space simply collapses
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "/usr/share/icons/hicolor/172x172/apps/harbour-sailwave.png"
                width: Theme.iconSizeExtraLarge
                height: width
                sourceSize.width: width
                sourceSize.height: height
                visible: status === Image.Ready

                // Hidden: press and hold shows all one-time hints again
                // (for testing)
                MouseArea {
                    anchors.fill: parent
                    onPressAndHold: {
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
                anchors.horizontalCenter: parent.horizontalCenter
                visible: aboutPage.copyright.length > 0
                text: aboutPage.copyright
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
                text: qsTr("Internet radio for Sailfish OS - thousands of stations from all over the world.")
            }

            DetailItem {
                visible: aboutPage.licenseName.length > 0
                label: qsTr("License")
                value: aboutPage.licenseName
            }

            SectionHeader { text: qsTr("Data sources") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                linkColor: Theme.highlightColor
                textFormat: Text.StyledText
                text: qsTr("Station data from the community database %1. "
                + "Station logos from the stations' websites, missing ones via Google's favicon service (can be turned off in the settings). "
                + "Album covers and genres from the iTunes Search API (can be turned off in the settings). "
                + "Home country detected via ipapi.co or api.country.is (only while set to automatic in the settings).")
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

            Item { width: 1; height: Theme.paddingMedium }

            ButtonLayout {
                Button {
                    visible: aboutPage.sourceCodeUrl.length > 0
                    text: qsTr("Source code")
                    onClicked: Qt.openUrlExternally(aboutPage.sourceCodeUrl)
                }
                Button {
                    visible: aboutPage.privacyPolicyUrl.length > 0
                    text: qsTr("Privacy policy")
                    onClicked: Qt.openUrlExternally(aboutPage.privacyPolicyUrl)
                }
                Button {
                    visible: aboutPage.issuesUrl.length > 0
                    text: qsTr("Report a problem")
                    onClicked: Qt.openUrlExternally(aboutPage.issuesUrl)
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
