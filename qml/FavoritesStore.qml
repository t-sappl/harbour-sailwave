// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import QtQuick.LocalStorage 2.0
import Sailfish.Silica 1.0
import "RadioApi.js" as RadioApi

// Favourites storage based on QtQuick.LocalStorage (SQLite),
// the usual way to store persistent data in Silica apps.

Item {
    id: favoritesStore

    // All favourites, in display order: groups in their order, favourites
    // without a group last; within a group by their own position.
    // Each entry has groupId (0 = no group).
    property var favorites: []

    // Favourite groups (I1), in their order: { id, name }
    property var groups: []

    // Emitted when a station was saved as a favourite (not on removal);
    // used for the automatic vote (see harbour-sailwave.qml)
    signal favoriteAdded(var station)

    // --- Reachability (H8) ---
    // Uses radio-browser's own regular stream check (lastcheckok) instead of
    // requesting the streams: one request for all favourites at app start
    // (shortly delayed), after adding a favourite, and every 6 hours.
    // health: stream URL -> "broken" (last check failed) or "missing" (no
    // longer listed). A failed request keeps the previous result.
    property var health: ({})
    property int healthVersion: 0

    function healthOf(url) {
        return healthVersion >= 0 && health[url] ? health[url] : ""
    }

    Timer {
        id: healthDelay
        interval: 4000
        running: true
        onTriggered: favoritesStore.checkHealth()
    }

    Timer {
        interval: 6 * 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: favoritesStore.checkHealth()
    }

    function checkHealth() {
        var uuids = []
        for (var i = 0; i < favorites.length; i++) {
            if (favorites[i].stationuuid) {
                uuids.push(favorites[i].stationuuid)
            }
        }
        if (uuids.length === 0) {
            health = {}
            healthVersion++
            return
        }
        RadioApi.requestJson(RadioApi.apiUrl("stations/byuuid?uuids=") + uuids.join(","),
                             appWindow.apiUserAgent, function(list) {
            if (!list) {
                return
            }
            var byUuid = {}
            for (var j = 0; j < list.length; j++) {
                byUuid[list[j].stationuuid] = list[j]
            }
            var result = {}
            for (var k = 0; k < favorites.length; k++) {
                var fav = favorites[k]
                if (!fav.stationuuid) {
                    continue
                }
                var st = byUuid[fav.stationuuid]
                if (!st) {
                    result[fav.url] = "missing"
                } else if (Number(st.lastcheckok) === 0) {
                    result[fav.url] = "broken"
                }
            }
            health = result
            healthVersion++
        })
    }

    Component.onCompleted: {
        db()   // creates/migrates the tables if no one did so yet
        reload()
    }

    // The tables are created on the first access, not only in
    // Component.onCompleted: the order of onCompleted handlers is not
    // defined, and on a fresh install a page could query a table before it
    // existed ("no such table: station_history", seen in the emulator).
    property bool tablesReady: false

    function db() {
        var database = LocalStorage.openDatabaseSync("harbour-sailwave", "1.0", "Sailwave Radio Favorites", 100000)
        if (!tablesReady) {
            tablesReady = true   // set first: initDb() itself calls db()
            initDb()
        }
        return database
    }

    function initDb() {
        db().transaction(function(tx) {
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS favorites(" +
                "url TEXT UNIQUE, name TEXT, url_resolved TEXT, " +
                "country TEXT, codec TEXT, bitrate INTEGER, stationuuid TEXT, favicon TEXT, homepage TEXT, " +
                "tags TEXT, language TEXT, countrycode TEXT)"
            )
            // Migrations for existing installations without the respective column
            // (fails harmlessly if the column already exists)
            var migrations = ["stationuuid TEXT", "favicon TEXT", "homepage TEXT",
                               "tags TEXT", "language TEXT", "countrycode TEXT",
                               "sort_order INTEGER", "group_id INTEGER"]
            for (var i = 0; i < migrations.length; i++) {
                try {
                    tx.executeSql("ALTER TABLE favorites ADD COLUMN " + migrations[i])
                } catch (e) {
                    // Column already exists - no problem
                }
            }
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS favorite_groups(" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, sort_order INTEGER)"
            )
            // Favourites without a position (stored before the order could be
            // changed): append them in alphabetical order, as shown so far
            var unordered = tx.executeSql("SELECT url FROM favorites WHERE sort_order IS NULL ORDER BY name COLLATE NOCASE")
            if (unordered.rows.length > 0) {
                var maxRow = tx.executeSql("SELECT COALESCE(MAX(sort_order), -1) AS m FROM favorites")
                var next = Number(maxRow.rows.item(0).m) + 1
                for (var u = 0; u < unordered.rows.length; u++) {
                    tx.executeSql("UPDATE favorites SET sort_order = ? WHERE url = ?",
                                  [next + u, unordered.rows.item(u).url])
                }
            }
        })
    }

    // New order of the favourites (stream URLs, first to last). favorites is
    // reloaded, so the start page and the cover action follow the order.
    function setOrder(urls) {
        db().transaction(function(tx) {
            for (var i = 0; i < urls.length; i++) {
                tx.executeSql("UPDATE favorites SET sort_order = ? WHERE url = ?", [i, urls[i]])
            }
        })
        reload()
    }

    function isFavorite(stationUrl) {
        for (var i = 0; i < favorites.length; i++) {
            if (favorites[i].url === stationUrl) {
                return true
            }
        }
        return false
    }

    function toggle(station) {
        if (!station || !station.url) {
            console.warn("FavoritesStore: invalid station object")
            return
        }
        if (isFavorite(station.url)) {
            remove(station.url)
        } else {
            add(station)
        }
    }

    function add(station) {
        if (isFavorite(station.url)) {
            return
        }
        db().transaction(function(tx) {
            tx.executeSql(
                // New favourites go to the end of the list
                "INSERT OR IGNORE INTO favorites " +
                "(url, name, url_resolved, country, codec, bitrate, stationuuid, favicon, homepage, " +
                "tags, language, countrycode, sort_order) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, " +
                "(SELECT COALESCE(MAX(sort_order), -1) + 1 FROM favorites))",
                [station.url, station.name, station.url_resolved || "",
                 station.country || "", station.codec || "", station.bitrate || 0,
                 station.stationuuid || "", station.favicon || "", station.homepage || "",
                 station.tags || "", station.language || "", station.countrycode || ""]
            )
        })
        reload()
        favoritesChanged()
        favoriteAdded(station)
        healthDelay.restart()
    }

    function remove(stationUrl) {
        db().transaction(function(tx) {
            tx.executeSql("DELETE FROM favorites WHERE url = ?", [stationUrl])
        })
        reload()
        favoritesChanged()
    }

    // Adds tags/language/countrycode to an already stored favourite that
    // does not have these fields yet (e.g. because it was added before the
    // app recorded these fields at all). Deliberately does NOT emit
    // favoritesChanged(), to avoid an update loop with the recommendation
    // logic that calls this function itself.
    function updateMetadata(stationuuid, tags, language, countrycode) {
        if (!stationuuid) {
            return
        }
        db().transaction(function(tx) {
            tx.executeSql(
                "UPDATE favorites SET tags = ?, language = ?, countrycode = ? WHERE stationuuid = ?",
                [tags || "", language || "", countrycode || "", stationuuid]
            )
        })
        reload()
    }

    function reload() {
        var list = []
        var groupList = []
        db().transaction(function(tx) {
            var g = tx.executeSql("SELECT id, name FROM favorite_groups ORDER BY sort_order, id")
            for (var j = 0; j < g.rows.length; j++) {
                groupList.push({ id: g.rows.item(j).id, name: g.rows.item(j).name || "" })
            }
            // Favourites of a group in group order; without a group (or with
            // a group that no longer exists) at the end
            var result = tx.executeSql(
                "SELECT f.*, CASE WHEN g.id IS NULL THEN 0 ELSE g.id END AS gid, " +
                "CASE WHEN g.id IS NULL THEN 1 ELSE 0 END AS ungrouped, g.sort_order AS gorder " +
                "FROM favorites f LEFT JOIN favorite_groups g ON g.id = f.group_id " +
                "ORDER BY ungrouped, gorder, g.id, f.sort_order, f.name COLLATE NOCASE")
            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                list.push({
                    name: RadioApi.cleanName(row.name),
                    url: row.url,
                    url_resolved: row.url_resolved,
                    country: row.country,
                    codec: row.codec,
                    bitrate: row.bitrate,
                    stationuuid: row.stationuuid || "",
                    favicon: row.favicon || "",
                    homepage: row.homepage || "",
                    tags: row.tags || "",
                    language: row.language || "",
                    countrycode: row.countrycode || "",
                    groupId: Number(row.gid) || 0
                })
            }
        })
        groups = groupList
        favorites = list
    }

    function groupName(groupId) {
        for (var i = 0; i < groups.length; i++) {
            if (groups[i].id === groupId) {
                return groups[i].name
            }
        }
        return ""
    }

    function favoritesOfGroup(groupId) {
        return favorites.filter(function(f) { return f.groupId === groupId })
    }

    // --- Groups (I1) ---

    function createGroup(name) {
        var id = 0
        db().transaction(function(tx) {
            tx.executeSql(
                "INSERT INTO favorite_groups (name, sort_order) VALUES (?, " +
                "(SELECT COALESCE(MAX(sort_order), -1) + 1 FROM favorite_groups))", [name])
            id = Number(tx.executeSql("SELECT last_insert_rowid() AS id").rows.item(0).id)
        })
        reload()
        return id
    }

    function renameGroup(groupId, name) {
        db().transaction(function(tx) {
            tx.executeSql("UPDATE favorite_groups SET name = ? WHERE id = ?", [name, groupId])
        })
        reload()
    }

    // withFavorites: also delete the favourites in it; otherwise they move
    // to "no group" (at the end of that list)
    function deleteGroup(groupId, withFavorites) {
        deleteGroups([groupId], withFavorites)
    }

    function deleteGroups(groupIds, withFavorites) {
        db().transaction(function(tx) {
            for (var i = 0; i < groupIds.length; i++) {
                if (withFavorites) {
                    tx.executeSql("DELETE FROM favorites WHERE group_id = ?", [groupIds[i]])
                } else {
                    tx.executeSql(
                        "UPDATE favorites SET group_id = NULL, sort_order = sort_order + " +
                        "(SELECT COALESCE(MAX(sort_order), 0) + 1 FROM favorites) WHERE group_id = ?",
                        [groupIds[i]])
                }
                tx.executeSql("DELETE FROM favorite_groups WHERE id = ?", [groupIds[i]])
            }
        })
        reload()
        favoritesChanged()
    }

    // Moves a group one place up (delta -1) or down (+1)
    function moveGroup(groupId, delta) {
        var ids = groups.map(function(g) { return g.id })
        var from = ids.indexOf(groupId)
        var to = from + delta
        if (from < 0 || to < 0 || to >= ids.length) {
            return
        }
        ids.splice(from, 1)
        ids.splice(to, 0, groupId)
        db().transaction(function(tx) {
            for (var i = 0; i < ids.length; i++) {
                tx.executeSql("UPDATE favorite_groups SET sort_order = ? WHERE id = ?", [i, ids[i]])
            }
        })
        reload()
    }

    // Group and position of all favourites at once, e.g. after dragging on
    // the favourites page: entries { url, groupId } in display order
    function setLayout(entries) {
        db().transaction(function(tx) {
            for (var i = 0; i < entries.length; i++) {
                tx.executeSql("UPDATE favorites SET group_id = ?, sort_order = ? WHERE url = ?",
                              [entries[i].groupId > 0 ? entries[i].groupId : null, i, entries[i].url])
            }
        })
        reload()
    }

    function moveToGroup(url, groupId) {
        db().transaction(function(tx) {
            tx.executeSql(
                "UPDATE favorites SET group_id = ?, sort_order = " +
                "(SELECT COALESCE(MAX(sort_order), -1) + 1 FROM favorites) WHERE url = ?",
                [groupId > 0 ? groupId : null, url])
        })
        reload()
    }

    // Restoring a backup (I3, merge): adds favourites that are not there yet
    // (by stationuuid or stream URL) in one go; groups are matched by name
    // and created if missing. Existing favourites keep their group and
    // position. No favoriteAdded() - restoring does not vote.
    // entries: { station: {...}, groupName: "" }, groupNames: in order.
    // Returns the number of added favourites.
    function addMany(entries, groupNames) {
        var added = 0
        db().transaction(function(tx) {
            var groupIds = {}
            var existing = tx.executeSql("SELECT id, name FROM favorite_groups")
            for (var i = 0; i < existing.rows.length; i++) {
                groupIds[existing.rows.item(i).name] = existing.rows.item(i).id
            }
            for (var g = 0; g < groupNames.length; g++) {
                var name = groupNames[g]
                if (name && groupIds[name] === undefined) {
                    tx.executeSql(
                        "INSERT INTO favorite_groups (name, sort_order) VALUES (?, " +
                        "(SELECT COALESCE(MAX(sort_order), -1) + 1 FROM favorite_groups))", [name])
                    groupIds[name] = Number(tx.executeSql("SELECT last_insert_rowid() AS id").rows.item(0).id)
                }
            }
            for (var e = 0; e < entries.length; e++) {
                var st = entries[e].station
                if (!st || !st.url) {
                    continue
                }
                var dup = st.stationuuid
                        ? tx.executeSql("SELECT 1 FROM favorites WHERE url = ? OR (stationuuid = ? AND stationuuid != '')",
                                        [st.url, st.stationuuid])
                        : tx.executeSql("SELECT 1 FROM favorites WHERE url = ?", [st.url])
                if (dup.rows.length > 0) {
                    continue
                }
                var gid = entries[e].groupName && groupIds[entries[e].groupName] !== undefined
                        ? groupIds[entries[e].groupName] : null
                tx.executeSql(
                    "INSERT OR IGNORE INTO favorites " +
                    "(url, name, url_resolved, country, codec, bitrate, stationuuid, favicon, homepage, " +
                    "tags, language, countrycode, group_id, sort_order) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, " +
                    "(SELECT COALESCE(MAX(sort_order), -1) + 1 FROM favorites))",
                    [st.url, st.name || "", st.url_resolved || "", st.country || "", st.codec || "",
                     st.bitrate || 0, st.stationuuid || "", st.favicon || "", st.homepage || "",
                     st.tags || "", st.language || "", st.countrycode || "", gid])
                added++
            }
        })
        reload()
        favoritesChanged()
        healthDelay.restart()
        return added
    }

    // Restoring a backup in "replace" mode: favourites and groups become
    // exactly the backup (order and groups included). Same entry format as
    // addMany; no favoriteAdded() - restoring does not vote.
    function replaceAll(entries, groupNames) {
        db().transaction(function(tx) {
            tx.executeSql("DELETE FROM favorites")
            tx.executeSql("DELETE FROM favorite_groups")
            var groupIds = {}
            for (var g = 0; g < groupNames.length; g++) {
                var name = groupNames[g]
                if (name && groupIds[name] === undefined) {
                    tx.executeSql("INSERT INTO favorite_groups (name, sort_order) VALUES (?, ?)", [name, g])
                    groupIds[name] = Number(tx.executeSql("SELECT last_insert_rowid() AS id").rows.item(0).id)
                }
            }
            for (var e = 0; e < entries.length; e++) {
                var st = entries[e].station
                if (!st || !st.url) {
                    continue
                }
                var gid = entries[e].groupName && groupIds[entries[e].groupName] !== undefined
                        ? groupIds[entries[e].groupName] : null
                tx.executeSql(
                    "INSERT OR IGNORE INTO favorites " +
                    "(url, name, url_resolved, country, codec, bitrate, stationuuid, favicon, homepage, " +
                    "tags, language, countrycode, group_id, sort_order) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    [st.url, st.name || "", st.url_resolved || "", st.country || "", st.codec || "",
                     st.bitrate || 0, st.stationuuid || "", st.favicon || "", st.homepage || "",
                     st.tags || "", st.language || "", st.countrycode || "", gid, e])
            }
        })
        reload()
        favoritesChanged()
        healthDelay.restart()
    }

    function removeMany(urls) {
        db().transaction(function(tx) {
            for (var i = 0; i < urls.length; i++) {
                tx.executeSql("DELETE FROM favorites WHERE url = ?", [urls[i]])
            }
        })
        reload()
        favoritesChanged()
    }
}
