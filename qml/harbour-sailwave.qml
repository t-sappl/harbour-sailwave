// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import QtMultimedia 5.6
import Sailfish.Silica 1.0
import "pages"
import "cover"
import "RadioApi.js" as RadioApi
import "TrackText.js" as TrackText

ApplicationWindow {
    id: appWindow

    property var currentStation: null
    property bool isPlaying: player.playbackState === MediaPlayer.PlayingState
    property bool isBuffering: player.status === MediaPlayer.Buffering || player.status === MediaPlayer.Stalled

    // Current song title from the stream's ICY metadata (empty if the station sends none)
    property string currentTrackTitle: ""

    // Artist and title of the current song as written by iTunes - only set
    // when they match the stream text (see CoverArtCache), e.g. for streams
    // that send everything in CAPITALS. currentTrackDisplay is what the
    // PlayerBar, the app cover and the lock screen (MPRIS) show.
    property string currentItunesArtist: ""
    property string currentItunesTitle: ""
    // Always one line (the stream text may contain a line break, see TrackText.clean)
    readonly property string currentTrackDisplay: currentItunesArtist.length > 0 && currentItunesTitle.length > 0
                                                  ? currentItunesArtist + " - " + currentItunesTitle
                                                  : TrackText.oneLine(currentTrackTitle)
    onCurrentTrackTitleChanged: {
        currentItunesArtist = ""
        currentItunesTitle = ""
    }

    signal trackHistoryUpdated()
    signal stationHistoryUpdated()
    signal homepageOverridesUpdated()

    property alias favoritesStore: favoritesStore
    property alias persistentState: persistentState
    property alias appSettings: appSettingsInstance
    property alias sleepTimer: sleepTimerInstance

    AppSettings {
        id: appSettingsInstance
    }

    // Remembers, for the current app session, which icon URLs failed to load
    // (many favicon fields on radio-browser.info are broken or outdated).
    // Without this, every recycled list row would try the same broken link
    // over the network again - wasted loading time and choppy scrolling.
    property var brokenIconUrls: ({})
    // Raised whenever a URL is marked broken. Changing a key inside the
    // object above sends no change signal, so bindings that call
    // isIconUrlBroken() (StationIcon) would never notice - a logo that had
    // just failed kept its letter avatar in the lists, while places created
    // later (PlayerBar, lock screen) already showed the Google fallback.
    // Reading this counter in isIconUrlBroken() makes every such binding
    // re-evaluate.
    property int brokenIconRevision: 0

    function isIconUrlBroken(url) {
        return brokenIconRevision >= 0 && url.length > 0 && brokenIconUrls[url] === true
    }

    function markIconUrlBroken(url) {
        if (url.length > 0 && brokenIconUrls[url] !== true) {
            brokenIconUrls[url] = true
            brokenIconRevision++
        }
    }

    // App version number (for "About Sailwave" and the User-Agent).
    // Bump it with every release, together with the version in the .spec/.yaml.
    readonly property string appVersion: "1.0"

    // radio-browser.info API etiquette: our own User-Agent instead of the Qt default
    property string apiUserAgent: "harbour-sailwave/" + appVersion

    // Reconnect logic against dropouts on unstable connections
    property int reconnectAttempts: 0
    property int maxReconnectAttempts: 3

    // --- Ring navigation ---
    // The three main pages exist exactly once and live for the whole
    // session (scroll position, filters and search text are preserved).
    // Pages pushed as objects rather than URLs are not destroyed by the
    // PageStack when they are removed.
    property Page ringTopStationsPage: TopStationsPage { ringMember: true; objectName: "ringTopStations" }
    property Page ringTrackHistoryPage: TrackHistoryPage { ringMember: true; objectName: "ringTrackHistory" }
    property Page ringAdvancedSearchPage: AdvancedSearchPage { ringMember: true; objectName: "ringAdvancedSearch" }

    // No initialPage: Silica warns when it is given an existing page object
    // instead of a Component ("sub-optimal"). The ring needs the fixed
    // instance, so the start page is pushed in Component.onCompleted instead.
    cover: CoverPage {}
    // Portrait only in 1.0 (landscape is planned for 1.1, all pages would
    // need to be checked and adapted)
    allowedOrientations: Orientation.Portrait

    FavoritesStore {
        id: favoritesStore
    }

    // Favourites backup, restore, M3U export and WebDAV sync (I3-I5)
    property alias favoritesBackup: favoritesBackupInstance
    FavoritesBackup {
        id: favoritesBackupInstance
        store: favoritesStore
        settings: appSettingsInstance
        onSyncConflict: {
            var top = pageStack.currentPage
            if (!top || top.objectName !== "syncConflictPage") {
                pageStack.push(Qt.resolvedUrl("pages/SyncConflictPage.qml"))
            }
        }
    }

    PersistentState {
        id: persistentState
        trackHistoryLimit: appSettingsInstance.trackHistoryLimit
    }

    // Sleep timer: pauses playback at the end (the station stays selected)
    SleepTimer {
        id: sleepTimerInstance
        mediaPlayer: player
        fadeOut: appSettingsInstance.sleepFadeOut
        onExpired: {
            if (appWindow.isPlaying) {
                player.pause()
            }
        }
    }

    // --- Home country ---
    // Central place for all pages: country chosen manually in Settings,
    // otherwise detected by IP, otherwise taken from the system locale
    // (de_AT -> AT). Detection runs only once per session.
    property string detectedCountry: ""
    readonly property string userCountry: appSettingsInstance.homeCountry.length > 0
                                          ? appSettingsInstance.homeCountry : detectedCountry
    property var _countryCallbacks: []
    property bool _countryDetecting: false

    function localeCountry() {
        var parts = Qt.locale().name.split("_")
        return (parts.length > 1 && /^[A-Z]{2}$/.test(parts[1])) ? parts[1] : ""
    }

    // callback(code) - code is an ISO code or "" (then no country preference)
    function resolveUserCountry(callback) {
        appSettingsInstance.ensureLoaded()
        if (appSettingsInstance.homeCountry.length > 0) {
            callback(appSettingsInstance.homeCountry)
            return
        }
        if (detectedCountry.length > 0) {
            callback(detectedCountry)
            return
        }
        _countryCallbacks.push(callback)
        if (_countryDetecting) {
            return
        }
        _countryDetecting = true
        // Never let the pages wait forever (their busy indicators depend on
        // this): without an answer, fall back to the system locale
        countryTimeout.restart()
        RadioApi.fetchUserCountry(function(code) {
            _finishCountryDetection(code || localeCountry())
        }, apiUserAgent)
    }

    function _finishCountryDetection(code) {
        if (!_countryDetecting) {
            return   // already finished (answer came after the timeout)
        }
        countryTimeout.stop()
        detectedCountry = code
        _countryDetecting = false
        var cbs = _countryCallbacks
        _countryCallbacks = []
        for (var i = 0; i < cbs.length; i++) {
            cbs[i](userCountry)
        }
    }

    Timer {
        id: countryTimeout
        interval: 6000
        onTriggered: appWindow._finishCountryDetection(appWindow.localeCountry())
    }

    // Included via a Loader instead of a direct type reference: if the
    // Amber.Mpris QML plugin is missing on the device (import fails), the
    // Loader just sets status to Loader.Error - the app keeps running, only
    // without lock screen integration. A direct reference would prevent the
    // whole app from loading when the plugin is missing.
    Loader {
        id: mprisLoader
        source: "MprisIntegration.qml"
        asynchronous: false
        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("MPRIS integration not available (amber-mpris-qt5 missing) - app keeps running normally")
            }
        }
    }

    // Standalone, NOT inside MprisIntegration/MprisPlayer (see the
    // comment in CoverArtCache.qml for why this matters).
    CoverArtCache {
        id: coverArtCache

        // Store a found album cover (and its album name and genre) permanently
        // with the title in the track history
        onTrackArtResolved: {
            if (rawTitle === appWindow.currentTrackTitle && cleanArtist.length > 0 && cleanTitle.length > 0) {
                appWindow.currentItunesArtist = cleanArtist
                appWindow.currentItunesTitle = cleanTitle
            }
            if (appWindow.currentStation && appSettingsInstance.trackHistoryEnabled) {
                persistentState.setTrackDetails(rawTitle, appWindow.currentStation.name, artUrl, albumName, genre,
                                                cleanArtist, cleanTitle)
                appWindow.trackHistoryUpdated()
            }
        }
    }

    // Image for MPRIS / the lock screen: the PNG composed by ArtComposer once it
    // matches the current station and song; until then (a moment while the
    // images download) the image URL directly.
    readonly property string currentCoverArtUrl: coverArtCache.cachedArtFresh
                                                  ? "file://" + coverArtCache.cachedArtPath
                                                  : coverArtCache.directArtUrl
    readonly property string currentTrackArtUrl: coverArtCache.trackArtUrl

    // Height of the global PlayerBar, for the bottom margin of page content.
    // 0 while no station is selected (the bar then shows no content anyway).
    readonly property real playerBarHeight: currentStation ? playerBar.height : 0

    // Lists and flickables end above the *collapsed* PlayerBar (their view is
    // shortened by playerBarBaseHeight via anchors.bottomMargin). Then
    // Silica's own logic keeps an opened context menu inside the visible
    // area, like in the Mail app - an earlier helper that scrolled the list
    // while the menu opened fought Silica's scrolling and could trigger a
    // menu entry under the finger. The collapsed height is used on purpose:
    // otherwise the list would shrink whenever the bar is expanded.
    readonly property real playerBarBaseHeight: currentStation ? playerBar.collapsedHeight : 0
    // The part of the (expanded) bar that lies on top of such a view - the
    // footers add this much space so the last rows can still be scrolled
    // above the expanded bar. 0 while the bar is collapsed.
    readonly property real playerBarOverlap: Math.max(0, playerBarHeight - playerBarBaseHeight)
    MediaPlayer {
        id: player
        autoPlay: false

        onError: {
            console.warn("Player error: " + errorString)
            attemptReconnect()
        }

        onStatusChanged: {
            if (status === MediaPlayer.Buffered || status === MediaPlayer.Playing) {
                // Stream is stable again - reset the reconnect counter
                reconnectAttempts = 0
                stallTimer.stop()
            } else if (status === MediaPlayer.Stalled) {
                // Only reconnect after a few seconds of stalling;
                // short dropouts should be allowed to recover on their own
                stallTimer.restart()
            }
        }
    }

    // Evaluate the ICY metadata (StreamTitle) of the current station. Instead
    // of an onMetaDataChanged handler (which this MediaPlayer type does not
    // have), use a declarative binding that re-evaluates automatically
    // whenever player.metaData.title changes.
    // Tidied up right away (TrackText.clean: line breaks are kept, spaces,
    // tabs and empty lines cleaned). Places with room for one line only use
    // TrackText.oneLine (currentTrackDisplay, iTunes search, previews).
    property string rawTrackTitle: TrackText.clean(player.metaData ? (player.metaData.title || "") : "")

    onRawTrackTitleChanged: {
        if (rawTrackTitle.length > 0 && rawTrackTitle !== currentTrackTitle) {
            currentTrackTitle = rawTrackTitle
            if (currentStation && appSettingsInstance.trackHistoryEnabled) {
                persistentState.addTrackTitle(rawTrackTitle, currentStation.name,
                                               currentStation.stationuuid || "", currentStation.favicon || "",
                                               currentStation.url || "", currentStation.url_resolved || "",
                                               currentStation.homepage || "")
                trackHistoryUpdated()
            }
        } else if (rawTrackTitle.length === 0) {
            currentTrackTitle = ""
        }
    }

    Timer {
        id: stallTimer
        interval: 8000
        onTriggered: attemptReconnect()
    }

    function attemptReconnect() {
        if (!currentStation) {
            return
        }
        if (reconnectAttempts >= maxReconnectAttempts) {
            console.warn("Reconnect aborted after " + maxReconnectAttempts + " attempts")
            // Give up visibly: stop, so the play button shows "play" again,
            // and tell the user how to recover
            stallTimer.stop()
            player.stop()
            showMessage(qsTr("Station not reachable. Check your connection and tap play to try again."))
            return
        }
        reconnectAttempts += 1
        player.stop()
        player.source = currentStation.url_resolved && currentStation.url_resolved.length > 0
                         ? currentStation.url_resolved
                         : currentStation.url
        player.play()
    }

    function playStation(station) {
        // PlayerBar, app cover, lock screen and histories show this name
        station.name = RadioApi.cleanName(station.name)
        currentStation = station
        currentTrackTitle = ""
        reconnectAttempts = 0
        stallTimer.stop()
        player.stop()
        player.source = station.url_resolved && station.url_resolved.length > 0
                         ? station.url_resolved
                         : station.url
        player.play()
        persistentState.saveLastStation(station)
        persistentState.recordStationHistory(station)
        stationHistoryUpdated()
        registerClick(station)
    }

    // Reports a click on the station to the API (for popularity stats/top lists)
    // and uses the response as a freshly resolved stream URL in case something
    // changed since the list was loaded. radio-browser.info counts the click only
    // once per station and IP per 24h anyway - playback still starts immediately
    // with the already known url_resolved, so there is no waiting time.
    function registerClick(station) {
        if (!station.stationuuid) {
            return
        }
        RadioApi.requestJson(RadioApi.apiUrl("url/" + station.stationuuid), apiUserAgent, function(response) {
            if (response) {
                try {
                    var freshUrl = response.url
                    var stillCurrent = currentStation
                                        && currentStation.stationuuid === station.stationuuid
                    if (response.ok === true && freshUrl && stillCurrent
                        && freshUrl !== player.source.toString()) {
                        player.stop()
                        player.source = freshUrl
                        player.play()
                    }
                } catch (e) {
                    console.warn("Could not read click response: " + e)
                }
            }
        })
    }

    // --- Voting ---
    // radio-browser accepts one vote per station and IP every 10 minutes.
    // Sailwave adds its own fair rule: one vote per station per day
    // (voteIntervalMs). While a vote request is running, the station counts
    // as voted (no second tap that would only run into the API limit).
    readonly property double voteIntervalMs: 24 * 60 * 60 * 1000
    property var _votesPending: ({})

    // silent: automatic vote when saving a favourite - no banner
    signal voteStarted(string stationuuid)
    signal voteRegistered(bool ok, string message, string stationuuid, bool silent)

    onVoteRegistered: {
        if (!silent) {
            showMessage(ok ? qsTr("Vote counted, thank you!")
                           : message === "timeout" || message === "Network error"
                             ? qsTr("Vote not possible, no connection")
                             : qsTr("Vote not possible (already voted?)"))
        }
    }

    function isVotePending(stationuuid) {
        return _votesPending[stationuuid] !== undefined
    }

    // Offline the request may get no answer at all - after 10 s the vote
    // counts as failed: the heart is empty again, message "no connection"
    readonly property int voteTimeoutMs: 10000
    Timer {
        id: voteTimeoutCheck
        interval: 1000
        repeat: true
        onTriggered: {
            var now = Date.now()
            var anyLeft = false
            for (var uuid in appWindow._votesPending) {
                var pending = appWindow._votesPending[uuid]
                if (now - pending.time >= appWindow.voteTimeoutMs) {
                    delete appWindow._votesPending[uuid]
                    appWindow.voteRegistered(false, "timeout", uuid, pending.silent)
                } else {
                    anyLeft = true
                }
            }
            if (!anyLeft) stop()
        }
    }

    function votedRecently(stationuuid) {
        var last = persistentState.lastVoteTime(stationuuid)
        return last > 0 && Date.now() - last < voteIntervalMs
    }

    // Returns false if no vote was sent (already voted today, or running)
    function voteForStation(stationuuid, silent) {
        if (!stationuuid || isVotePending(stationuuid) || votedRecently(stationuuid)) {
            return false
        }
        _votesPending[stationuuid] = { time: Date.now(), silent: silent === true }
        voteTimeoutCheck.start()
        voteStarted(stationuuid)
        RadioApi.requestJson(RadioApi.apiUrl("vote/" + stationuuid), apiUserAgent, function(response) {
            // Already given up (timeout): ignore the late answer
            if (!appWindow._votesPending[stationuuid]) {
                return
            }
            delete appWindow._votesPending[stationuuid]
            if (response) {
                if (response.ok === true) {
                    persistentState.markVoted(stationuuid)
                }
                voteRegistered(response.ok === true, response.message || "", stationuuid, silent === true)
            } else {
                voteRegistered(false, "Network error", stationuuid, silent === true)
            }
        })
        return true
    }

    // Saving a favourite also votes for it, if enabled in Settings
    Connections {
        target: favoritesStore
        onFavoriteAdded: {
            if (appSettingsInstance.autoVoteOnFavorite && station && station.stationuuid) {
                appWindow.voteForStation(station.stationuuid, true)
            }
        }
    }

    // Opens the advanced search with a search text (e.g. "Find alternative"
    // for a favourite that is no longer reachable). The ring is rebuilt with
    // the search page on top; the ring logic then adds its neighbours.
    function searchStationsFor(text) {
        var target = ringAdvancedSearchPage
        target.searchFor(text)
        if (pageStack.currentPage === target) {
            return
        }
        pageStack.clear()
        pageStack.push(prevRingPage(target), {}, PageStackAction.Immediate)
        pageStack.push(target)
    }

    // Ring order: every page has exactly one right-hand neighbour.
    function nextRingPage(page) {
        if (page === ringTopStationsPage) return ringTrackHistoryPage
        if (page === ringTrackHistoryPage) return ringAdvancedSearchPage
        if (page === ringAdvancedSearchPage) return ringTopStationsPage
        return null
    }

    // Left-hand neighbour in the ring (inverse of nextRingPage).
    function prevRingPage(page) {
        if (page === ringTopStationsPage) return ringAdvancedSearchPage
        if (page === ringTrackHistoryPage) return ringTopStationsPage
        if (page === ringAdvancedSearchPage) return ringTrackHistoryPage
        return null
    }

    // The ring logic is triggered not only by the page's status change but
    // also by the PageStack itself (page change, animation finished). That
    // way no trigger gets lost - e.g. when the start page becomes active
    // before the UI has been fully built.
    function ringPageActivated(page) {
        _ringRetries = 0
        ringTimer.restart()
    }

    Connections {
        target: pageStack
        onCurrentPageChanged: appWindow.ringPageActivated(pageStack.currentPage)
        onBusyChanged: {
            if (!pageStack.busy) {
                appWindow.ringPageActivated(pageStack.currentPage)
            }
        }
    }

    property int _ringRetries: 0

    Timer {
        id: ringTimer
        interval: 50
        onTriggered: appWindow._applyRingNavigation()
    }

    function _applyRingNavigation() {
        var page = pageStack.currentPage
        if (!page || !page.ringMember) {
            return
        }

        // Still in the middle of an animation or the page is not fully active:
        // try again shortly (limited, so nothing loops forever).
        if (pageStack.busy || page.status !== PageStatus.Active) {
            if (_ringRetries < 40) {
                _ringRetries += 1
                ringTimer.restart()
            } else {
                console.warn("[Ring] Giving up: busy=" + pageStack.busy + " status=" + page.status)
            }
            return
        }

        var wantedPrev = prevRingPage(page)
        var prev = pageStack.previousPage(page)
        var prevIsBase = prev && !pageStack.previousPage(prev)

        if (prev !== wantedPrev || !prevIsBase) {
            pageStack.clear()
            pageStack.push(wantedPrev, {}, PageStackAction.Immediate)
            pageStack.push(page, {}, PageStackAction.Immediate)
            return
        }

        if (!page.canNavigateForward) {
            var next = nextRingPage(page)
            pageStack.pushAttached(next)
        }
    }

    function togglePlayback() {
        if (isPlaying) {
            player.pause()
        } else if (currentStation) {
            // A manual start gets the full set of reconnect attempts again
            reconnectAttempts = 0
            player.play()
        }
    }

    // Opens the info page of a station - but never twice for the same station:
    // if it is already shown, nothing happens; if it is further down the page
    // stack (e.g. info A -> similar B -> info B -> similar A), the app goes
    // back to that page instead of stacking a second copy.
    function stationKey(st) {
        return st ? (st.stationuuid || st.url || st.name || "") : ""
    }

    // replaceCurrent: used for the "Similar stations" of an info page. The new
    // info page then replaces the current one instead of stacking on top of
    // it (like the Jolla Maps app), so browsing from station to station does
    // not build an ever deeper page stack.
    function openStationInfo(st, replaceCurrent) {
        if (!st) {
            return
        }
        playerBarHint.dismiss()
        var key = stationKey(st)
        var top = pageStack.currentPage
        if (top && top.objectName === "stationInfoPage" && stationKey(top.station) === key) {
            return
        }
        var existing = pageStack.find(function(p) {
            return p.objectName === "stationInfoPage" && stationKey(p.station) === key
        })
        if (existing) {
            pageStack.pop(existing)
            return
        }
        if (replaceCurrent && top && top.objectName === "stationInfoPage") {
            pageStack.replace(Qt.resolvedUrl("pages/StationInfoPage.qml"), { station: st })
        } else {
            pageStack.push(Qt.resolvedUrl("pages/StationInfoPage.qml"), { station: st })
        }
    }

    // --- Cover action "next favourite" ---
    // With groups (I1): the next favourite of the playing station's group
    // (groups are usually thematic, e.g. news / music). If the station is
    // not a favourite, has no group, or is alone in its group: through all
    // favourites. Order = order on the start page.
    function nextFavoriteCandidates() {
        var favs = favoritesStore.favorites
        if (!currentStation) {
            return favs
        }
        var groupId = 0
        for (var i = 0; i < favs.length; i++) {
            if (favs[i].url === currentStation.url) {
                groupId = favs[i].groupId
                break
            }
        }
        if (groupId > 0) {
            var inGroup = favoritesStore.favoritesOfGroup(groupId)
            if (inGroup.length > 1) {
                return inGroup
            }
        }
        return favs
    }

    readonly property bool canPlayNextFavorite: {
        var favs = favoritesStore.favorites
        if (favs.length === 0) {
            return false
        }
        if (favs.length > 1) {
            return true
        }
        return !currentStation || favs[0].url !== currentStation.url
    }

    function playNextFavorite() {
        var list = nextFavoriteCandidates()
        if (list.length === 0) {
            return
        }
        var index = -1
        if (currentStation) {
            for (var i = 0; i < list.length; i++) {
                if (list[i].url === currentStation.url) {
                    index = i
                    break
                }
            }
        }
        playStation(list[(index + 1) % list.length])
    }

    // Short message at the bottom of the screen (see MessageBanner.qml)
    function showMessage(text) {
        messageBanner.show(text)
    }

    function stopPlayback() {
        player.stop()
        stallTimer.stop()
        currentStation = null
        currentTrackTitle = ""
        persistentState.clearLastStation()
    }

    Component.onCompleted: {
        pageStack.push(ringTopStationsPage, {}, PageStackAction.Immediate)
        ringPageActivated(pageStack.currentPage)
        appSettingsInstance.ensureLoaded()
        if (!appSettingsInstance.ringHintShown) {
            ringHintTimer.start()
        }
        var last = persistentState.loadLastStation()
        if (last) {
            restoreLastStation(last)
            // Only if enabled in Settings - otherwise deliberately no autostart
            if (appSettingsInstance.autoplayLastStation) {
                player.play()
            }
        }
    }

    function restoreLastStation(station) {
        station.name = RadioApi.cleanName(station.name)
        currentStation = station
        currentTrackTitle = ""
        player.stop()
        player.source = station.url_resolved && station.url_resolved.length > 0
                         ? station.url_resolved
                         : station.url
    }

    PlayerBar {
        id: playerBar
        anchors.bottom: parent.bottom
        width: parent.width
        z: 100
    }

    // --- One-time hints above the PlayerBar, one after the other:
    // 1. the station name opens the station info (the pulley entry for it
    //    was removed), 2. the arrow expands the bar (recent tracks, sleep
    //    timer - the moon only exists in the expanded bar).
    // Each appears 1.5 s after the PlayerBar is there (the second one 1.5 s
    // after the first is gone), disappears on tap or after 8 s - and never
    // comes back. The first also goes when the station info is opened, the
    // second when the bar is expanded (also if that happens before it was
    // ever shown).
    InteractionHintLabel {
        id: playerBarHint
        anchors.bottom: playerBar.top
        width: parent.width
        z: 101
        text: qsTr("Tap the station name for station info")
        property bool shown: false
        opacity: shown && !playerBar.isHiddenPage ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { FadeAnimation { duration: 400 } }

        MouseArea {
            anchors.fill: parent
            onClicked: playerBarHint.dismiss()
        }

        function dismiss() {
            if (shown) {
                shown = false
                playerBarHintHideTimer.stop()
                appSettingsInstance.playerBarHintShown = true
                // Next one in the chain
                if (!appSettingsInstance.playerBarExpandHintShown) {
                    playerBarHintTimer.restart()
                }
            }
        }
    }

    InteractionHintLabel {
        id: playerBarExpandHint
        anchors.bottom: playerBar.top
        width: parent.width
        z: 101
        text: qsTr("Tap the arrow for recent tracks and the sleep timer")
        property bool shown: false
        opacity: shown && !playerBar.isHiddenPage ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { FadeAnimation { duration: 400 } }

        MouseArea {
            anchors.fill: parent
            onClicked: playerBarExpandHint.dismiss()
        }

        function dismiss() {
            if (shown) {
                shown = false
                playerBarExpandHintHideTimer.stop()
            }
            appSettingsInstance.playerBarExpandHintShown = true
        }
    }

    readonly property bool playerBarHintsPending: !appSettingsInstance.playerBarHintShown
                                                  || !appSettingsInstance.playerBarExpandHintShown

    Timer {
        id: playerBarHintTimer
        interval: 1500
        onTriggered: {
            // Never two hints at the same time: wait for the swipe hint
            if (ringHint.active) {
                restart()
                return
            }
            if (!appWindow.currentStation || playerBar.isHiddenPage) {
                return
            }
            if (!appSettingsInstance.playerBarHintShown) {
                playerBarHint.shown = true
                playerBarHintHideTimer.start()
            } else if (!appSettingsInstance.playerBarExpandHintShown && !playerBar.expanded) {
                playerBarExpandHint.shown = true
                playerBarExpandHintHideTimer.start()
            }
        }
    }

    Timer {
        id: playerBarHintHideTimer
        interval: 8000
        onTriggered: playerBarHint.dismiss()
    }

    Timer {
        id: playerBarExpandHintHideTimer
        interval: 8000
        onTriggered: playerBarExpandHint.dismiss()
    }

    Connections {
        target: appWindow
        onCurrentStationChanged: {
            if (appWindow.playerBarHintsPending && appWindow.currentStation
                    && !playerBarHint.shown && !playerBarExpandHint.shown) {
                playerBarHintTimer.restart()
            }
        }
    }

    Connections {
        target: playerBar
        onExpandedChanged: {
            if (playerBar.expanded) {
                playerBarExpandHint.dismiss()
            }
        }
    }

    // --- One-time hint on the first start: swiping between the ring pages.
    // Starts 1 s after the start, only on the start page; ends after its
    // last run or on any page change - and never comes back.
    RingHint {
        id: ringHint
        anchors.fill: parent
        bottomMargin: appWindow.playerBarHeight
        z: 101
        onFinished: appSettingsInstance.ringHintShown = true
    }

    Timer {
        id: ringHintTimer
        interval: 1000
        onTriggered: {
            if (appSettingsInstance.ringHintShown) return
            if (pageStack.currentPage === ringTopStationsPage) {
                ringHint.start()
            } else if (pageStack.currentPage && pageStack.currentPage.ringMember) {
                // Already swiped by themselves - no hint needed
                appSettingsInstance.ringHintShown = true
            }
        }
    }

    Connections {
        target: pageStack
        onCurrentPageChanged: ringHint.stop()
    }

    MessageBanner {
        id: messageBanner
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: playerBar.top
        anchors.bottomMargin: Theme.paddingLarge
        z: 101
    }
}
