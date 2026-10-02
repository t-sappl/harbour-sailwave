import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"

Page {
    id: aboutPage
    objectName: "aboutPage"

    // --- Fill in before publishing. Empty entries are
    // not shown.
    property string licenseName: ""          // e.g. "GPLv3"
    property string sourceCodeUrl: ""        // e.g. "https://github.com/.../harbour-sailwave"
    property string privacyPolicyUrl: ""     // link to the privacy policy

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
                + "Album covers and genres from the iTunes Search API.")
                .arg("<a href=\"https://www.radio-browser.info\">radio-browser.info</a>")
                onLinkActivated: Qt.openUrlExternally(link)
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
            }
        }

        VerticalScrollDecorator {}
    }
}
