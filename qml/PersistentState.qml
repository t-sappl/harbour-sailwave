import QtQuick 2.6
import QtQuick.LocalStorage 2.0

// Stores 1) the last played station (to resume automatically)
// and 2) search results with a timestamp (as a simple cache, so that a
// repeated search does not hit the network again right away).

Item {
    id: persistentState

    // Cache validity for search results: 10 minutes
    property int cacheTtlMs: 10 * 60 * 1000

    // In-memory cache of the homepage overrides (stationuuid -> homepage).
    // Loaded once at startup and updated on every change - so
    // getHomepageOverride() needs NO database transaction of its own.
    // Important for performance: StationIcon queries this for every station
    // row, and lists recycle their delegates constantly while scrolling - a
    // synchronous SQLite query per icon change caused stutter and
    // flickering favicons.
    property var homepageOverridesCache: ({})

    function db() {
        return LocalStorage.openDatabaseSync("harbour-sailwave", "1.0", "Sailwave Radio State", 200000)
    }

    Component.onCompleted: {
        initDb()
        pruneSearchCache()
        loadHomepageOverridesCache()
    }

    function loadHomepageOverridesCache() {
        var cache = {}
        db().transaction(function(tx) {
            var result = tx.executeSql("SELECT stationuuid, homepage FROM homepage_overrides")
            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                cache[row.stationuuid] = row.homepage || ""
            }
        })
        homepageOverridesCache = cache
    }

    function initDb() {
        db().transaction(function(tx) {
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS app_state(key TEXT PRIMARY KEY, value TEXT)"
            )
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS search_cache(" +
                "cache_key TEXT PRIMARY KEY, results TEXT, timestamp INTEGER)"
            )
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS track_history(" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, station_name TEXT, " +
                "stationuuid TEXT, favicon TEXT, url TEXT, url_resolved TEXT, timestamp INTEGER)"
            )
            // Migration for installations where track_history was created without
            // stationuuid/favicon/url/url_resolved (fails harmlessly if the column
            // already exists)
            try {
                tx.executeSql("ALTER TABLE track_history ADD COLUMN stationuuid TEXT")
            } catch (e) {
                // Column already exists - no problem
            }
            try {
                tx.executeSql("ALTER TABLE track_history ADD COLUMN favicon TEXT")
            } catch (e) {
                // Column already exists - no problem
            }
            try {
                tx.executeSql("ALTER TABLE track_history ADD COLUMN url TEXT")
            } catch (e) {
                // Column already exists - no problem
            }
            try {
                tx.executeSql("ALTER TABLE track_history ADD COLUMN url_resolved TEXT")
            } catch (e) {
                // Column already exists - no problem
            }
            // URL of the album cover for the title (found via iTunes)
            try {
                tx.executeSql("ALTER TABLE track_history ADD COLUMN art_url TEXT")
            } catch (e) {
                // Column already exists - no problem
            }
            // Album name for the title (from iTunes)
            try {
                tx.executeSql("ALTER TABLE track_history ADD COLUMN album_name TEXT")
            } catch (e) {
                // Column already exists - no problem
            }
            // Station homepage, so the track history can show the same logo
            // fallback (Google favicon) as the rest of the app
            try {
                tx.executeSql("ALTER TABLE track_history ADD COLUMN homepage TEXT")
            } catch (e) {
                // Column already exists - no problem
            }
            try {
                // iTunes genre of the song (for similar stations, see getGenreCounts)
                tx.executeSql("ALTER TABLE track_history ADD COLUMN genre TEXT")
            } catch (e) {
                // Column already exists - no problem
            }
            try {
                // Artist and title as written by iTunes - only stored when
                // they match the stream text (see CoverArtCache), so the
                // track history can show them in proper spelling
                tx.executeSql("ALTER TABLE track_history ADD COLUMN itunes_artist TEXT")
            } catch (e) {
                // Column already exists - no problem
            }
            try {
                tx.executeSql("ALTER TABLE track_history ADD COLUMN itunes_title TEXT")
            } catch (e) {
                // Column already exists - no problem
            }
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS station_history(" +
                "url TEXT PRIMARY KEY, name TEXT, url_resolved TEXT, country TEXT, " +
                "codec TEXT, bitrate INTEGER, stationuuid TEXT, favicon TEXT, homepage TEXT, timestamp INTEGER)"
            )
            // Migration for installations where station_history was created without
            // the homepage column (fails harmlessly if the column already
            // exists)
            try {
                tx.executeSql("ALTER TABLE station_history ADD COLUMN homepage TEXT")
            } catch (e) {
                // Column already exists - no problem
            }
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS homepage_overrides(" +
                "stationuuid TEXT PRIMARY KEY, homepage TEXT)"
            )
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS voted_stations(" +
                "stationuuid TEXT PRIMARY KEY, timestamp INTEGER)"
            )
        })
    }

    // --- Last played station ---

    function saveLastStation(station) {
        var value = JSON.stringify(station)
        db().transaction(function(tx) {
            tx.executeSql(
                "INSERT OR REPLACE INTO app_state (key, value) VALUES ('last_station', ?)",
                [value]
            )
        })
    }

    function loadLastStation() {
        var found = null
        db().transaction(function(tx) {
            var result = tx.executeSql("SELECT value FROM app_state WHERE key = 'last_station'")
            if (result.rows.length > 0) {
                try {
                    found = JSON.parse(result.rows.item(0).value)
                } catch (e) {
                    console.warn("Could not read last station: " + e)
                }
            }
        })
        return found
    }

    function clearLastStation() {
        db().transaction(function(tx) {
            tx.executeSql("DELETE FROM app_state WHERE key = 'last_station'")
        })
    }

    function clearTrackHistory() {
        db().transaction(function(tx) {
            tx.executeSql("DELETE FROM track_history")
        })
    }

    function clearStationHistory() {
        db().transaction(function(tx) {
            tx.executeSql("DELETE FROM station_history")
        })
    }

    // Clears the cache for search results and top lists. The next request
    // fetches fresh data from radio-browser.info.
    function clearSearchCache() {
        db().transaction(function(tx) {
            tx.executeSql("DELETE FROM search_cache")
            tx.executeSql("DELETE FROM app_state WHERE key = 'top_stations'")
        })
    }

    // Removes expired entries. Every new search creates its own entry and
    // entries are only ever replaced, never removed - without this the table
    // would keep growing until the cache is cleared in Settings.
    function pruneSearchCache() {
        var oldest = Date.now() - cacheTtlMs
        db().transaction(function(tx) {
            tx.executeSql("DELETE FROM search_cache WHERE timestamp < ?", [oldest])
        })
    }

    // --- Top stations snapshot ---
    // The first entries of the last computed top station list, shown right
    // away at the next app start while fresh data loads in the background.
    // Kept in app_state (not search_cache), because it is used for much
    // longer than the 10 minutes of the search cache.

    function saveTopStationsSnapshot(stations) {
        var value = JSON.stringify({ timestamp: Date.now(), stations: stations })
        db().transaction(function(tx) {
            tx.executeSql(
                "INSERT OR REPLACE INTO app_state (key, value) VALUES ('top_stations', ?)",
                [value]
            )
        })
    }

    // Returns { stations: [...], timestamp: ms } or null if there is none or
    // it is older than maxAgeMs
    function loadTopStationsSnapshot(maxAgeMs) {
        var found = null
        db().transaction(function(tx) {
            var result = tx.executeSql("SELECT value FROM app_state WHERE key = 'top_stations'")
            if (result.rows.length > 0) {
                try {
                    var snapshot = JSON.parse(result.rows.item(0).value)
                    if (snapshot && Array.isArray(snapshot.stations)
                            && Date.now() - snapshot.timestamp <= maxAgeMs) {
                        found = snapshot
                    }
                } catch (e) {
                    console.warn("Could not read top stations snapshot: " + e)
                }
            }
        })
        return found
    }

    // --- Search result cache ---

    function getCachedResults(cacheKey) {
        var found = null
        db().transaction(function(tx) {
            var result = tx.executeSql(
                "SELECT results, timestamp FROM search_cache WHERE cache_key = ?",
                [cacheKey]
            )
            if (result.rows.length > 0) {
                var row = result.rows.item(0)
                var age = Date.now() - row.timestamp
                if (age <= cacheTtlMs) {
                    try {
                        found = JSON.parse(row.results)
                    } catch (e) {
                        console.warn("Cache parse error: " + e)
                    }
                }
            }
        })
        return found
    }

    function setCachedResults(cacheKey, resultsArray) {
        var value = JSON.stringify(resultsArray)
        var now = Date.now()
        db().transaction(function(tx) {
            tx.executeSql(
                "INSERT OR REPLACE INTO search_cache (cache_key, results, timestamp) VALUES (?, ?, ?)",
                [cacheKey, value, now]
            )
        })
    }

    // --- Track history (from the ICY metadata of the current stream) ---

    property int trackHistoryLimit: 50

    function addTrackTitle(title, stationName, stationuuid, favicon, url, urlResolved, homepage) {
        var now = Date.now()
        db().transaction(function(tx) {
            tx.executeSql(
                "INSERT INTO track_history (title, station_name, stationuuid, favicon, url, url_resolved, homepage, timestamp) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [title, stationName || "", stationuuid || "", favicon || "", url || "", urlResolved || "", homepage || "", now]
            )
            // Keep the table small: only keep the last trackHistoryLimit entries
            tx.executeSql(
                "DELETE FROM track_history WHERE id NOT IN " +
                "(SELECT id FROM track_history ORDER BY timestamp DESC LIMIT ?)",
                [trackHistoryLimit]
            )
        })
    }

    // Attaches the album cover URL and album name to the newest matching entry
    function setTrackDetails(title, stationName, artUrl, albumName, genre, itunesArtist, itunesTitle) {
        if (!title) {
            return
        }
        db().transaction(function(tx) {
            tx.executeSql(
                // An empty album name or genre never overwrites a known one
                "UPDATE track_history SET art_url = ?, " +
                "album_name = CASE WHEN ? = '' THEN album_name ELSE ? END, " +
                "genre = CASE WHEN ? = '' THEN genre ELSE ? END, " +
                "itunes_artist = CASE WHEN ? = '' THEN itunes_artist ELSE ? END, " +
                "itunes_title = CASE WHEN ? = '' THEN itunes_title ELSE ? END WHERE id = " +
                "(SELECT id FROM track_history WHERE title = ? AND station_name = ? " +
                "ORDER BY timestamp DESC LIMIT 1)",
                [artUrl || "", albumName || "", albumName || "", genre || "", genre || "",
                 itunesArtist || "", itunesArtist || "", itunesTitle || "", itunesTitle || "",
                 title, stationName || ""]
            )
        })
    }

    // How often each iTunes genre occurs in a station's latest tracks (each
    // title counted once). Returns { counts: { genre: n }, total: n } -
    // total = titles with a known genre.
    function getGenreCounts(stationuuid, stationName, limit) {
        var counts = {}
        var total = 0
        db().transaction(function(tx) {
            var result = tx.executeSql(
                "SELECT title, genre FROM track_history " +
                "WHERE (stationuuid = ? AND ? != '') OR station_name = ? " +
                "ORDER BY timestamp DESC LIMIT ?",
                [stationuuid || "", stationuuid || "", stationName || "", limit || 50]
            )
            var seenTitles = {}
            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                var genre = row.genre || ""
                if (genre.length === 0 || seenTitles[row.title]) {
                    continue
                }
                seenTitles[row.title] = true
                counts[genre] = (counts[genre] || 0) + 1
                total++
            }
        })
        return { counts: counts, total: total }
    }

    // Backwards-compatible wrapper in case it is still called somewhere
    function setTrackArt(title, stationName, artUrl) {
        setTrackDetails(title, stationName, artUrl, "")
    }

    // Cover (and album name) already found for this title, possibly from
    // another station - saves another iTunes request.
    // Returns { artUrl, albumName }; both "" if nothing is known.
    function getTrackDetails(title) {
        var found = { artUrl: "", albumName: "", genre: "", itunesArtist: "", itunesTitle: "" }
        if (!title) {
            return found
        }
        db().transaction(function(tx) {
            var result = tx.executeSql(
                "SELECT art_url, album_name, genre, itunes_artist, itunes_title FROM track_history " +
                "WHERE title = ? AND art_url IS NOT NULL " +
                "AND art_url != '' ORDER BY timestamp DESC LIMIT 1",
                [title]
            )
            if (result.rows.length > 0) {
                found.artUrl = result.rows.item(0).art_url || ""
                found.albumName = result.rows.item(0).album_name || ""
                found.genre = result.rows.item(0).genre || ""
                found.itunesArtist = result.rows.item(0).itunes_artist || ""
                found.itunesTitle = result.rows.item(0).itunes_title || ""
            }
        })
        return found
    }

    // Backwards-compatible: only the cover URL
    function getTrackArt(title) {
        return getTrackDetails(title).artUrl
    }

    // Delete a single entry (context menu in the track history)
    function deleteTrackHistoryItem(stationName, timestamp) {
        db().transaction(function(tx) {
            tx.executeSql(
                "DELETE FROM track_history WHERE station_name = ? AND timestamp = ?",
                [stationName || "", timestamp]
            )
        })
    }

    function getTrackHistory(limit) {
        var list = []
        db().transaction(function(tx) {
            var result = tx.executeSql(
                // Older rows have no homepage yet - take it from the station
                // history (same stationuuid) in that case
                "SELECT t.title, t.station_name, t.stationuuid, t.favicon, t.url, t.url_resolved, " +
                "t.art_url, t.album_name, t.genre, t.itunes_artist, t.itunes_title, t.timestamp, " +
                "COALESCE(NULLIF(t.homepage, ''), (SELECT s.homepage FROM station_history s WHERE s.stationuuid = t.stationuuid AND s.stationuuid != '' AND s.homepage != '' ORDER BY s.timestamp DESC LIMIT 1), '') AS homepage " +
                "FROM track_history t ORDER BY t.timestamp DESC LIMIT ?",
                [limit || trackHistoryLimit]
            )
            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                list.push({
                    title: row.title,
                    stationName: row.station_name,
                    stationuuid: row.stationuuid || "",
                    favicon: row.favicon || "",
                    url: row.url || "",
                    url_resolved: row.url_resolved || "",
                    artUrl: row.art_url || "",
                    albumName: row.album_name || "",
                    genre: row.genre || "",
                    itunesArtist: row.itunes_artist || "",
                    itunesTitle: row.itunes_title || "",
                    homepage: row.homepage || "",
                    timestamp: row.timestamp
                })
            }
        })
        return list
    }

    // --- Station history (recently played stations, deduplicated by URL) ---

    property int stationHistoryLimit: 30

    function recordStationHistory(station) {
        var now = Date.now()
        db().transaction(function(tx) {
            tx.executeSql(
                "INSERT OR REPLACE INTO station_history " +
                "(url, name, url_resolved, country, codec, bitrate, stationuuid, favicon, homepage, timestamp) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [station.url, station.name, station.url_resolved || "",
                 station.country || "", station.codec || "", station.bitrate || 0,
                 station.stationuuid || "", station.favicon || "", station.homepage || "", now]
            )
            // Keep the table small: only keep the last stationHistoryLimit entries
            tx.executeSql(
                "DELETE FROM station_history WHERE url NOT IN " +
                "(SELECT url FROM station_history ORDER BY timestamp DESC LIMIT ?)",
                [stationHistoryLimit]
            )
        })
    }

    function removeStationHistory(url) {
            if (!url) {
                return
            }
            db().transaction(function(tx) {
                tx.executeSql("DELETE FROM station_history WHERE url = ?", [url])
            })
        }

    function getStationHistory(limit) {
        var list = []
        db().transaction(function(tx) {
            var result = tx.executeSql(
                "SELECT * FROM station_history ORDER BY timestamp DESC LIMIT ?",
                [limit || stationHistoryLimit]
            )
            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                list.push({
                    name: row.name,
                    url: row.url,
                    url_resolved: row.url_resolved,
                    country: row.country,
                    codec: row.codec,
                    bitrate: row.bitrate,
                    stationuuid: row.stationuuid || "",
                    favicon: row.favicon || "",
                    homepage: row.homepage || ""
                })
            }
        })
        return list
    }

    // --- Manually corrected station homepage (radio-browser sometimes gets it wrong) ---

    function setHomepageOverride(stationuuid, homepage) {
        if (!stationuuid) {
            return
        }
        db().transaction(function(tx) {
            tx.executeSql(
                "INSERT OR REPLACE INTO homepage_overrides (stationuuid, homepage) VALUES (?, ?)",
                [stationuuid, homepage]
            )
        })
        var cache = homepageOverridesCache
        cache[stationuuid] = homepage
        homepageOverridesCache = cache
    }

    // Read-only access to the in-memory cache - no database transaction
    // per call anymore (see the comment on homepageOverridesCache above).
    function getHomepageOverride(stationuuid) {
        if (!stationuuid) {
            return ""
        }
        return homepageOverridesCache[stationuuid] || ""
    }

    function clearHomepageOverride(stationuuid) {
        if (!stationuuid) {
            return
        }
        db().transaction(function(tx) {
            tx.executeSql("DELETE FROM homepage_overrides WHERE stationuuid = ?", [stationuuid])
        })
        var cache = homepageOverridesCache
        delete cache[stationuuid]
        homepageOverridesCache = cache
    }

    // --- Vote status (already voted for this station?) ---

    function markVoted(stationuuid) {
        if (!stationuuid) {
            return
        }
        db().transaction(function(tx) {
            tx.executeSql(
                "INSERT OR REPLACE INTO voted_stations (stationuuid, timestamp) VALUES (?, ?)",
                [stationuuid, Date.now()]
            )
        })
    }

    // Time of the own last vote for a station (ms), 0 = never
    function lastVoteTime(stationuuid) {
        if (!stationuuid) {
            return 0
        }
        var time = 0
        db().transaction(function(tx) {
            var result = tx.executeSql(
                "SELECT timestamp FROM voted_stations WHERE stationuuid = ?",
                [stationuuid]
            )
            if (result.rows.length > 0) {
                time = Number(result.rows.item(0).timestamp) || 0
            }
        })
        return time
    }

    function hasVoted(stationuuid) {
        if (!stationuuid) {
            return false
        }
        var found = false
        db().transaction(function(tx) {
            var result = tx.executeSql(
                "SELECT 1 FROM voted_stations WHERE stationuuid = ?",
                [stationuuid]
            )
            found = result.rows.length > 0
        })
        return found
    }

    // --- Track history for a single station (matched by name, since the
    // track history does not carry a stationuuid) ---

    function getTrackHistoryForStation(stationName, limit) {
        var list = []
        if (!stationName) {
            return list
        }
        db().transaction(function(tx) {
            var result = tx.executeSql(
                "SELECT t.title, t.station_name, t.stationuuid, t.favicon, t.url, t.url_resolved, " +
                "t.art_url, t.album_name, t.genre, t.itunes_artist, t.itunes_title, t.timestamp, " +
                "COALESCE(NULLIF(t.homepage, ''), (SELECT s.homepage FROM station_history s WHERE s.stationuuid = t.stationuuid AND s.stationuuid != '' AND s.homepage != '' ORDER BY s.timestamp DESC LIMIT 1), '') AS homepage " +
                "FROM track_history t WHERE t.station_name = ? ORDER BY t.timestamp DESC LIMIT ?",
                [stationName, limit || 50]
            )
            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                list.push({
                    title: row.title,
                    stationName: row.station_name,
                    stationuuid: row.stationuuid || "",
                    favicon: row.favicon || "",
                    url: row.url || "",
                    url_resolved: row.url_resolved || "",
                    artUrl: row.art_url || "",
                    albumName: row.album_name || "",
                    genre: row.genre || "",
                    itunesArtist: row.itunes_artist || "",
                    itunesTitle: row.itunes_title || "",
                    homepage: row.homepage || "",
                    timestamp: row.timestamp
                })
            }
        })
        return list
    }

    // --- UI settings (collapse states) ---

    function getCollapseState(key, defaultValue) {
        var result = defaultValue
        try {
            db().transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS ui_settings (key TEXT PRIMARY KEY, value TEXT)')
                var rs = tx.executeSql('SELECT value FROM ui_settings WHERE key = ?', [key])
                if (rs.rows.length > 0) {
                    result = (rs.rows.item(0).value === "true")
                }
            })
        } catch (e) {
            console.warn("Error reading collapse state: " + e)
        }
        return result
    }

    function setCollapseState(key, value) {
        db().transaction(function(tx) {
            tx.executeSql('CREATE TABLE IF NOT EXISTS ui_settings (key TEXT PRIMARY KEY, value TEXT)')
            tx.executeSql('INSERT OR REPLACE INTO ui_settings (key, value) VALUES (?, ?)', [key, value ? "true" : "false"])
        })
    }
}
