// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library
Qt.include("ServerPool.js")

// Shared helpers for the app's pages: requests to radio-browser.info and
// handling of station data.

// iTunes genre names (primaryGenreName, English - requested with
// lang=en_us) -> radio-browser.info tag. Only for "similar stations" of
// stations without tags (see StationInfoPage). Unknown genres fall back to
// their own lowercase name (e.g. "Reggae" -> "reggae"), which matches many
// radio-browser tags directly.
var itunesGenreTags = {
    "pop": "pop",
    "rock": "rock",
    "alternative": "alternative",
    "indie pop": "indie",
    "indie rock": "indie",
    "hip-hop/rap": "hip hop",
    "hip-hop": "hip hop",
    "rap": "rap",
    "r&b/soul": "rnb",
    "contemporary r&b": "rnb",
    "soul": "soul",
    "electronic": "electronic",
    "electronica": "electronic",
    "dance": "dance",
    "house": "house",
    "techno": "techno",
    "trance": "trance",
    "country": "country",
    "jazz": "jazz",
    "vocal jazz": "jazz",
    "blues": "blues",
    "classical": "classical",
    "soundtrack": "soundtrack",
    "schlager": "schlager",
    "volksmusik": "volksmusik",
    "reggae": "reggae",
    "latin": "latin",
    "latino": "latin",
    "pop latino": "latin",
    "metal": "metal",
    "heavy metal": "metal",
    "hard rock": "hard rock",
    "punk": "punk",
    "singer/songwriter": "singer-songwriter",
    "folk": "folk",
    "world": "world music",
    "worldwide": "world music",
    "christian & gospel": "christian",
    "christian": "christian",
    "gospel": "gospel",
    "new age": "new age",
    "ambient": "ambient",
    "easy listening": "easy listening",
    "oldies": "oldies",
    "k-pop": "k-pop",
    "j-pop": "j-pop",
    "chanson": "chanson",
    "children's music": "children"
};

// Tags that describe the kind of station rather than its programme
// ("public radio", "news", "traffic", ...). Two stations sharing one of them
// are only similar within the same country - a public radio station in
// Houston has nothing in common with one in Slovenia. Used by the similar
// stations (StationInfoPage).
var typeTags = {
    "public radio": true, "public": true, "public service": true,
    "international": true, "government": true,
    "community radio": true, "community": true,
    "college radio": true, "college": true, "university radio": true, "student radio": true,
    "news": true, "local news": true, "news talk": true, "talk": true,
    "traffic": true, "information": true,
    "regional": true, "local": true, "local radio": true,
    "commercial": true, "non-commercial": true
};

function isTypeTag(tag) {
    return typeTags[String(tag || "").toLowerCase()] === true;
}

function tagForItunesGenre(genre) {
    var key = String(genre || "").toLowerCase().replace(/^\s+|\s+$/g, "");
    if (key.length === 0) {
        return "";
    }
    if (itunesGenreTags.hasOwnProperty(key)) {
        return itunesGenreTags[key];
    }
    // Unknown genre: its first part as tag ("Folk-Rock" -> "folk-rock",
    // "Foo/Bar" -> "foo")
    return key.split("/")[0];
}

// Builds a radio-browser.info API URL, e.g. apiUrl("stations/topclick/100").
// The host "server" is a neutral placeholder: requestJson() replaces it with
// the currently active server of the pool on every attempt (see
// getBaseUrl in ServerPool.js). The URL itself stays the same no matter
// which server answers, so it can safely be used as part of cache keys.
function apiUrl(path) {
    return "https://server.api.radio-browser.info/json/" + path;
}

// Station names at radio-browser sometimes start with spaces or tabs or
// contain line breaks (e.g. "  88.9 NOTICIAS", "RADIO MARIAM ARABIC\n...").
// In the one-line lists that shifted the name to the right or made the row
// overflow into the next one, and A-Z put such names first. All whitespace
// runs become one space, the ends are trimmed.
function cleanName(name) {
    return String(name || "").replace(/[\s\u200B\uFEFF]+/g, " ").trim();
}

function stationFromApi(s) {
    return {
        name: cleanName(s.name),
        country: s.country || "",
        language: s.language || "",
        countrycode: s.countrycode || "",
        codec: s.codec || "",
        bitrate: s.bitrate || 0,
        votes: s.votes || 0,
        clickcount: s.clickcount || 0,
        url: s.url || "",
        url_resolved: s.url_resolved || "",
        tags: s.tags || "",
        stationuuid: s.stationuuid || "",
        favicon: s.favicon || "",
        homepage: s.homepage || "",
        // "2026-01-14 22:54:03" (UTC) - compares correctly as text
        lastchangetime: s.lastchangetime || ""
    };
}

// Search results for a typed text: stations whose name starts with the
// phrase first, then names containing it as a whole, then all other matches
// (each word may match anywhere, e.g. "si" in "blasmusik"). The order within
// each group is kept, so the caller sorts first (A-Z, popularity, ...) and
// then groups. phrase: the lowercased search words joined by one space;
// empty = list unchanged. Used by the quick search on the start page and
// the advanced search.
function groupByNameMatch(list, phrase) {
    if (!phrase) {
        return list.slice();
    }
    var groups = [[], [], []];
    for (var i = 0; i < list.length; i++) {
        var name = String(list[i].name || "").toLowerCase();
        var pos = name.indexOf(phrase);
        groups[pos === 0 ? 0 : (pos > 0 ? 1 : 2)].push(list[i]);
    }
    return groups[0].concat(groups[1], groups[2]);
}

function popularity(station) {
    return (station.votes || 0) * 5 + (station.clickcount || 0);
}

function splitList(csv, lowercase) {
    var result = [];
    if (csv === undefined || csv === null) {
        return result;
    }
    var parts = String(csv).split(",");
    for (var i = 0; i < parts.length; i++) {
        var p = parts[i].trim();
        if (lowercase) {
            p = p.toLowerCase();
        }
        if (p.length > 0) {
            result.push(p);
        }
    }
    return result;
}

// GET request, response as JSON. callback(data) - data is null on network
// errors, HTTP status other than 200, or invalid JSON (logged).
// Requests to radio-browser.info automatically switch to the next server on
// server-side failures (no connection, 403, 429, 5xx). Other hosts (e.g.
// ipapi.co) are requested exactly once, without touching the server list.
function requestJson(url, userAgent, callback) {
    var isApi = isApiUrl(url);
    var attemptsLeft = isApi ? servers.length : 1;

    function tryRequest() {
        // Server used for THIS attempt - needed to rotate the right one
        var usedServer = isApi ? getCurrentServer() : "";
        var currentUrl = isApi ? getBaseUrl(url) : url;

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            var status = xhr.status;
            var isServerError = (status === 0 || status === 403 || status === 429 || (status >= 500 && status < 600));

            if (status === 200) {
                var data = null;
                try {
                    data = JSON.parse(xhr.responseText);
                } catch (e) {
                    console.warn("[RadioApi] Parse error: " + e);
                }
                callback(data);
            } else if (isApi && isServerError && attemptsLeft > 1) {
                attemptsLeft--;
                rotateServer(usedServer);
                console.warn("[RadioApi] " + usedServer + " answered " + status + ", switching to " + getCurrentServer());
                tryRequest();
            } else {
                console.warn("[RadioApi] Request failed: " + status);
                callback(null);
            }
        };
        xhr.open("GET", currentUrl);
        if (userAgent) {
            xhr.setRequestHeader("User-Agent", userAgent);
        }
        xhr.send();
    }

    tryRequest();
}

// radio-browser sometimes lists the same stream twice (separate entries
// with their own name, tags and votes). The app identifies a station by its
// stream URL (favourites, history, "now playing"), so only one is kept: the
// one with more tags (up to 5 count - tag lists are what the similar stations
// and the search work with) plus more popularity (log10, so votes/clicks
// weigh about as much as one or two tags). Equal: the entry changed most
// recently (lastchangetime, i.e. maintained last); still equal: the smaller
// uuid - an arbitrary but fixed rule (uuids are random or not ordered by
// time), so the choice never depends on which answer arrived last.
function duplicateQuality(station) {
    return Math.min(splitList(station.tags).length, 5)
            + Math.log(popularity(station) + 1) / Math.LN10;
}

function betterDuplicate(a, b) {
    var qa = duplicateQuality(a);
    var qb = duplicateQuality(b);
    if (qa !== qb) {
        return qa > qb ? a : b;
    }
    var ta = String(a.lastchangetime || "");
    var tb = String(b.lastchangetime || "");
    if (ta !== tb) {
        return ta > tb ? a : b;
    }
    return String(a.stationuuid || "") <= String(b.stationuuid || "") ? a : b;
}

// Sends all station requests at once, merges the stations of all responses
// (duplicates by stream URL merged, see betterDuplicate) and calls
// onDone(merged, failedCount) exactly
// once at the end. failedCount is the number of requests that returned no data,
// so callers can tell "no results" (0 failed) from "no connection" (all failed).
//
// isStale (optional): returns true as soon as the result is no longer needed;
// onDone is then not called at all.
function fetchAll(urls, userAgent, isStale, onDone) {
    var merged = {};
    var pending = urls.length;
    var failed = 0;
    if (pending === 0) {
        onDone(merged, 0);
        return;
    }
    for (var i = 0; i < urls.length; i++) {
        requestJson(urls[i], userAgent, function(data) {
            if (isStale && isStale()) {
                return;
            }
            if (Array.isArray(data)) {
                for (var j = 0; j < data.length; j++) {
                    var s = stationFromApi(data[j]);
                    var key = s.url || s.stationuuid || s.name;
                    merged[key] = merged[key] ? betterDuplicate(merged[key], s) : s;
                }
            } else {
                failed += 1;
            }
            pending -= 1;
            if (pending === 0) {
                onDone(merged, failed);
            }
        });
    }
}

// The user's country by IP address. callback(code) - two-letter ISO code in
// upper case, or null if no service answered with a valid code.
// ipapi.co refuses requests without a User-Agent (403) and rate-limits
// heavily, so the request carries the app's User-Agent and falls back to
// api.country.is if ipapi.co does not answer.
function fetchUserCountry(callback, userAgent) {
    function valid(code) {
        code = code ? String(code).toUpperCase() : "";
        return /^[A-Z]{2}$/.test(code) ? code : null;
    }
    requestJson("https://ipapi.co/json/", userAgent || "", function(data) {
        var code = valid(data && data.country_code);
        if (code) {
            callback(code);
            return;
        }
        requestJson("https://api.country.is/", userAgent || "", function(data2) {
            callback(valid(data2 && data2.country));
        });
    });
}
