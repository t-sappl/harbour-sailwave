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

    // --- Favourites backup / sync (I3, I4) ---
    // "local" = only on the device (Documents/Sailwave), "webdav" = also on a
    // WebDAV server (e.g. Nextcloud)
    property string favoritesStorage: "local"
    property string webdavUrl: ""
    property string webdavUser: ""
    // Note: stored in the app's own database (sandboxed); an app password
    // is recommended in the settings text. Sailfish Secrets: see TODO I4.
    property string webdavPassword: ""
    // ETag of the server file after the last successful sync (conflict check)
    property string webdavEtag: ""
    // A change could not be uploaded yet (retried at the next chance)
    property bool webdavPending: false

    // --- Hints ---
    // The one-time hint "tap the station name" above the PlayerBar was shown
    property bool playerBarHintShown: false

    // --- Privacy ---
    // Look up album covers via the iTunes Search API (song titles are sent to Apple)
    property bool trackArtEnabled: true
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
        favoritesStorage: "string",
        webdavUrl: "string",
        webdavUser: "string",
        webdavPassword: "string",
        webdavEtag: "string",
        webdavPending: "bool",
        playerBarHintShown: "bool",
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
    onFavoritesStorageChanged: save("favoritesStorage")
    onWebdavUrlChanged: save("webdavUrl")
    onWebdavUserChanged: save("webdavUser")
    onWebdavPasswordChanged: save("webdavPassword")
    onWebdavEtagChanged: save("webdavEtag")
    onWebdavPendingChanged: save("webdavPending")
    onPlayerBarHintShownChanged: save("playerBarHintShown")
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
