import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"

// Content of an expanded filter of the advanced search (genres, languages
// or countries): a filter field, the suggestions and further entries as
// chips (wrapping, no horizontal scrolling), optionally the "all must
// match" switch. All data and actions come from the page (AdvancedSearchPage).
Column {
    id: chooser

    property var page
    property string kind            // "genres", "languages" or "countries"
    property string moreTitle
    property string matchAllText: ""
    property string filterText: ""

    width: parent ? parent.width : 0

    // Separate lists, so that tapping a chip does not recreate all chips:
    // only "extra" (selected entries that are in no list, and the typed
    // filter text as a new entry) depends on the selection.
    // The lists are read here directly as well, so these bindings are sure
    // to update when a list arrives from the network while the filter is open
    readonly property var suggested: {
        var lists = [page.recommendedTags, page.recommendedLanguages, page.recommendedCountries]
        return page.filterItems(page.suggestedItems(kind), filterText, 0)
    }
    readonly property var more: {
        var lists = [page.allTags, page.allLanguages, page.recommendedTags, page.recommendedLanguages]
        return page.filterItems(page.moreItems(kind), filterText, filterText.length > 0 ? 60 : 40)
    }
    readonly property var extra: {
        var lists = [page.allTags, page.allLanguages, page.activeTags, page.activeLanguages, page.activeCountryCodes]
        return page.extraItems(kind, filterText)
    }

    SearchField {
        width: parent.width
        placeholderText: qsTr("Filter")
        inputMethodHints: Qt.ImhNoAutoUppercase
        EnterKey.iconSource: "image://theme/icon-m-enter-close"
        EnterKey.onClicked: focus = false
        onTextChanged: chooser.filterText = text.replace(/^\s+|\s+$/g, "").toLowerCase()
    }

    SectionHeader {
        text: qsTr("Suggested")
        visible: chooser.suggested.length + chooser.extra.length > 0
    }

    Flow {
        x: Theme.horizontalPageMargin - Theme.paddingSmall / 2
        width: parent.width - 2 * Theme.horizontalPageMargin + Theme.paddingSmall

        Repeater {
            model: chooser.extra
            FilterChip {
                text: modelData.label
                selected: chooser.page.isActive(chooser.kind, modelData.key)
                onClicked: chooser.page.toggleFilterValue(chooser.kind, modelData.key)
            }
        }
        Repeater {
            model: chooser.suggested
            FilterChip {
                text: modelData.label
                selected: chooser.page.isActive(chooser.kind, modelData.key)
                onClicked: chooser.page.toggleFilterValue(chooser.kind, modelData.key)
            }
        }
    }

    SectionHeader {
        text: chooser.moreTitle
        visible: chooser.more.length > 0
    }

    Flow {
        x: Theme.horizontalPageMargin - Theme.paddingSmall / 2
        width: parent.width - 2 * Theme.horizontalPageMargin + Theme.paddingSmall

        Repeater {
            model: chooser.more
            FilterChip {
                text: modelData.label
                selected: chooser.page.isActive(chooser.kind, modelData.key)
                onClicked: chooser.page.toggleFilterValue(chooser.kind, modelData.key)
            }
        }
    }

    TextSwitch {
        visible: chooser.matchAllText.length > 0
        text: chooser.matchAllText
        automaticCheck: false
        checked: chooser.page.matchAll(chooser.kind)
        onClicked: chooser.page.setMatchAll(chooser.kind, !checked)
    }

    Item {
        width: parent.width
        height: Theme.paddingMedium
    }
}
