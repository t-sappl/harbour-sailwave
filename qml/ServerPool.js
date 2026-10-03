// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// List of radio-browser.info API servers with automatic failover.
//
// radio-browser.info runs several equivalent servers and asks apps not to
// hard-code one of them, but to fetch the current list and spread requests.
// The list is fetched once on first use; until then (and if that fails) the
// built-in fallback list below is used. Included into RadioApi.js via
// Qt.include(), so all pages share the same state.

var servers = ["de1", "fi1", "nl1"]; // Built-in fallback list
var currentIndex = 0;
var initialized = false;

function ensureInitialized() {
    if (initialized) return;
    initialized = true;

    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
            try {
                var data = JSON.parse(xhr.responseText);
                if (Array.isArray(data) && data.length > 0) {
                    var list = [];
                    for (var i = 0; i < data.length; i++) {
                        var rawName = typeof data[i] === "string" ? data[i] : (data[i].name || "");
                        if (rawName) {
                            var name = rawName.split(".")[0];
                            if (name) {
                                list.push(name);
                            }
                        }
                    }
                    if (list.length > 0) {
                        for (var j = list.length - 1; j > 0; j--) {
                            var k = Math.floor(Math.random() * (j + 1));
                            var temp = list[j];
                            list[j] = list[k];
                            list[k] = temp;
                        }
                        servers = list;
                        currentIndex = 0;
                    }
                }
            } catch (e) {
                console.warn("[ServerPool] Parse error: " + e);
            }
        }
    };
    xhr.open("GET", "https://all.api.radio-browser.info/json/servers");
    xhr.send();
}

function getCurrentServer() {
    ensureInitialized();
    return servers[currentIndex] || "de1";
}

// True if the URL goes to the radio-browser.info API (any of its servers).
// Only these requests take part in the server failover.
function isApiUrl(url) {
    return /^https?:\/\/[a-zA-Z0-9_-]+\.api\.radio-browser\.info\//.test(String(url));
}

// Moves the failed server to the end of the list. Only acts if failedName is
// still the active server: when several requests fail at the same time, the
// first one switches and the others must not skip a working server.
function rotateServer(failedName) {
    if (servers.length > 1 && (!failedName || servers[currentIndex] === failedName)) {
        var failed = servers[currentIndex];
        var s = servers.splice(currentIndex, 1)[0];
        servers.push(s);
        currentIndex = 0;
        console.warn("[ServerPool] Server " + failed + " failed, switching to " + servers[currentIndex]);
    }
}

function getBaseUrl(originalUrl) {
    var active = getCurrentServer();
    return originalUrl.replace(/https:\/\/[a-zA-Z0-9_-]+\.api\.radio-browser\.info/, "https://" + active + ".api.radio-browser.info");
}
