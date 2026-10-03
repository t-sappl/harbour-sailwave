// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "RadioApi.js" as RadioApi

// Favourites backup, restore, M3U export and WebDAV sync.
//
// Files:
//  - Documents/Sailwave/sailwave-favorites.json: current state, fixed name,
//    updated after every change (shortly delayed). For sharing, restoring,
//    and the file synced with WebDAV.
//  - App data folder backups/favorites-<date>-<time>.json: the last 5
//    states. At most one new state per hour (within the hour the newest is
//    updated); always a new one before restoring and before deleting a
//    group with its favourites.
//  - Manual backups (BackupPage) in Documents/Sailwave, next to the current
//    file, told apart by the name: sailwave-backup-<YYYY-MM-DD_HHMM>.json and
//    sailwave-playlist-<YYYY-MM-DD_HHMM>.m3u (they are never changed again).
//    Or to the WebDAV server (fixed names in "Sailwave/").
//
// Restoring: "replace" (favourites and groups exactly as in the backup) or
// "merge" (missing ones added, nothing deleted), see restore().
//
// WebDAV: the same JSON file in the folder "Sailwave/" below the given URL.
// webdavAvailable = server set up (manual backups/restoring); webdavEnabled
// = additionally automatic sync. With automatic sync the ETag after the last
// sync is remembered; if the server file changed since (other device), the
// user decides (SyncConflictPage): merge both, or keep this device's state.
// Failed uploads are retried later.
//
// Needs the C++ helpers fileHelper and webDav (see src/).
Item {
    id: backup

    property var store
    property var settings

    readonly property string folder: fileHelper.documentsPath() + "/Sailwave"
    readonly property string jsonPath: folder + "/sailwave-favorites.json"
    readonly property string versionsDir: fileHelper.dataPath() + "/backups"
    readonly property int maxVersions: 5
    readonly property double versionIntervalMs: 60 * 60 * 1000

    // A server is set up (manual backups and restoring)
    readonly property bool webdavAvailable: settings.webdavUse && settings.webdavUrl.length > 0
    // ... and every change is synced automatically
    readonly property bool webdavEnabled: webdavAvailable && settings.webdavAutoSync
    property bool syncing: false

    // The server file was changed elsewhere: the user has to decide
    signal syncConflict()

    // --- Saving ---

    Timer {
        id: saveTimer
        interval: 2000
        onTriggered: backup.save(false)
    }

    Connections {
        target: backup.store
        onFavoritesChanged: saveTimer.restart()
    }

    Component.onCompleted: {
        if (store.favorites.length > 0 && !fileHelper.exists(jsonPath)) {
            saveTimer.restart()
        }
    }

    // Sync check shortly after the start (not during it)
    property bool _startChecked: false
    Timer {
        interval: 6000
        running: true
        onTriggered: {
            backup._startChecked = true
            if (backup.webdavEnabled) backup.syncNow(true)
        }
    }

    // Automatic sync switched on later (settings): check right away
    onWebdavEnabledChanged: if (webdavEnabled && _startChecked) syncNow(true)

    function buildData() {
        var groupNames = {}
        var groups = []
        for (var g = 0; g < store.groups.length; g++) {
            groupNames[store.groups[g].id] = store.groups[g].name
            groups.push({ name: store.groups[g].name, order: g })
        }
        var favorites = []
        for (var i = 0; i < store.favorites.length; i++) {
            var f = store.favorites[i]
            favorites.push({
                stationuuid: f.stationuuid || "",
                name: f.name || "",
                url: f.url || "",
                url_resolved: f.url_resolved || "",
                homepage: f.homepage || "",
                favicon: f.favicon || "",
                country: f.country || "",
                countrycode: f.countrycode || "",
                language: f.language || "",
                tags: f.tags || "",
                codec: f.codec || "",
                bitrate: f.bitrate || 0,
                group: f.groupId > 0 ? (groupNames[f.groupId] || "") : "",
                order: i
            })
        }
        return {
            format: "sailwave-favorites",
            version: 1,
            savedAt: new Date().toISOString(),
            groups: groups,
            favorites: favorites
        }
    }

    // forceNewVersion: always start a new backup state (before restoring
    // or deleting a group with its favourites)
    function save(forceNewVersion) {
        saveTimer.stop()
        var text = JSON.stringify(buildData(), null, 2)
        fileHelper.ensureDir(folder)
        var ok = fileHelper.writeText(jsonPath, text)
        writeVersion(text, forceNewVersion === true)
        upload(text)
        return ok
    }

    // --- Backup states (versions) ---

    function stamp(d) {
        function two(n) { return (n < 10 ? "0" : "") + n }
        return d.getFullYear() + two(d.getMonth() + 1) + two(d.getDate()) + "-"
                + two(d.getHours()) + two(d.getMinutes()) + two(d.getSeconds())
    }

    // Creation time from the file name (the modification time changes
    // whenever the newest state is updated)
    function timeOf(name) {
        var m = /favorites-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})\.json/.exec(name)
        if (!m) return 0
        return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]),
                        Number(m[4]), Number(m[5]), Number(m[6])).getTime()
    }

    // Newest first
    function versionFiles() {
        var list = fileHelper.listDir(versionsDir, ["favorites-*.json"]).filter(function(e) { return !e.isDir })
        list.sort(function(a, b) { return b.name < a.name ? -1 : (b.name > a.name ? 1 : 0) })
        return list
    }

    function writeVersion(text, forceNew) {
        fileHelper.ensureDir(versionsDir)
        var list = versionFiles()
        var now = new Date()
        if (!forceNew && list.length > 0 && now.getTime() - timeOf(list[0].name) < versionIntervalMs) {
            fileHelper.writeText(list[0].path, text)
            return
        }
        fileHelper.writeText(versionsDir + "/favorites-" + stamp(now) + ".json", text)
        list = versionFiles()
        for (var i = maxVersions; i < list.length; i++) {
            fileHelper.removeFile(list[i].path)
        }
    }

    // For the restore page: [{ path, time, favorites, groups }], newest first
    function listVersions() {
        var result = []
        var list = versionFiles()
        for (var i = 0; i < list.length; i++) {
            var data = readBackup(list[i].path)
            if (data) {
                result.push({
                    path: list[i].path,
                    time: timeOf(list[i].name),
                    favorites: data.favorites.length,
                    groups: (data.groups || []).length
                })
            }
        }
        return result
    }

    // null if the file is no Sailwave favourites backup
    function readBackup(path) {
        var text = fileHelper.readText(path)
        if (!text) return null
        try {
            var data = JSON.parse(text)
            if (data && data.format === "sailwave-favorites" && Array.isArray(data.favorites)) {
                return data
            }
        } catch (e) {
            console.warn("[Backup] Unreadable file " + path + ": " + e)
        }
        return null
    }

    // --- Restoring (merge) ---

    // Key of a favourite for comparing backup and device
    function favKey(f) {
        return f.stationuuid ? "u:" + f.stationuuid : "url:" + f.url
    }

    // What restoring would change (for the confirmation dialog):
    // { add, remove, regroup, groupsAdd, groupsRemove } - counts for
    // "replace"; for "merge" only add and groupsAdd apply
    function previewRestore(data) {
        var current = {}
        for (var i = 0; i < store.favorites.length; i++) {
            var f = store.favorites[i]
            current[favKey(f)] = f.groupId > 0 ? store.groupName(f.groupId) : ""
            // a favourite matches by UUID or by stream URL
            current["url:" + f.url] = current[favKey(f)]
        }
        var inBackup = {}
        var add = 0, regroup = 0
        for (var j = 0; j < data.favorites.length; j++) {
            var b = data.favorites[j]
            var k = current[favKey(b)] !== undefined ? favKey(b)
                  : current["url:" + b.url] !== undefined ? "url:" + b.url : ""
            if (!k) {
                add++
            } else {
                inBackup[k] = true
                if ((b.group || "") !== current[k]) regroup++
            }
        }
        var remove = 0
        for (var c = 0; c < store.favorites.length; c++) {
            var cf = store.favorites[c]
            if (!inBackup[favKey(cf)] && !inBackup["url:" + cf.url]) remove++
        }
        var backupGroups = (data.groups || []).map(function(g) { return g.name })
        var deviceGroups = store.groups.map(function(g) { return g.name })
        return {
            add: add,
            remove: remove,
            regroup: regroup,
            groupsAdd: backupGroups.filter(function(n) { return deviceGroups.indexOf(n) === -1 }).length,
            groupsRemove: deviceGroups.filter(function(n) { return backupGroups.indexOf(n) === -1 }).length
        }
    }

    // mode "replace": favourites and groups become exactly the backup;
    // mode "merge" (default, also used by the WebDAV conflict): missing
    // favourites and groups are added, nothing is deleted.
    // done(added): number of favourites added (merge) / restored (replace)
    function restore(data, done, mode) {
        var replace = mode === "replace"
        save(true)
        var groupNames = (data.groups || []).slice()
                .sort(function(a, b) { return (a.order || 0) - (b.order || 0) })
                .map(function(g) { return g.name })
        var favs = data.favorites.slice()
                .sort(function(a, b) { return (a.order || 0) - (b.order || 0) })
        var entries = []
        var uuids = []
        for (var i = 0; i < favs.length; i++) {
            var f = favs[i]
            entries.push({ station: f, groupName: f.group || "" })
            if (f.stationuuid && (replace || !store.isFavorite(f.url))) {
                uuids.push(f.stationuuid)
            }
        }
        function finish() {
            var count = 0
            if (replace) {
                store.replaceAll(entries, groupNames)
                count = entries.length
            } else {
                count = store.addMany(entries, groupNames)
            }
            if (done) done(count)
        }
        if (uuids.length === 0) {
            finish()
            return
        }
        // Fresh data from radio-browser (stream URLs may have changed);
        // without an answer the saved data is used
        RadioApi.requestJson(RadioApi.apiUrl("stations/byuuid?uuids=") + uuids.join(","),
                             appWindow.apiUserAgent, function(list) {
            if (list) {
                var byUuid = {}
                for (var j = 0; j < list.length; j++) byUuid[list[j].stationuuid] = list[j]
                for (var k = 0; k < entries.length; k++) {
                    var fresh = byUuid[entries[k].station.stationuuid]
                    if (fresh) {
                        entries[k].station = {
                            stationuuid: fresh.stationuuid,
                            name: fresh.name || entries[k].station.name,
                            url: fresh.url || entries[k].station.url,
                            url_resolved: fresh.url_resolved || "",
                            homepage: fresh.homepage || "",
                            favicon: fresh.favicon || "",
                            country: fresh.country || "",
                            countrycode: fresh.countrycode || "",
                            language: fresh.language || "",
                            tags: fresh.tags || "",
                            codec: fresh.codec || "",
                            bitrate: fresh.bitrate || 0
                        }
                    }
                }
            }
            finish()
        })
    }

    // --- Manual backups (BackupPage) ---

    // "2026-10-02_1830" for file names of manual backups (sorts by time)
    function fileStamp(d) {
        function two(n) { return (n < 10 ? "0" : "") + n }
        return d.getFullYear() + "-" + two(d.getMonth() + 1) + "-" + two(d.getDate()) + "_"
                + two(d.getHours()) + two(d.getMinutes())
    }

    // format "json" or "m3u"
    function backupText(format) {
        return format === "m3u" ? m3uText() : JSON.stringify(buildData(), null, 2)
    }

    // To this device: Documents/Sailwave, next to the current file, as
    // sailwave-backup-<date_time>.json or sailwave-playlist-<date_time>.m3u.
    // Returns the path or "".
    function backupToDevice(format) {
        fileHelper.ensureDir(folder)
        var path = folder + (format === "m3u" ? "/sailwave-playlist-" : "/sailwave-backup-")
                + fileStamp(new Date()) + (format === "m3u" ? ".m3u" : ".json")
        return fileHelper.writeText(path, backupText(format)) ? path : ""
    }

    // Time of a manual backup from its name (0 if the name does not match)
    function manualTimeOf(name) {
        var m = /sailwave-backup-(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})\.json$/.exec(name)
        if (!m) return 0
        return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]),
                        Number(m[4]), Number(m[5])).getTime()
    }

    // For the restore page: the manual backups in Documents/Sailwave,
    // [{ path, time, favorites, groups }], newest first
    function listManualBackups() {
        var files = fileHelper.listDir(folder, ["sailwave-backup-*.json"]).filter(function(e) { return !e.isDir })
        files.sort(function(a, b) { return b.name < a.name ? -1 : (b.name > a.name ? 1 : 0) })
        var result = []
        for (var i = 0; i < files.length; i++) {
            var data = readBackup(files[i].path)
            if (data) {
                result.push({
                    path: files[i].path,
                    time: manualTimeOf(files[i].name) || files[i].modified,
                    favorites: data.favorites.length,
                    groups: (data.groups || []).length
                })
            }
        }
        return result
    }

    // To the WebDAV server ("Sailwave/", fixed names; the JSON file is the
    // one used for syncing). An explicit action: overwrites the server file
    // without a conflict check. done(ok, status)
    function backupToWebdav(format, done) {
        var text = backupText(format)
        var file = format === "m3u" ? remoteFolder() + "sailwave-favorites.m3u" : remoteFile()
        function putFile() {
            dav("PUT", file, text, function(status, body, etag) {
                var ok = status >= 200 && status < 300
                if (ok && format !== "m3u") {
                    settings.webdavPending = false
                    if (etag.length > 0) {
                        settings.webdavEtag = etag
                    } else {
                        dav("HEAD", remoteFile(), "", function(s, b, e) { if (s === 200 && e) settings.webdavEtag = e })
                    }
                }
                done(ok, status)
            })
        }
        // Create the folder if needed (405 = exists already - fine)
        dav("MKCOL", remoteFolder(), "", function() { putFile() })
    }

    // The JSON file on the server, for the restore page.
    // done(data or null, status, etag); status 404 = no file yet
    function fetchRemote(done) {
        dav("GET", remoteFile(), "", function(status, body, etag) {
            if (status !== 200) {
                done(null, status, "")
                return
            }
            var data = null
            try { data = JSON.parse(body) } catch (e) { data = null }
            if (!data || data.format !== "sailwave-favorites" || !Array.isArray(data.favorites)) {
                data = null
            }
            done(data, status, etag)
        })
    }

    // --- M3U export ---

    function m3uText() {
        function attr(s) { return String(s || "").replace(/"/g, "'") }
        var lines = ["#EXTM3U"]
        for (var i = 0; i < store.favorites.length; i++) {
            var f = store.favorites[i]
            var group = f.groupId > 0 ? store.groupName(f.groupId) : ""
            lines.push("#EXTINF:-1 tvg-logo=\"" + attr(f.favicon) + "\" group-title=\"" + attr(group) + "\","
                       + String(f.name || "").replace(/[\r\n]+/g, " "))
            lines.push(f.url_resolved || f.url)
        }
        return lines.join("\n") + "\n"
    }

    // --- WebDAV ---

    property int _requestId: 0
    property var _handlers: ({})

    // Requests wait until the password has arrived from Sailfish Secrets
    // (asynchronous, see AppSettings) - otherwise the first sync after the
    // start would be sent without a password
    property var _waiting: []

    function dav(method, url, body, callback) {
        if (!settings.webdavPasswordReady) {
            _waiting.push([method, url, body, callback])
            // Not read yet (only read when needed, see AppSettings)
            settings.ensurePasswordLoaded()
            return
        }
        _requestId++
        _handlers[_requestId] = callback
        webDav.request(_requestId, method, url, settings.webdavUser, settings.webdavPassword, body || "")
    }

    Connections {
        target: backup.settings
        onWebdavPasswordReadyChanged: {
            if (!backup.settings.webdavPasswordReady) return
            var calls = backup._waiting
            backup._waiting = []
            for (var i = 0; i < calls.length; i++) {
                backup.dav(calls[i][0], calls[i][1], calls[i][2], calls[i][3])
            }
        }
    }

    Connections {
        target: webDav
        onFinished: {
            var callback = backup._handlers[requestId]
            delete backup._handlers[requestId]
            if (callback) callback(status, body, etag, error)
        }
    }

    function baseUrl() {
        var u = settings.webdavUrl.replace(/^\s+|\s+$/g, "")
        return /\/$/.test(u) ? u : u + "/"
    }
    function remoteFolder() { return baseUrl() + "Sailwave/" }
    function remoteFile() { return remoteFolder() + "sailwave-favorites.json" }

    // done(ok, status): for "Test connection" in the settings
    function testConnection(done) {
        dav("PROPFIND", baseUrl(), "", function(status, body, etag, error) {
            if (error.length > 0 && status === 0) console.warn("[WebDAV] " + error)
            done(status === 207 || status === 200, status)
        })
    }

    function failSync(status) {
        syncing = false
        settings.webdavPending = true
        appWindow.showMessage(status === 401 || status === 403
                              ? qsTr("WebDAV sign-in failed")
                              : qsTr("Favorites could not be synced, trying again later"))
    }

    // After every local save: upload, unless the server file changed since
    // the last sync (then the user decides)
    function upload(text) {
        if (!webdavEnabled) return
        if (syncing) {
            settings.webdavPending = true
            return
        }
        syncing = true
        dav("HEAD", remoteFile(), "", function(status, body, etag) {
            if (status === 200) {
                if (settings.webdavEtag.length === 0 || etag !== settings.webdavEtag) {
                    syncing = false
                    syncConflict()
                    return
                }
                put(text)
            } else if (status === 404) {
                // Folder may not exist yet (405 = exists already - fine)
                dav("MKCOL", remoteFolder(), "", function() { put(text) })
            } else {
                failSync(status)
            }
        })
    }

    function put(text) {
        dav("PUT", remoteFile(), text, function(status, body, etag) {
            if (status >= 200 && status < 300) {
                syncing = false
                settings.webdavPending = false
                if (etag.length > 0) {
                    settings.webdavEtag = etag
                } else {
                    dav("HEAD", remoteFile(), "", function(s, b, e) { if (s === 200 && e) settings.webdavEtag = e })
                }
            } else {
                failSync(status)
            }
        })
    }

    // At start, from "Sync now" and after a successful connection test.
    // quiet: no message when everything is up to date
    function syncNow(quiet) {
        if (!webdavEnabled || syncing) return
        dav("HEAD", remoteFile(), "", function(status, body, etag) {
            if (status === 404) {
                upload(JSON.stringify(buildData(), null, 2))
            } else if (status === 200) {
                if (settings.webdavEtag.length > 0 && etag === settings.webdavEtag) {
                    if (settings.webdavPending) {
                        upload(JSON.stringify(buildData(), null, 2))
                    } else if (!quiet) {
                        appWindow.showMessage(qsTr("Favorites are up to date"))
                    }
                } else {
                    syncConflict()
                }
            } else if (!quiet || status === 401 || status === 403) {
                failSync(status)
            }
        })
    }

    // Conflict: merge the server state into this device, then upload
    function resolveMerge() {
        syncing = true
        dav("GET", remoteFile(), "", function(status, body, etag) {
            syncing = false
            if (status !== 200) {
                failSync(status)
                return
            }
            var data = null
            try { data = JSON.parse(body) } catch (e) { data = null }
            if (!data || data.format !== "sailwave-favorites" || !Array.isArray(data.favorites)) {
                appWindow.showMessage(qsTr("The file on the server is not a Sailwave favorites file"))
                return
            }
            // The merged state is then uploaded over exactly this version
            settings.webdavEtag = etag
            restore(data, function(added) {
                appWindow.showMessage(qsTr("%n favorite(s) added from the server", "", added))
            })
        })
    }

    // Conflict: replace the server file with this device's state (older
    // versions stay in Nextcloud's version history)
    function resolveKeepLocal() {
        syncing = true
        dav("HEAD", remoteFile(), "", function(status, body, etag) {
            syncing = false
            settings.webdavEtag = status === 200 ? etag : ""
            upload(JSON.stringify(buildData(), null, 2))
        })
    }
}
