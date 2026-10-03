// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import QtQuick.LocalStorage 2.0

// Persistently stored app settings (key/value in the same SQLite
// database as FavoritesStore, separate table "settings").
//
// Adding a new setting:
//   1. add a property with its default value
//   2. add it to _defs (name + type) and add an onXxxChanged handler
//      calling save("xxx") - loading then happens automatically

QtObject {
    id: appSettings

    // --- Playback ---
    // Start playing the last heard station right away when the app starts
    property bool autoplayLastStation: false
    // Last sleep timer duration chosen in the PlayerBar (in minutes)
    property int sleepTimerMinutes: 30
    // Fade out slowly at the end of the sleep timer instead of stopping abruptly
    property bool sleepFadeOut: true

    // --- Discover ---
    // Home country as ISO code ("AT"); empty = detect automatically
    property string homeCountry: ""
    // Vote for a station on radio-browser.info when saving it as a favourite
    property bool autoVoteOnFavorite: true

    // --- Favourites backup / sync ---
    // Favourites are always backed up on the device (Documents/Sailwave).
    // webdavUse: a WebDAV server is set up (e.g. Nextcloud) - offered for
    // manual backups and restoring. webdavAutoSync: additionally every
    // change is uploaded and changes from other devices are checked at
    // start-up. (Replaces the former choice favoritesStorage, see
    // ensureLoaded.)
    property bool webdavUse: false
    property bool webdavAutoSync: true
    property string webdavUrl: ""
    property string webdavUser: ""
    // The password is NOT in the settings table: it is kept in Sailfish
    // Secrets (C++ "secretStore") and only held in memory here. Change it
    // only via setWebdavPassword(). webdavPasswordReady: loaded (or there is
    // none) - the WebDAV sync waits for it. webdavPasswordError: it could
    // not be saved or read securely (shown in the settings).
    property string webdavPassword: ""
    property bool webdavPasswordReady: false
    property bool webdavPasswordError: false
    // A password is stored in Sailfish Secrets (so it is loaded at start-up)
    property bool webdavPasswordStored: false
    // ETag of the server file after the last successful sync (conflict check)
    property string webdavEtag: ""
    // A change could not be uploaded yet (retried at the next chance)
    property bool webdavPending: false

    // --- Hints ---
    // The one-time hint "tap the station name" above the PlayerBar was shown
    property bool playerBarHintShown: false
    // One-time hints: swiping between the ring pages (first start), and
    // where the other favourite options are (first "Move" on the start page)
    property bool ringHintShown: false
    property bool moveHintShown: false
    // After the station info hint: the arrow expands the PlayerBar (recent
    // tracks, sleep timer); advanced search: where the results appear
    property bool playerBarExpandHintShown: false
    property bool searchResultsHintShown: false

    // --- Privacy ---
    // Look up album covers via the iTunes Search API (song titles are sent to Apple)
    property bool trackArtEnabled: true
    // Missing station logos via Google's favicon service (the homepage's
    // domain is sent to Google); off = letter avatar instead
    property bool googleLogoFallback: true
    // Save played tracks in the track history
    property bool trackHistoryEnabled: true
    // Maximum number of stored tracks
    property int trackHistoryLimit: 100

    // Name -> type of all stored settings
    readonly property var _defs: ({
        autoplayLastStation: "bool",
        sleepTimerMinutes: "int",
        sleepFadeOut: "bool",
        homeCountry: "string",
        autoVoteOnFavorite: "bool",
        webdavUse: "bool",
        webdavAutoSync: "bool",
        webdavUrl: "string",
        webdavUser: "string",
        webdavPasswordStored: "bool",
        webdavEtag: "string",
        webdavPending: "bool",
        playerBarHintShown: "bool",
        ringHintShown: "bool",
        moveHintShown: "bool",
        playerBarExpandHintShown: "bool",
        searchResultsHintShown: "bool",
        googleLogoFallback: "bool",
        trackArtEnabled: "bool",
        trackHistoryEnabled: "bool",
        trackHistoryLimit: "int"
    })

    property bool _loaded: false

    onAutoplayLastStationChanged: save("autoplayLastStation")
    onSleepTimerMinutesChanged: save("sleepTimerMinutes")
    onSleepFadeOutChanged: save("sleepFadeOut")
    onHomeCountryChanged: save("homeCountry")
    onAutoVoteOnFavoriteChanged: save("autoVoteOnFavorite")
    onWebdavUseChanged: {
        save("webdavUse")
        // Switched on in the settings: the fields show the password
        if (webdavUse && _loaded) ensurePasswordLoaded()
    }
    onWebdavAutoSyncChanged: save("webdavAutoSync")
    onWebdavUrlChanged: save("webdavUrl")
    onWebdavUserChanged: save("webdavUser")
    onWebdavPasswordStoredChanged: save("webdavPasswordStored")
    onWebdavEtagChanged: save("webdavEtag")
    onWebdavPendingChanged: save("webdavPending")
    onPlayerBarHintShownChanged: save("playerBarHintShown")
    onRingHintShownChanged: save("ringHintShown")
    onMoveHintShownChanged: save("moveHintShown")
    onPlayerBarExpandHintShownChanged: save("playerBarExpandHintShown")
    onSearchResultsHintShownChanged: save("searchResultsHintShown")
    onGoogleLogoFallbackChanged: save("googleLogoFallback")

    // Shows all one-time hints again (press and hold the icon on the about page)
    function resetHints() {
        playerBarHintShown = false
        ringHintShown = false
        moveHintShown = false
        playerBarExpandHintShown = false
        searchResultsHintShown = false
    }
    onTrackArtEnabledChanged: save("trackArtEnabled")
    onTrackHistoryEnabledChanged: save("trackHistoryEnabled")
    onTrackHistoryLimitChanged: save("trackHistoryLimit")

    Component.onCompleted: ensureLoaded()

    function db() {
        return LocalStorage.openDatabaseSync("harbour-sailwave", "1.0", "Sailwave Radio Favorites", 100000)
    }

    // Can be called several times, only loads the first time. This lets
    // other components make sure the values are there - regardless of the
    // order in which the Component.onCompleted handlers run.
    function ensureLoaded() {
        if (_loaded) {
            return
        }
        var values = {}
        db().transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT)")
            var rs = tx.executeSql("SELECT key, value FROM settings")
            for (var i = 0; i < rs.rows.length; i++) {
                values[rs.rows.item(i).key] = rs.rows.item(i).value
            }
        })
        for (var key in _defs) {
            var raw = values[key]
            // Missing or empty (NULL) in the database: keep the default.
            // Assigning null to a string property throws ("Cannot assign
            // void* to QString") and would abort loading all other settings.
            if (raw === undefined || raw === null) {
                continue
            }
            raw = String(raw)
            if (_defs[key] === "bool") {
                appSettings[key] = (raw === "true")
            } else if (_defs[key] === "int") {
                var n = parseInt(raw, 10)
                if (!isNaN(n)) {
                    appSettings[key] = n
                }
            } else {
                appSettings[key] = raw
            }
        }
        _loaded = true

        // Until v60 there was one choice "Save favorites": "local" or
        // "webdav" (= server with automatic sync). Taken over once.
        if (values["webdavUse"] === undefined && values["favoritesStorage"] !== undefined) {
            var wasWebdav = String(values["favoritesStorage"]) === "webdav"
            webdavUse = wasWebdav
            webdavAutoSync = true
        }

        // Until v51 the password was stored in the settings table: move it
        // to Sailfish Secrets (the row is deleted once that worked)
        var legacy = values["webdavPassword"]
        _initPassword(legacy !== undefined && legacy !== null ? String(legacy) : "")
    }

    // --- WebDAV password in Sailfish Secrets ---

    readonly property string _secretName: "webdavPassword"
    property bool _migrating: false

    function _initPassword(legacy) {
        if (legacy.length > 0) {
            webdavPassword = legacy
            webdavPasswordReady = true
            _migrating = true
            secretStore.store(_secretName, legacy)
        } else if (webdavPasswordStored) {
            // Read only when needed: right away only with automatic sync
            // (it syncs shortly after the start); otherwise on the first
            // server access or when the WebDAV settings are shown
            _passwordLoadPending = true
            if (webdavUse && webdavAutoSync) {
                ensurePasswordLoaded()
            }
        } else {
            webdavPasswordReady = true
        }
    }

    property bool _passwordLoadPending: false

    // Loads the password from Sailfish Secrets if that has not happened yet
    // (FavoritesBackup.dav, settings page). webdavPasswordReady follows.
    function ensurePasswordLoaded() {
        if (!_passwordLoadPending) return
        _passwordLoadPending = false
        secretStore.load(_secretName)
    }

    // From the password field: kept in memory right away, saved securely
    // shortly after the last change (not on every letter)
    function setWebdavPassword(text) {
        if (text === webdavPassword) {
            return
        }
        webdavPassword = text
        _passwordSaveTimer.restart()
    }

    property Timer _passwordSaveTimer: Timer {
        interval: 800
        onTriggered: {
            if (appSettings.webdavPassword.length > 0) {
                secretStore.store(appSettings._secretName, appSettings.webdavPassword)
            } else {
                secretStore.remove(appSettings._secretName)
                appSettings.webdavPasswordStored = false
                appSettings.webdavPasswordError = false
            }
        }
    }

    property Connections _secretConnections: Connections {
        target: secretStore
        onStored: {
            if (name !== appSettings._secretName) return
            if (ok) {
                appSettings.webdavPasswordStored = true
                appSettings.webdavPasswordError = false
                if (appSettings._migrating) {
                    appSettings._migrating = false
                    appSettings.db().transaction(function(tx) {
                        tx.executeSql("DELETE FROM settings WHERE key = 'webdavPassword'")
                    })
                }
            } else {
                // Not stored anywhere (no fallback to the database); an old
                // secret was replaced, so nothing is stored any more. The
                // password still works until the app is closed. During the
                // migration the old row stays, so the next start tries again.
                console.warn("WebDAV password could not be stored in Sailfish Secrets: " + error)
                appSettings.webdavPasswordStored = false
                appSettings.webdavPasswordError = true
            }
        }
        onLoaded: {
            if (name !== appSettings._secretName) return
            if (ok) {
                // A password typed in the meantime takes precedence
                if (appSettings.webdavPassword.length === 0) {
                    appSettings.webdavPassword = value
                }
            } else {
                console.warn("WebDAV password could not be read from Sailfish Secrets: " + error)
                appSettings.webdavPasswordError = true
            }
            appSettings.webdavPasswordReady = true
        }
    }

    function save(key) {
        // Do not write back while loading
        if (!_loaded) {
            return
        }
        var value = String(appSettings[key])
        db().transaction(function(tx) {
            tx.executeSql("INSERT OR REPLACE INTO settings(key, value) VALUES (?, ?)", [key, value])
        })
    }
}
