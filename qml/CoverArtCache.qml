// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import harbour.sailwave 1.0
import "StationLogo.js" as StationLogo
import "TrackText.js" as TrackText

// Provides the cover art for MPRIS (lock screen) as a local PNG file:
//
//   - If a recognisable song is playing and iTunes finds an album cover:
//     large album cover, station logo as a small badge in the bottom right.
//   - Otherwise: just the station logo.
//
// That way the station always stays visible, and the switch between song
// and station image is easy for the user to follow.
//
// This component decides WHAT to show (iTunes lookup, station logo sources);
// the image itself is drawn and saved by the C++ helper ArtComposer
// (src/artcomposer.cpp). Unlike QML's grabToImage(), it also works while the
// app is in the background or the device is locked.
//
// IMPORTANT: Standalone, NOT a child of MprisPlayer (visual children there
// broke the MPRIS registration).
//
// Station logo sources come from StationLogo.js - the SAME logic StationIcon
// uses, so the lock screen always shows the same logo as the app (including a
// manually corrected homepage). The first source that loads wins.
//
// Until the PNG for the current state is ready (a fraction of a second while
// the images download), MPRIS gets the image URL directly - see cachedArtFresh.

Item {
    id: coverArtCache
    width: 0
    height: 0

    // Plain file path (without file://), empty if none is available (yet)
    property string cachedArtPath: ""

    // What the saved file shows and what it SHOULD show right now.
    // Only when both match is the file up to date.
    property string cachedArtKey: ""
    readonly property string wantedArtKey: _candidates.join(" ") + "|" + trackArtUrl
    readonly property bool cachedArtFresh: cachedArtPath.length > 0 && cachedArtKey === wantedArtKey

    // Direct image URL as a stand-in while the file is not up to date:
    // album cover first, otherwise the preferred station logo
    readonly property string directArtUrl: trackArtUrl.length > 0 ? trackArtUrl
                                           : (faviconUrl.length > 0 ? encodeURI(faviconUrl) : "")

    // Preferred station logo URL (first candidate)
    readonly property string faviconUrl: _candidates.length > 0 ? _candidates[0] : ""

    // URL of the album cover found via iTunes ("" = none)
    property string trackArtUrl: ""

    // The signal also passes the clean iTunes track title and the album name
    // genre: iTunes "primaryGenreName" of the song (English, see requestItunes),
    // stored in the track history for "similar stations" of untagged stations
    // cleanArtist/cleanTitle: artist and title as written by iTunes - only
    // set when they match the stream text (sameName), otherwise empty
    signal trackArtResolved(string rawTitle, string artUrl, string cleanTitle, string albumName, string genre, string cleanArtist)

    // Album cover lookup can be switched on and off (song titles are sent
    // to Apple for this). Bound to the persistent app settings.
    property bool trackArtEnabled: appWindow.appSettings ? appWindow.appSettings.trackArtEnabled : true

    // Station logo URLs to try, in order
    property var _candidates: []

    // iTunes lookup result cache for this session: title -> { art, album }
    property var _trackCache: ({})
    property string _lookupTitle: ""

    Connections {
        target: appWindow
        onCurrentStationChanged: {
            coverArtCache.trackArtUrl = ""
            coverArtCache._lookupTitle = ""
            logoTimer.restart()
        }
        onCurrentTrackTitleChanged: trackTimer.restart()
        // A corrected homepage can change the station logo
        onHomepageOverridesUpdated: logoTimer.restart()
    }

    Component.onCompleted: logoTimer.restart()

    Timer {
        id: logoTimer
        interval: 0
        onTriggered: coverArtCache.refreshLogo()
    }

    // Wait a moment: some stations send the title several times in quick
    // succession or incomplete at first.
    Timer {
        id: trackTimer
        interval: 1500
        onTriggered: coverArtCache.lookupTrack(appWindow.currentTrackTitle)
    }

    // ---------------------------------------------------------------
    // Composing the image (C++)
    // ---------------------------------------------------------------

    ArtComposer {
        id: composer
        userAgent: appWindow.apiUserAgent
        imageSize: 512

        onComposed: {
            // Ignore results for a state that is already outdated
            if (key === coverArtCache.wantedArtKey) {
                coverArtCache.cachedArtKey = key
                coverArtCache.cachedArtPath = path
            }
        }
        onFailed: {
            if (key === coverArtCache.wantedArtKey) {
                coverArtCache.cachedArtKey = ""
                coverArtCache.cachedArtPath = ""
            }
        }
        // Deliberately NOT marked as broken for the rest of the app: C++ may
        // fail on formats the QML Image can still show (e.g. .ico without the
        // Qt ico plugin). Marking them would hide working logos in the app.
    }

    // Bundle several changes in quick succession (station + title) into one job
    Timer {
        id: composeTimer
        interval: 150
        onTriggered: coverArtCache.compose()
    }

    onWantedArtKeyChanged: composeTimer.restart()

    function compose() {
        if (_candidates.length === 0 && trackArtUrl.length === 0) {
            cachedArtKey = ""
            cachedArtPath = ""
            return
        }
        // Old file stays until the new one is ready (it is just no longer
        // "fresh", so MPRIS uses directArtUrl meanwhile)
        composer.compose(trackArtUrl, _candidates, wantedArtKey)
    }

    // ---------------------------------------------------------------
    // Station logo
    // ---------------------------------------------------------------

    function buildCandidates(st) {
        var list = []
        if (!st) {
            return list
        }
        var fav = st.favicon || ""
        if (fav.length > 0 && !appWindow.isIconUrlBroken(fav)) {
            list.push(fav)
        }
        var override = (st.stationuuid && appWindow.persistentState)
                ? appWindow.persistentState.getHomepageOverride(st.stationuuid) : ""
        var google = appWindow.appSettings.googleLogoFallback
                ? StationLogo.googleFaviconUrl(StationLogo.resolveHomepage(st.homepage, override), 128) : ""
        if (google.length > 0 && !appWindow.isIconUrlBroken(google)) {
            list.push(google)
        }
        return list
    }

    function refreshLogo() {
        _candidates = buildCandidates(appWindow.currentStation)
    }

    // ---------------------------------------------------------------
    // Album cover via the iTunes Search API
    // ---------------------------------------------------------------

    // The same name apart from upper/lower case, punctuation and additions
    // in brackets ("(Radio Edit)", "[2011 Remaster]")
    function sameName(a, b) {
        function strip(s) {
            return normalize((s || "").replace(/\([^)]*\)|\[[^\]]*\]/g, ""))
        }
        var x = strip(a)
        return x.length > 0 && x === strip(b)
    }

    function normalize(s) {
        return (s || "").toLowerCase().replace(/[\s.,;:'"!?()\[\]&+\/_-]+/g, "")
    }

    // Split "Artist - Title"; everything else (jingles, news, slogans
    // without a separator) is not looked up at all.
    function parseTitle(t) {
        // A multi-line stream text is searched as one line
        t = TrackText.oneLine(t)
        var i = t.indexOf(" - ")
        if (i <= 0) {
            return null
        }
        var artist = t.substring(0, i).trim()
        var title = t.substring(i + 3).trim()
        if (artist.length < 2 || title.length < 2) {
            return null
        }
        // Stations that send their own name as the "artist"
        if (appWindow.currentStation
                && normalize(artist) === normalize(appWindow.currentStation.name)) {
            return null
        }
        return { artist: artist, title: title }
    }

    // User's iTunes store from the system locale (de_AT -> AT)
    function storeCountry() {
        var parts = Qt.locale().name.split("_")
        return parts.length > 1 && parts[1].length === 2 ? parts[1] : ""
    }

    function lookupTrack(rawTitle) {
        if (!trackArtEnabled) {
            trackArtUrl = ""
            return
        }
        var parsed = parseTitle(rawTitle)
        if (!parsed) {
            _lookupTitle = ""
            trackArtUrl = ""
            return
        }
        var key = normalize(rawTitle)
        _lookupTitle = key
        if (_trackCache.hasOwnProperty(key)) {
            var cached = _trackCache[key]
            trackArtUrl = cached.art
            if (cached.art.length > 0) {
                trackArtResolved(rawTitle, cached.art, cached.title || "", cached.album, cached.genre || "", cached.artist || "")
            }
            return
        }
        // Found before (possibly in an earlier session)?
        // Then take it from the track history instead of asking iTunes again.
        var stored = appWindow.persistentState
                ? appWindow.persistentState.getTrackDetails(rawTitle) : { artUrl: "", albumName: "" }
        if (stored.artUrl.length > 0) {
            _trackCache[key] = { art: stored.artUrl, album: stored.albumName, genre: stored.genre,
                                 artist: stored.itunesArtist, title: stored.itunesTitle }
            trackArtUrl = stored.artUrl
            trackArtResolved(rawTitle, stored.artUrl, stored.itunesTitle, stored.albumName, stored.genre, stored.itunesArtist)
            return
        }
        requestItunes(parsed, key, storeCountry(), rawTitle)
    }

    function requestItunes(parsed, key, country, rawTitle) {
        var url = "https://itunes.apple.com/search?media=music&entity=song&limit=5&term="
                + encodeURIComponent(parsed.artist + " " + parsed.title)
                + (country ? "&country=" + country : "")
                // English metadata in every store (also the genre names, which
                // are mapped to radio-browser tags - see RadioApi.tagForItunesGenre)
                + "&lang=en_us"
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }
            // Different title in the meantime? Discard the result.
            if (key !== coverArtCache._lookupTitle) {
                return
            }
            if (xhr.status !== 200) {
                if (country) {
                    // Unknown store? Try once without a country.
                    coverArtCache.requestItunes(parsed, key, "", rawTitle)
                } else {
                    console.warn("[CoverArt] iTunes error " + xhr.status)
                    coverArtCache.trackArtUrl = ""
                }
                return
            }
            var art = ""
            var cleanTrack = ""
            var cleanArtist = ""
            var albumName = ""
            var genre = ""
            try {
                var results = JSON.parse(xhr.responseText).results || []
                var wanted = coverArtCache.normalize(parsed.artist)
                for (var i = 0; i < results.length; i++) {
                    var got = coverArtCache.normalize(results[i].artistName)
                    // Rough artist match to avoid wrong hits
                    if (got.length > 0 && (got.indexOf(wanted) !== -1 || wanted.indexOf(got) !== -1)) {
                        art = (results[i].artworkUrl100 || "").replace("100x100bb", "600x600bb")
                        // Proper spelling only if artist AND title match the
                        // stream text - the artist match above is deliberately
                        // rough and could pick a different song
                        if (coverArtCache.sameName(parsed.artist, results[i].artistName)
                                && coverArtCache.sameName(parsed.title, results[i].trackName)) {
                            cleanArtist = results[i].artistName || ""
                            cleanTrack = results[i].trackName || ""
                        }
                        albumName = results[i].collectionName || ""
                        genre = results[i].primaryGenreName || ""
                        break
                    }
                }
            } catch (e) {
                console.warn("[CoverArt] Unreadable iTunes response: " + e)
            }
            coverArtCache._trackCache[key] = { art: art, album: albumName, genre: genre,
                                                artist: cleanArtist, title: cleanTrack }
            coverArtCache.trackArtUrl = art
            if (art.length > 0) {
                coverArtCache.trackArtResolved(rawTitle, art, cleanTrack, albumName, genre, cleanArtist)
            }
        }
        xhr.open("GET", url)
        xhr.setRequestHeader("User-Agent", appWindow.apiUserAgent)
        xhr.send()
    }

    // Setting toggled at runtime: remove the cover immediately or look it
    // up for the current title
    onTrackArtEnabledChanged: {
        if (trackArtEnabled) {
            lookupTrack(appWindow.currentTrackTitle)
        } else {
            _lookupTitle = ""
            trackArtUrl = ""
        }
    }
}
