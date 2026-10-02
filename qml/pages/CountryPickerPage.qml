import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"
import "../CountryData.js" as CountryData

// Choice of the home country for top stations and recommendations.
// Top entry "Automatic": the country is detected by IP or system locale.

Page {
    id: countryPage
    objectName: "countryPickerPage"

    property string filterText: ""

    function rebuild() {
        countryModel.clear()
        var q = filterText.trim().toLowerCase()
        if (q.length === 0) {
            countryModel.append({ code: "", label: qsTr("Automatic") })
        }
        var list = []
        for (var i = 0; i < CountryData.countries.length; i++) {
            var c = CountryData.countries[i]
            var name = CountryData.getLocalizedName(c)
            if (q.length === 0 || name.toLowerCase().indexOf(q) !== -1
                    || c.name.toLowerCase().indexOf(q) !== -1
                    || c.code.toLowerCase() === q) {
                list.push({ code: c.code, label: name })
            }
        }
        list.sort(function(a, b) { return a.label.localeCompare(b.label) })
        for (var j = 0; j < list.length; j++) {
            countryModel.append(list[j])
        }
    }

    Component.onCompleted: rebuild()

    ListModel { id: countryModel }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: countryModel

        header: Column {
            width: listView.width

            PageHeader {
                title: qsTr("Home country")
            }

            SearchField {
                width: parent.width
                placeholderText: qsTr("Search countries")
                onTextChanged: {
                    countryPage.filterText = text
                    countryPage.rebuild()
                }
            }
        }

        delegate: ListItem {
            id: item
            readonly property bool selected: model.code === appWindow.appSettings.homeCountry

            Label {
                anchors.verticalCenter: parent.verticalCenter
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin - codeLabel.width
                text: model.label
                truncationMode: TruncationMode.Fade
                color: (item.selected || item.highlighted) ? Theme.highlightColor : Theme.primaryColor
            }

            Label {
                id: codeLabel
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                text: model.code
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            onClicked: {
                appWindow.appSettings.homeCountry = model.code
                pageStack.pop()
            }
        }

        VerticalScrollDecorator {}
    }
}
