// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"
import "../RadioApi.js" as RadioApi
import "../CountryData.js" as CountryData

Page {
    id: page
    objectName: "stationInfoPage"

    property var station: appWindow.currentStation
    property var stationInfo: null
    property string homepageOverride: ""
    property bool loading: false

    // Voting: the own last vote (ms, 0 = never); voted within the last day
    // (Sailwave's rule: one vote per station per day, see voteForStation);
    // a vote request running right now
    property bool hasVoted: false
    property double lastVote: 0
    property bool votePending: false

    // Reachability from radio-browser's own stream check: "broken" (last
    // check failed) or "missing" (no longer listed) - see loadInfo
    property string streamHealth: ""

    // The track history section shows only the latest few titles; the full
    // list is one tap away ("Open track history")
    // Titles loaded for the scrollable preview (3 visible, see TrackPreview)
    readonly property int historyPreviewCount: 30

    property bool historyCollapsed: false
    property bool similarCollapsed: false

    // Helper function to fetch data from either stationInfo or station
    function currentVal(key) {
        // The name as shown everywhere else (whitespace tidied up)
        if (key === "name") {
            return RadioApi.cleanName(rawVal("name"))
        }
        return rawVal(key)
    }

    function rawVal(key) {
        if (stationInfo && stationInfo[key] !== undefined && stationInfo[key] !== null && stationInfo[key] !== "") {
            return stationInfo[key]
        }
        if (station && station[key] !== undefined && station[key] !== null) {
            return station[key]
        }
        return ""
    }

    // Manually corrected homepage wins over the one from radio-browser.info
    readonly property string effectiveHomepage: homepageOverride.length > 0 ? homepageOverride : currentVal("homepage")

    onStationChanged: {
        if (station) {
            stationInfo = null
            loadHomepageOverride()
            loadSectionStates()
            refreshVoteStatus()
            refreshTrackHistory()
            loadInfo()
        }
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        // Ends above the collapsed PlayerBar (see appWindow.playerBarBaseHeight);
        // the content only adds room for the expanded part of the bar
        anchors.bottomMargin: appWindow.playerBarBaseHeight
        contentHeight: contentColumn.height + appWindow.playerBarOverlap + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                visible: page.streamHealth.length > 0
                text: qsTr("Find alternative")
                onClicked: appWindow.searchStationsFor(currentVal("name"))
            }
            MenuItem {
                text: qsTr("Refresh")
                enabled: station !== null
                onClicked: loadInfo()
            }
        }

        Column {
            id: contentColumn
            width: parent.width

            PageHeader {
                id: pageHeader
                title: qsTr("Station info")

                // Loading the full details: the page already shows the data
                // known from the list, so the indicator sits small in the free
                // left part of the header instead of taking space in the
                // layout (which made everything jump up once loading finished)
                BusyIndicator {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    size: BusyIndicatorSize.Small
                    running: page.loading
                }
            }

            InfoLabel {
                visible: !station
                text: qsTr("No station selected")
            }
            Label {
                visible: !station
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Select a station from the list or start playing one.")
            }

            // Main container, visible once a station is available
            Column {
                width: parent.width
                visible: station !== null
                spacing: 0

                StationIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    faviconUrl: currentVal("favicon")
                    homepageUrl: effectiveHomepage
                    stationuuid: currentVal("stationuuid")
                    stationName: currentVal("name")
                    iconSize: Theme.iconSizeLarge
                }

                // --- Play/Pause Button styled like PlayerBar ---
                Item {
                    width: parent.width
                    height: Theme.paddingMedium
                }

                // Play/pause in the centre, favourite heart to its right (an
                // empty slot on the left keeps the play button centred)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingLarge

                    Item {
                        width: favoriteButton.width
                        height: 1
                        visible: favoriteButton.visible
                    }

                    IconButton {
                        readonly property bool isThisStationActive: {
                            var currentUuid = appWindow && appWindow.currentStation ? appWindow.currentStation.stationuuid : ""
                            var thisUuid = currentVal("stationuuid")
                            return currentUuid !== "" && thisUuid !== "" && currentUuid === thisUuid
                        }
                        readonly property bool isPlayingThis: isThisStationActive && appWindow && appWindow.isPlaying

                        icon.source: isPlayingThis ? "image://theme/icon-m-pause" : "image://theme/icon-m-play"
                        icon.color: Theme.highlightColor

                        onClicked: {
                            var targetStation = stationInfo ? stationInfo : station
                            if (!targetStation || !appWindow) return

                            if (isThisStationActive) {
                                if (typeof appWindow.togglePlayback === "function") {
                                    appWindow.togglePlayback()
                                }
                            } else {
                                if (typeof appWindow.playStation === "function") {
                                    appWindow.playStation(targetStation)
                                }
                            }
                        }
                    }

                    IconButton {
                        id: favoriteButton
                        readonly property string targetUrl: currentVal("url")
                        visible: targetUrl.length > 0
                        icon.source: appWindow.favoritesStore.isFavorite(targetUrl)
                                     ? "image://theme/icon-m-favorite-selected"
                                     : "image://theme/icon-m-favorite"
                        onClicked: appWindow.favoritesStore.toggle({
                            name: currentVal("name"),
                            url: currentVal("url"),
                            url_resolved: currentVal("url_resolved"),
                            country: currentVal("country"),
                            codec: currentVal("codec"),
                            bitrate: currentVal("bitrate"),
                            stationuuid: currentVal("stationuuid"),
                            favicon: currentVal("favicon"),
                            homepage: currentVal("homepage"),
                            tags: currentVal("tags"),
                            language: currentVal("language"),
                            countrycode: currentVal("countrycode")
                        })
                    }
                }

                // --- Section: Station Properties ---
                Item {
                    width: parent.width
                    height: Theme.paddingLarge
                }

                SectionHeader {
                    text: qsTr("Station properties")
                }

                Column {
                    width: parent.width
                    spacing: 0

                    DetailItem {
                        label: qsTr("Country")
                        value: {
                            var c = CountryData.displayName(currentVal("countrycode"), currentVal("country"))
                            var s = String(currentVal("state") || "").trim()
                            // Some entries repeat the country as the state
                            // ("Spain · Spain") - shown only once
                            var sameAsCountry = s.toLowerCase() === c.toLowerCase()
                                    || s.toLowerCase() === String(currentVal("country") || "").toLowerCase()
                            var parts = []
                            if (c) parts.push(c)
                            if (s && !sameAsCountry) parts.push(s)
                            return parts.length > 0 ? parts.join(" · ") : qsTr("Unknown")
                        }
                    }
                    DetailItem {
                        label: qsTr("Language")
                        value: {
                            var lang = currentVal("language")
                            return lang ? lang : qsTr("Unknown")
                        }
                    }
                    DetailItem {
                        label: qsTr("Codec / bitrate")
                        value: {
                            var codec = currentVal("codec")
                            var bitrate = currentVal("bitrate")
                            var res = []
                            if (codec) res.push(codec.toUpperCase())
                            if (bitrate && bitrate !== 0 && bitrate !== "0" && bitrate !== "?") res.push(bitrate + " kbps")
                            return res.length > 0 ? res.join(" · ") : qsTr("Unknown")
                        }
                    }
                    DetailItem {
                        label: qsTr("Tags")
                        value: {
                            // All tags; radio-browser separates them with a
                            // bare comma - with a space the line can wrap
                            var tags = RadioApi.splitList(currentVal("tags"), false)
                            return tags.length > 0 ? tags.join(", ") : qsTr("Unknown")
                        }
                    }
                    // Only when there is a problem ("Find alternative" in
                    // the pulley menu then)
                    DetailItem {
                        visible: page.streamHealth.length > 0
                        label: qsTr("Status")
                        value: page.streamHealth === "broken" ? qsTr("Not reachable at the moment")
                                                              : qsTr("No longer listed at radio-browser.info")
                    }
                }

                // Homepage: centred link in the same text size as the station
                // properties, with an edit button next to it that opens
                // HomepageDialog. A corrected homepage is used for the station
                // logo fallback (Google favicon).
                Item {
                    width: parent.width
                    height: Theme.paddingLarge
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Homepage")
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    Label {
                        id: homepageLink
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, page.width - 2 * Theme.horizontalPageMargin
                                        - (editButton.visible ? editButton.width + parent.spacing : 0))
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeSmall
                        // A corrected homepage is shown in italics
                        font.italic: homepageOverride.length > 0
                        textFormat: Text.StyledText
                        linkColor: Theme.highlightColor
                        color: Theme.secondaryColor
                        // Shown without "https://" and trailing slash, opens the full URL
                        text: effectiveHomepage.length > 0
                              ? "<a href=\"" + effectiveHomepage + "\">"
                                + effectiveHomepage.replace(/^https?:\/\//i, "").replace(/\/$/, "") + "</a>"
                              : qsTr("Unknown")
                        onLinkActivated: Qt.openUrlExternally(link)
                    }

                    // Small pencil, but the touch area of a regular IconButton
                    IconButton {
                        id: editButton
                        anchors.verticalCenter: parent.verticalCenter
                        visible: currentVal("stationuuid").length > 0
                        icon.source: "image://theme/icon-m-edit"
                        icon.width: Theme.iconSizeExtraSmall
                        icon.height: Theme.iconSizeExtraSmall
                        width: Theme.itemSizeSmall
                        height: Theme.itemSizeSmall
                        onClicked: page.openHomepageDialog()
                    }
                }

                // Popularity and voting in one row: the like button votes
                // (filled at once while the vote is sent, and for a day
                // after it), next to it votes and total clicks
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingSmall

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: currentVal("stationuuid").length > 0
                        icon.source: (hasVoted || votePending) ? "image://theme/icon-m-like" : "image://theme/icon-m-outline-like"
                        onClicked: {
                            var uuid = currentVal("stationuuid")
                            if (!uuid || votePending) {
                                return
                            }
                            if (hasVoted) {
                                appWindow.showMessage(qsTr("Voting for this station is possible again tomorrow"))
                                return
                            }
                            appWindow.voteForStation(uuid, false)
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property int votes: Number(currentVal("votes")) || 0
                        readonly property int clicks: Number(currentVal("clickcount")) || 0
                        text: qsTr("%Ln votes", "", votes) + " · " + qsTr("%Ln clicks", "", clicks)
                        color: hasVoted ? Theme.highlightColor : Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                // When the own last vote was (also after the day is over, so
                // it stays visible that this station was voted for before)
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: page.lastVote > 0
                    text: qsTr("Last voted on %1").arg(Qt.formatDate(new Date(page.lastVote), Qt.DefaultLocaleShortDate))
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                }

                // --- Sections: track history and similar stations ---
                // Own collapsible headers, like on the other pages. The state
                // is remembered (the same for all stations).
                Item {
                    width: parent.width
                    height: Theme.paddingLarge
                    visible: trackHistoryModel.count > 0 || similarStationsModel.count > 0
                }

                BackgroundItem {
                    width: parent.width
                    height: Theme.itemSizeMedium
                    visible: trackHistoryModel.count > 0
                    onClicked: {
                        page.historyCollapsed = !page.historyCollapsed
                        page.saveSectionState("history", !page.historyCollapsed)
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.rightMargin: Theme.horizontalPageMargin
                        spacing: Theme.paddingMedium

                        SectionHeader {
                            text: qsTr("Track history")
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - expandIconHistory.width - parent.spacing
                        }

                        IconButton {
                            id: expandIconHistory
                            anchors.verticalCenter: parent.verticalCenter
                            icon.source: page.historyCollapsed ? "image://theme/icon-m-right" : "image://theme/icon-m-down"
                            enabled: false
                        }
                    }
                }

                // The latest titles + "Open track history" (shared with the PlayerBar)
                TrackPreview {
                    width: parent.width
                    visible: trackHistoryModel.count > 0 && !page.historyCollapsed
                    model: trackHistoryModel
                    onOpenClicked: page.openTrackHistory()
                }

                BackgroundItem {
                    width: parent.width
                    height: Theme.itemSizeMedium
                    visible: similarStationsModel.count > 0
                    onClicked: {
                        page.similarCollapsed = !page.similarCollapsed
                        page.saveSectionState("similar", !page.similarCollapsed)
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.rightMargin: Theme.horizontalPageMargin
                        spacing: Theme.paddingMedium

                        SectionHeader {
                            // Without tags the section shows popular stations of
                            // the station's country instead - with its own title,
                            // so it does not claim a similarity
                            text: page.similarByCountry ? qsTr("Popular in this country") : qsTr("Similar stations")
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - expandIconSimilar.width - parent.spacing
                        }

                        IconButton {
                            id: expandIconSimilar
                            anchors.verticalCenter: parent.verticalCenter
                            icon.source: page.similarCollapsed ? "image://theme/icon-m-right" : "image://theme/icon-m-down"
                            enabled: false
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: similarStationsModel.count > 0 && !page.similarCollapsed

                    // Same row as in every other station list: tap plays the
                    // station, the (i) button opens its info page (replacing
                    // this one), the heart adds it to the favourites
                    Repeater {
                        model: similarStationsModel
                        delegate: StationDelegate {
                            width: parent.width
                            replaceInfoPage: true
                        }
                    }
                }
            }
        }
        VerticalScrollDecorator {}
    }


    ListModel { id: trackHistoryModel }
    ListModel { id: similarStationsModel }

    Component.onCompleted: {
        if (station) {
            loadSectionStates()
            loadHomepageOverride()
            refreshVoteStatus()
            refreshTrackHistory()
            loadInfo()
        }
    }

    // New songs of this station show up in the preview right away
    Connections {
        target: appWindow
        onTrackHistoryUpdated: page.refreshTrackHistory()
    }

    Connections {
        target: appWindow
        onVoteStarted: {
            if (stationuuid === currentVal("stationuuid")) {
                votePending = true
            }
        }
        onVoteRegistered: {
            var uuid = currentVal("stationuuid")
            if (uuid && stationuuid === uuid) {
                refreshVoteStatus()
                if (ok) {
                    loadInfo()
                }
            }
        }
    }

    // Open/closed state of both sections, the same for all stations
    // (default: both open). Stored like the collapse states of the start page.
    function loadSectionStates() {
        historyCollapsed = appWindow.persistentState.getCollapseState("stationInfoHistoryCollapsed", false)
        similarCollapsed = appWindow.persistentState.getCollapseState("stationInfoSimilarCollapsed", false)
    }

    function saveSectionState(section, expanded) {
        appWindow.persistentState.setCollapseState(section === "history" ? "stationInfoHistoryCollapsed"
                                                                         : "stationInfoSimilarCollapsed",
                                                   !expanded)
    }

    // The track history page for this station. Opened as a normal sub-page
    // on top of this info page (not the ring page), so swiping back returns
    // here. It scrolls to this station's entries and expands them.
    function openTrackHistory() {
        pageStack.push(Qt.resolvedUrl("TrackHistoryPage.qml"), {
            targetStationKey: currentVal("stationuuid") || currentVal("name")
        })
    }

    function refreshVoteStatus() {
        var uuid = currentVal("stationuuid")
        lastVote = uuid ? appWindow.persistentState.lastVoteTime(uuid) : 0
        hasVoted = lastVote > 0 && Date.now() - lastVote < appWindow.voteIntervalMs
        votePending = uuid ? appWindow.isVotePending(uuid) : false
    }

    function refreshTrackHistory() {
        trackHistoryModel.clear()
        var stationName = currentVal("name")
        if (!stationName) {
            return
        }
        var history = appWindow.persistentState.getTrackHistoryForStation(stationName, historyPreviewCount)
        for (var i = 0; i < history.length; i++) {
            trackHistoryModel.append(history[i])
        }
    }

    function formatTime(timestampMs) {
        var d = new Date(timestampMs)
        var hh = ("0" + d.getHours()).slice(-2)
        var mm = ("0" + d.getMinutes()).slice(-2)
        return hh + ":" + mm
    }

    function loadHomepageOverride() {
        var uuid = currentVal("stationuuid")
        homepageOverride = uuid ? appWindow.persistentState.getHomepageOverride(uuid) : ""
    }

    function openHomepageDialog() {
        var dialog = pageStack.push(Qt.resolvedUrl("HomepageDialog.qml"), {
            originalHomepage: currentVal("homepage"),
            initialHomepage: effectiveHomepage
        })
        dialog.accepted.connect(function() {
            saveHomepageOverride(dialog.homepage)
        })
    }

    // An empty URL or the one from the station database removes the correction
    function saveHomepageOverride(newUrl) {
        var uuid = currentVal("stationuuid")
        if (!uuid) {
            return
        }
        if (newUrl.length === 0 || newUrl === currentVal("homepage")) {
            appWindow.persistentState.clearHomepageOverride(uuid)
            homepageOverride = ""
        } else {
            appWindow.persistentState.setHomepageOverride(uuid, newUrl)
            homepageOverride = newUrl
        }
        appWindow.homepageOverridesUpdated()
    }

    function loadInfo() {
        stationInfo = null

        var uuid = currentVal("stationuuid")
        if (!uuid) {
            requestSimilarStations()
            return
        }

        loading = true
        streamHealth = ""
        RadioApi.requestJson(RadioApi.apiUrl("stations/byuuid?uuids=") + encodeURIComponent(uuid), appWindow.apiUserAgent, function(results) {
            loading = false
            if (results && Array.isArray(results) && results.length === 0) {
                // Answer without the station: no longer listed
                streamHealth = "missing"
                requestSimilarStations()
            } else if (results && Array.isArray(results) && results.length > 0) {
                stationInfo = results[0]
                streamHealth = Number(stationInfo.lastcheckok) === 0 ? "broken" : ""
                loadSectionStates()
                refreshVoteStatus()
                refreshTrackHistory()
                requestSimilarStations()
            } else {
                // The data known from the list stays on screen; a message
                // instead of an inserted label keeps the layout in place
                appWindow.showMessage(qsTr("Could not load details"))
            }
        })
    }

    // --- Similar stations ---
    //
    // 1. Take the station's tags, without those that only name its own
    //    country or language. Type tags (RadioApi.isTypeTag: "public radio",
    //    "news", ...) describe the kind of station, not its programme.
    // 2. Ask radio-browser (most popular first, exact tag):
    //      - the first three genre (non-type) tags worldwide, in the
    //        station's language and in the user's home country (if it
    //        differs from the station's)
    //      - all tags (up to six, incl. type and brand tags such as
    //        "rtvslo") in the station's own country - finds sister stations
    //    All requests are sent at the same time. The targeted ones make sure
    //    there are enough matching candidates - the worldwide top lists are
    //    dominated by a few countries.
    // 3. Score every candidate: shared tags count most (type tags only
    //    within the same country), then the same country and language as the
    //    current station, then the home country and neighbouring countries.
    //    Candidates without any shared tag are dropped. Popularity only
    //    breaks ties and can never outweigh a matching country or language.
    // 4. Merge duplicates (the same station listed with several streams or
    //    bitrates) and show the 15 best matches.
    // The candidates are cached for 10 minutes per station, so opening the
    // same info page again needs no requests at all.

    property int similarRequestId: 0

    // Station name reduced to its core, for spotting duplicates: text in
    // brackets, codec/bitrate words and punctuation are removed, so
    // "Radio FFH (128k MP3)", "Radio FFH - 128 kbit" and "RADIO FFH AAC"
    // all become "radioffh".
    function normalizedName(name) {
        return String(name || "").toLowerCase()
                .replace(/\([^)]*\)|\[[^\]]*\]/g, " ")
                .replace(/\b(mp3|aac\+?|ogg|opus|flac|hq|hd|lq|stream|\d+\s*k(bit|bps|b)?(\/s)?)\b/g, " ")
                .replace(/[^a-z0-9\u00c0-\u024f]+/g, "")
    }

    // The up to 12 requests for similar stations each cost some time when
    // their answer arrives. They start only once the page has finished
    // sliding in, so the push animation stays smooth (seen in the QML
    // profiler as frame drops while the page opened).
    property bool similarPending: false

    onStatusChanged: {
        if (status === PageStatus.Active && similarPending) {
            similarPending = false
            loadSimilarStations()
        }
    }

    function requestSimilarStations() {
        if (status === PageStatus.Active) {
            similarPending = false
            loadSimilarStations()
        } else {
            similarPending = true
        }
    }

    // true: the station has no tags, so the section lists popular stations
    // of its country (and language, if known) instead of similar ones
    property bool similarByCountry: false

    // Up to two tags from the genres of the station's latest songs. A genre
    // counts with at least 2 of the titles and a share of at least 30 %,
    // and only with at least 3 titles with a known genre in total - so a
    // single (possibly wrongly matched) song decides nothing.
    function genreTagsFromHistory() {
        var stats = appWindow.persistentState.getGenreCounts(currentVal("stationuuid"), currentVal("name"), 50)
        if (stats.total < 3) {
            return []
        }
        var genres = []
        for (var g in stats.counts) {
            genres.push({ name: g, count: stats.counts[g] })
        }
        genres.sort(function(a, b) { return b.count - a.count })

        var tags = []
        for (var i = 0; i < genres.length && tags.length < 2; i++) {
            if (genres[i].count < 2 || genres[i].count / stats.total < 0.3) {
                break
            }
            var tag = RadioApi.tagForItunesGenre(genres[i].name)
            if (tag.length > 0 && tags.indexOf(tag) === -1) {
                tags.push(tag)
            }
        }
        return tags
    }

    function loadSimilarStations() {
        similarStationsModel.clear()
        similarRequestId++
        var requestId = similarRequestId

        var ownCountry = String(currentVal("countrycode") || "").toUpperCase()
        var ownLanguages = RadioApi.splitList(currentVal("language"), true)

        // Tags that only name the station's own country or language (e.g.
        // "slovenia", "english" for a station in Slovenia broadcasting in
        // English) are ignored: country and language are scored from their
        // own fields below. Other countries/languages stay - "greek" on a
        // station in Germany says something about its programme.
        var ownCountryData = CountryData.findCountry(ownCountry)
        var placeTags = [String(currentVal("country") || "").toLowerCase()].concat(ownLanguages)
        if (ownCountryData) {
            placeTags.push(ownCountryData.name.toLowerCase(), String(ownCountryData.de || "").toLowerCase())
            for (var cl = 0; cl < ownCountryData.languages.length; cl++) {
                placeTags.push(ownCountryData.languages[cl].toLowerCase())
            }
        }
        var ownTags = RadioApi.splitList(currentVal("tags"), true).filter(function(t, idx, all) {
            return all.indexOf(t) === idx && placeTags.indexOf(t) === -1
        })
        // No tags of its own: use the genres of the songs this station
        // played (iTunes genres from the track history, mapped to tags)
        if (ownTags.length === 0) {
            ownTags = genreTagsFromHistory()
        }

        // Genre tags are searched worldwide (the first 3); type tags such as
        // "public radio" or "news" only in the station's own country, where
        // all its tags are searched (up to 6) - this also finds sister
        // stations through brand tags like "rtvslo"
        var worldTags = ownTags.filter(function(t) { return !RadioApi.isTypeTag(t) }).slice(0, 3)
        var countryTags = ownTags.slice(0, 6)

        // Neither tags nor enough genres: popular stations of the same
        // country instead (none without a country either)
        similarByCountry = ownTags.length === 0
        if (similarByCountry && !ownCountry) {
            return
        }

        var ownUuid = currentVal("stationuuid")
        var ownUrl = currentVal("url")
        var ownName = normalizedName(currentVal("name"))
        var homeCountry = String(appWindow.userCountry || "").toUpperCase()
        if (homeCountry === ownCountry) {
            homeCountry = ""   // no separate requests or bonus needed
        }
        var neighbours = ownCountryData ? ownCountryData.borders : []
        // A language shared with a station that broadcasts in several
        // languages (often including English) says less about similarity
        var languageBonus = ownLanguages.length > 1 ? 2 : 4

        var base = RadioApi.apiUrl("stations/search?tagExact=true")
                + "&order=clickcount&reverse=true&hidebroken=true&limit=40&tag="
        var urls = []
        if (similarByCountry) {
            // Most clicked stations of the country; with a known language a
            // second request for that language - its stations get the
            // language bonus in the scoring below and come first
            var countryUrl = RadioApi.apiUrl("stations/search?order=clickcount&reverse=true&hidebroken=true&limit=40&countrycode=")
                    + encodeURIComponent(ownCountry)
            urls.push(countryUrl)
            if (ownLanguages.length > 0) {
                urls.push(countryUrl + "&languageExact=true&language=" + encodeURIComponent(ownLanguages[0]))
            }
        }
        // Genre tags: worldwide, in the station's language, in the home country
        for (var q = 0; q < worldTags.length; q++) {
            var tagUrl = base + encodeURIComponent(worldTags[q])
            urls.push(tagUrl)
            if (ownLanguages.length > 0) {
                urls.push(tagUrl + "&languageExact=true&language=" + encodeURIComponent(ownLanguages[0]))
            }
            if (homeCountry) {
                urls.push(tagUrl + "&countrycode=" + encodeURIComponent(homeCountry))
            }
        }
        // All tags (genre and type) in the station's own country
        if (ownCountry && !similarByCountry) {
            for (var ct = 0; ct < countryTags.length; ct++) {
                urls.push(base + encodeURIComponent(countryTags[ct])
                          + "&countrycode=" + encodeURIComponent(ownCountry))
            }
        }

        function showResults(merged) {
            var scored = []
            for (var key in merged) {
                var s = merged[key]
                if ((ownUuid && s.stationuuid === ownUuid) || (ownUrl && s.url === ownUrl)) {
                    continue
                }
                var name = normalizedName(s.name)
                // Another stream of the current station is not "similar"
                if (name.length === 0 || name === ownName) {
                    continue
                }

                var country = String(s.countrycode || "").toUpperCase()
                var sameCountry = ownCountry.length > 0 && country === ownCountry
                var inHomeCountry = homeCountry.length > 0 && country === homeCountry
                var inNeighbour = !sameCountry && neighbours.indexOf(country) !== -1

                // Type tags only count within the same country
                var tags = RadioApi.splitList(s.tags, true)
                var sharedTags = 0
                for (var t = 0; t < ownTags.length; t++) {
                    if (tags.indexOf(ownTags[t]) !== -1 && (sameCountry || !RadioApi.isTypeTag(ownTags[t]))) {
                        sharedTags++
                    }
                }
                // Without a shared tag a station is not similar (except in
                // the "popular in this country" fallback)
                if (!similarByCountry && sharedTags === 0) {
                    continue
                }

                var sameLanguage = false
                var langs = RadioApi.splitList(s.language, true)
                for (var l = 0; l < ownLanguages.length && !sameLanguage; l++) {
                    sameLanguage = langs.indexOf(ownLanguages[l]) !== -1
                }

                // Popularity adds at most about 2 points (log10 of the clicks
                // x 0.3), less than a matching country or language
                var score = sharedTags * 3
                        + (sameCountry ? 4 : 0)
                        + (sameLanguage ? languageBonus : 0)
                        + (inHomeCountry ? 2 : 0)
                        + (inNeighbour ? 2 : 0)
                        + Math.log(RadioApi.popularity(s) + 1) / Math.LN10 * 0.3

                scored.push({ station: s, name: name, score: score })
            }

            scored.sort(function(a, b) { return b.score - a.score })

            // Merge duplicates: the best-scored entry per station name wins
            var seenNames = {}
            similarStationsModel.clear()
            for (var k = 0; k < scored.length && similarStationsModel.count < 15; k++) {
                if (seenNames[scored[k].name]) {
                    continue
                }
                seenNames[scored[k].name] = true
                similarStationsModel.append(scored[k].station)
            }
        }

        // 10-minute cache (see PersistentState) for this set of requests
        var cacheKey = "similar:" + urls.join("|")
        var cached = appWindow.persistentState.getCachedResults(cacheKey)
        if (cached) {
            var cachedMap = {}
            for (var c = 0; c < cached.length; c++) {
                cachedMap[cached[c].url || cached[c].stationuuid || cached[c].name] = cached[c]
            }
            showResults(cachedMap)
            return
        }

        RadioApi.fetchAll(urls, appWindow.apiUserAgent,
            function() { return requestId !== similarRequestId },
            function(merged, failed) {
                // Only cache complete answers
                if (failed === 0) {
                    var list = []
                    for (var mk in merged) {
                        list.push(merged[mk])
                    }
                    appWindow.persistentState.setCachedResults(cacheKey, list)
                }
                showResults(merged)
            })
    }
}
