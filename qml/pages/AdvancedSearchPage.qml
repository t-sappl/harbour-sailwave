// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import QtQuick.Layouts 1.1
import Sailfish.Silica 1.0
import "../"
import "../CountryData.js" as CountryData
import "../RadioApi.js" as RadioApi

Page {
    id: searchPage

    readonly property string apiBase: RadioApi.apiUrl("stations/")
    // Home country; comes from appWindow.resolveUserCountry()
    property string userCountry: ""
    property var recommendedTags: []
    property var recommendedLanguages: []
    // Calculated from the home country (CountryData.rankCountries) -
    // deliberately no hard-coded countries, so the app starts sensibly everywhere
    property var recommendedCountries: []

    property var countryLangMap: ({})
    property var radioLanguageCache: ({})

    property var activeTags: []
    property var activeLanguages: []
    property var activeCountryCodes: []

    property int minBitrate: 0
    property string sortMode: "popularity" // "popularity" or "alphabetical"

    property bool weightByHome: true
    property real ownCountryFactor: 2
    property int minSearchLength: 2

    // Property for the search string passed in
    property string initialSearchText: ""

    // Ring navigation (TopStations -> track history -> advanced search -> TopStations).
    // Only the three fixed ring instances from harbour-sailwave.qml have
    // ringMember: true. Copies of this page opened via push() behave like
    // normal stack pages.
    property bool ringMember: false

    onStatusChanged: {
        if (ringMember && status === PageStatus.Active) {
            appWindow.ringPageActivated(searchPage)
        }
        if (status === PageStatus.Deactivating) {
            searchResultsHint.dismiss()
        }
        // Load the popular genres/languages as soon as the page is shown for
        // the first time, so they are there before a filter is opened
        // (and not inserted into an already open filter afterwards)
        if (status === PageStatus.Active && !_listsRequested) {
            _listsRequested = true
            ensureAllTags()
            ensureAllLanguages()
        }
    }
    property bool _listsRequested: false

    onActiveCountryCodesChanged: {
        updateRecommendedLanguages()
    }

    property string tagMatchMode: "OR"
    property string languageMatchMode: "OR"
    property string countryMatchMode: "OR"

    property string searchFieldText: ""

    // Search for a text from outside (e.g. "Find alternative" for a
    // favourite): clears the filters and puts the text into the search
    // field, which then searches as if it had been typed
    signal searchRequested(string text)

    function searchFor(text) {
        activeTags = []
        activeLanguages = []
        activeCountryCodes = []
        openFilter = ""
        searchRequested(text)
        // Also when the field already showed this text (no change signal)
        searchFieldText = text
        searchTimer.restart()
    }

    // --- Filter selection (genres, languages, countries) ---
    // Which filter is expanded: "genres", "languages", "countries" or ""
    property string openFilter: ""
    // Popular genres / languages of radio-browser.info (beyond the
    // suggestions), loaded the first time the filter is opened
    property var allTags: []
    property var allLanguages: []
    property bool _tagsLoading: false
    property bool _languagesLoading: false

    // Error / empty state of the last search (shown below the results)
    property bool searchDone: false
    property bool searchFailed: false
    property int searchRequestId: 0

    Component.onCompleted: {
        refreshDynamicFilters()

        var cachedCountries = appWindow.persistentState && typeof appWindow.persistentState.getCachedResults === "function"
                ? appWindow.persistentState.getCachedResults("advanced_search_recommended_countries_v2") : null

        if (cachedCountries && cachedCountries.length > 0) {
            recommendedCountries = cachedCountries
            updateRecommendedLanguages()
        }

        applyUserCountry()

        if (initialSearchText.length > 0) {
            searchPage.searchFieldText = initialSearchText
            performAdvancedSearch(initialSearchText, activeTags, activeLanguages, activeCountryCodes)
        }
    }

    // Home country from the central place in harbour-sailwave.qml (chosen in
    // Settings, detected by IP or taken from the system locale)
    function applyUserCountry() {
        appWindow.resolveUserCountry(function(code) {
            userCountry = code || ""
            updateCountryRecommendations(userCountry)
        })
    }

    Connections {
        target: appWindow.appSettings
        onHomeCountryChanged: searchPage.applyUserCountry()
    }

    function refreshDynamicFilters() {
        var tagCounts = {}
        var langCounts = {}

        function extractFromList(list) {
            if (!list) return
            for (var i = 0; i < list.length; i++) {
                var item = list[i]
                var tags = RadioApi.splitList(item.tags, true)
                for (var t = 0; t < tags.length; t++) {
                    tagCounts[tags[t]] = (tagCounts[tags[t]] || 0) + 1
                }
                var langs = RadioApi.splitList(item.language, true)
                for (var l = 0; l < langs.length; l++) {
                    langCounts[langs[l]] = (langCounts[langs[l]] || 0) + 1
                }
            }
        }

        if (appWindow && appWindow.favoritesStore && appWindow.favoritesStore.favorites) {
            extractFromList(appWindow.favoritesStore.favorites)
        }
        if (appWindow && appWindow.persistentState && typeof appWindow.persistentState.getStationHistory === "function") {
            extractFromList(appWindow.persistentState.getStationHistory(30))
        }

        var sortableTags = []
        for (var tag in tagCounts) {
            sortableTags.push([tag, tagCounts[tag]])
        }
        sortableTags.sort(function(a, b) { return b[1] - a[1] })

        var topTags = []
        for (var j = 0; j < sortableTags.length && j < 12; j++) {
            topTags.push(sortableTags[j][0])
        }

        var defaultTags = ["classical", "rock", "pop", "jazz", "news", "electronic", "ambient", "metal"]
        for (var d = 0; d < defaultTags.length; d++) {
            if (topTags.indexOf(defaultTags[d]) === -1 && topTags.length < 10) {
                topTags.push(defaultTags[d])
            }
        }
        recommendedTags = topTags

        var sortableLangs = []
        for (var lang in langCounts) {
            sortableLangs.push([lang, langCounts[lang]])
        }
        sortableLangs.sort(function(a, b) { return b[1] - a[1] })

        var topLangs = []
        for (var k = 0; k < sortableLangs.length && k < 10; k++) {
            topLangs.push(sortableLangs[k][0])
        }

        var defaultLangs = ["german", "english", "french", "spanish", "italian"]
        for (var dl = 0; dl < defaultLangs.length; dl++) {
            if (topLangs.indexOf(defaultLangs[dl]) === -1 && topLangs.length < 8) {
                topLangs.push(defaultLangs[dl])
            }
        }

        if (Object.keys(countryLangMap).length === 0 && activeCountryCodes.length === 0) {
            recommendedLanguages = topLangs
        }
    }

    function updateRecommendedLanguages() {
        if (!activeCountryCodes || activeCountryCodes.length === 0) {
            var langs = []
            var targetCountries = recommendedCountries.map(function(c) { return c.iso_code; })

            for (var i = 0; i < targetCountries.length; i++) {
                var code = targetCountries[i]
                if (countryLangMap[code]) {
                    var cLangs = countryLangMap[code]
                    for (var j = 0; j < cLangs.length; j++) {
                        var l = cLangs[j].toLowerCase()
                        if (langs.indexOf(l) === -1) {
                            langs.push(l)
                        }
                    }
                }
            }

            if (langs.length > 0) {
                recommendedLanguages = langs
            } else {
                refreshDynamicFilters()
            }
            validateActiveLanguages()
            return;
        }

        var combinedLangCounts = {}
        var countriesToFetch = []

        for (var c = 0; c < activeCountryCodes.length; c++) {
            var countryCode = activeCountryCodes[c]
            if (radioLanguageCache[countryCode]) {
                var cachedCounts = radioLanguageCache[countryCode]
                for (var l in cachedCounts) {
                    combinedLangCounts[l] = (combinedLangCounts[l] || 0) + cachedCounts[l]
                }
            } else {
                countriesToFetch.push(countryCode)
            }
        }

        if (countriesToFetch.length === 0) {
            finalizeRadioLanguages(combinedLangCounts)
            return
        }

        var pendingRequests = countriesToFetch.length

        function checkRadioLanguagesFinished() {
            pendingRequests--
            if (pendingRequests <= 0) {
                finalizeRadioLanguages(combinedLangCounts)
            }
        }

        for (var f = 0; f < countriesToFetch.length; f++) {
            (function(codeToFetch) {
                RadioApi.requestJson(apiBase + "bycountrycodeexact/" + encodeURIComponent(codeToFetch) + "?hidebroken=true",
                                     appWindow.apiUserAgent, function(stations) {
                    var singleCountryLangCounts = {}
                    if (stations) {
                        for (var s = 0; s < stations.length; s++) {
                            var stationLangs = RadioApi.splitList(stations[s].language, true)
                            for (var p = 0; p < stationLangs.length; p++) {
                                singleCountryLangCounts[stationLangs[p]] = (singleCountryLangCounts[stationLangs[p]] || 0) + 1
                            }
                        }
                    }
                    radioLanguageCache[codeToFetch] = singleCountryLangCounts

                    for (var l in singleCountryLangCounts) {
                        combinedLangCounts[l] = (combinedLangCounts[l] || 0) + singleCountryLangCounts[l]
                    }

                    checkRadioLanguagesFinished()
                })
            })(countriesToFetch[f])
        }
    }

    function finalizeRadioLanguages(langCounts) {
        var sortable = []
        for (var l in langCounts) {
            sortable.push([l, langCounts[l]])
        }
        sortable.sort(function(a, b) { return b[1] - a[1] })

        var topLangs = []
        for (var idx = 0; idx < sortable.length && idx < 15; idx++) {
            topLangs.push(sortable[idx][0])
        }

        if (topLangs.length > 0) {
            recommendedLanguages = topLangs
        }
        validateActiveLanguages()
    }

    function validateActiveLanguages() {
        if (!activeLanguages) return
        var validActiveLangs = []
        for (var k = 0; k < activeLanguages.length; k++) {
            // Keep a language that was picked from the full list ("More
            // languages"); only drop ones that are in neither list
            if (recommendedLanguages.indexOf(activeLanguages[k]) !== -1
                    || allLanguages.indexOf(activeLanguages[k]) !== -1) {
                validActiveLangs.push(activeLanguages[k])
            }
        }
        if (validActiveLangs.length !== activeLanguages.length) {
            activeLanguages = validActiveLangs
            performAdvancedSearch(searchPage.searchFieldText, activeTags, activeLanguages, activeCountryCodes)
        }
    }

    function updateCountryRecommendations(userCountryCode) {
        countryLangMap = CountryData.languageMap()
        var list = CountryData.rankCountries(userCountryCode, 20)

        if (list.length > 0) {
            var isDifferent = false
            if (recommendedCountries.length !== list.length) {
                isDifferent = true
            } else {
                for (var idx = 0; idx < list.length; idx++) {
                    if (recommendedCountries[idx].iso_code !== list[idx].iso_code ||
                        recommendedCountries[idx].name !== list[idx].name) {
                        isDifferent = true
                        break
                    }
                }
            }

            if (isDifferent) {
                recommendedCountries = list
            }

            if (appWindow && appWindow.persistentState && typeof appWindow.persistentState.setCachedResults === "function") {
                appWindow.persistentState.setCachedResults("advanced_search_recommended_countries_v2", list)
            }
        }

        updateRecommendedLanguages()
    }

    function toggleFilter(kind) {
        openFilter = (openFilter === kind) ? "" : kind
        if (openFilter === "genres") {
            ensureAllTags()
        } else if (openFilter === "languages") {
            ensureAllLanguages()
        }
    }

    function activeList(kind) {
        if (kind === "genres") return activeTags || []
        if (kind === "languages") return activeLanguages || []
        return activeCountryCodes || []
    }

    function isActive(kind, key) {
        return activeList(kind).indexOf(key) !== -1
    }

    function toggleFilterValue(kind, key) {
        var list = activeList(kind).slice()
        var index = list.indexOf(key)
        if (index !== -1) {
            list.splice(index, 1)
        } else {
            list.push(key)
        }
        if (kind === "genres") {
            activeTags = list
        } else if (kind === "languages") {
            activeLanguages = list
        } else {
            activeCountryCodes = list
        }
        // Several chips are often tapped in a row: search once afterwards
        searchTimer.restart()
    }

    // Clears one filter (the ✕ in its row) and searches right away
    function clearFilter(kind) {
        if (kind === "genres") {
            activeTags = []
        } else if (kind === "languages") {
            activeLanguages = []
        } else {
            activeCountryCodes = []
        }
        searchTimer.stop()
        performAdvancedSearch(searchPage.searchFieldText, activeTags, activeLanguages, activeCountryCodes)
    }

    function matchAll(kind) {
        return kind === "genres" ? tagMatchMode === "AND" : languageMatchMode === "AND"
    }

    function setMatchAll(kind, on) {
        if (kind === "genres") {
            tagMatchMode = on ? "AND" : "OR"
        } else {
            languageMatchMode = on ? "AND" : "OR"
        }
        if (activeList(kind).length > 1) {
            searchTimer.restart()
        }
    }

    function countryName(code, fallback) {
        var country = CountryData.findCountry(code)
        return country ? CountryData.getLocalizedName(country) : (fallback || code)
    }

    function itemsFromNames(names) {
        return names.map(function(n) { return { key: n, label: n } })
    }

    function suggestedItems(kind) {
        if (kind === "genres") {
            return itemsFromNames(recommendedTags || [])
        }
        if (kind === "languages") {
            return itemsFromNames(recommendedLanguages || [])
        }
        return (recommendedCountries || []).map(function(c) {
            return { key: c.iso_code, label: searchPage.countryName(c.iso_code, c.name) }
        })
    }

    function moreItems(kind) {
        var suggestedKeys = suggestedItems(kind).map(function(i) { return i.key })
        var items
        if (kind === "genres") {
            items = itemsFromNames(allTags)
        } else if (kind === "languages") {
            items = itemsFromNames(allLanguages)
        } else {
            items = CountryData.countries.map(function(c) {
                return { key: c.code, label: CountryData.getLocalizedName(c) }
            })
            items.sort(function(a, b) { return a.label.localeCompare(b.label) })
        }
        return items.filter(function(i) { return suggestedKeys.indexOf(i.key) === -1 })
    }

    // Selected entries that are in no list (e.g. typed earlier), plus the
    // typed filter text as a new genre/language if it matches no entry
    function extraItems(kind, filterText) {
        var known = suggestedItems(kind).concat(moreItems(kind)).map(function(i) { return i.key })
        var result = []
        var active = activeList(kind)
        for (var i = 0; i < active.length; i++) {
            if (known.indexOf(active[i]) === -1) {
                result.push({ key: active[i], label: kind === "countries" ? countryName(active[i]) : active[i] })
            }
        }
        if (kind !== "countries" && filterText.length >= 2
                && known.indexOf(filterText) === -1 && active.indexOf(filterText) === -1) {
            result.push({ key: filterText, label: filterText })
        }
        return result
    }

    // limit 0 = no limit
    function filterItems(items, text, limit) {
        var result = text.length === 0 ? items : items.filter(function(i) {
            return i.label.toLowerCase().indexOf(text) !== -1 || i.key.toLowerCase().indexOf(text) !== -1
        })
        return limit > 0 ? result.slice(0, limit) : result
    }

    // Shown next to the filter name: the selection, or "All"
    function filterValueText(kind) {
        var active = activeList(kind)
        if (active.length === 0) {
            return qsTr("All")
        }
        if (kind === "countries") {
            return active.map(function(code) { return searchPage.countryName(code) }).join(", ")
        }
        return active.join(", ")
    }

    // Loads the most used names of a radio-browser list ("tags" or
    // "languages"); results are cached like searches, failures never
    function loadNameList(endpoint, cacheKey, done) {
        var cached = appWindow.persistentState.getCachedResults(cacheKey)
        if (cached && cached.length > 0) {
            done(cached)
            return
        }
        RadioApi.requestJson(RadioApi.apiUrl(endpoint + "?order=stationcount&reverse=true&hidebroken=true&limit=120"),
                             appWindow.apiUserAgent, function(list) {
            if (!list) {
                done(null)
                return
            }
            var names = []
            for (var i = 0; i < list.length; i++) {
                var name = String(list[i].name || "").replace(/^\s+|\s+$/g, "").toLowerCase()
                if (name.length >= 2 && name.length <= 30 && name.indexOf(",") === -1 && names.indexOf(name) === -1) {
                    names.push(name)
                }
            }
            if (names.length > 0) {
                appWindow.persistentState.setCachedResults(cacheKey, names)
            } else {
                console.warn("[AdvancedSearch] No usable entries in the " + endpoint + " list")
            }
            done(names)
        })
    }

    function ensureAllTags() {
        if (allTags.length > 0 || _tagsLoading) return
        _tagsLoading = true
        loadNameList("tags", "advanced_search_all_tags_v1", function(names) {
            _tagsLoading = false
            if (names) allTags = names
        })
    }

    function ensureAllLanguages() {
        if (allLanguages.length > 0 || _languagesLoading) return
        _languagesLoading = true
        loadNameList("languages", "advanced_search_all_languages_v1", function(names) {
            _languagesLoading = false
            if (names) allLanguages = names
        })
    }

    function performAdvancedSearch(nameQuery, tagQueries, langQueries, countryCodeQueries) {
        var rawQuery = nameQuery ? nameQuery.trim().toLowerCase() : ""
        var tokens = rawQuery.length > 0 ? rawQuery.split(/\s+/).filter(function(t) { return t.length > 0 }) : []

        var longestToken = 0
        for (var lt = 0; lt < tokens.length; lt++) {
            if (tokens[lt].length > longestToken) {
                longestToken = tokens[lt].length
            }
        }
        if (longestToken < minSearchLength) {
            rawQuery = ""
            tokens = []
        }

        if (tokens.length === 0 && (!tagQueries || tagQueries.length === 0) && (!langQueries || langQueries.length === 0) && (!countryCodeQueries || countryCodeQueries.length === 0)) {
            searchRequestId++
            searchResultsModel.clear()
            busy.running = false
            searchDone = false
            searchFailed = false
            return
        }

        searchRequestId++
        var currentRequestId = searchRequestId

        busy.running = true

        // Keep the number of requests small: only ONE filter type goes to the
        // server (one request per selected value, OR), all other filters are
        // applied locally in processAndDisplayResults(). Before, every
        // combination of tag x language x country was requested separately,
        // which could add up to dozens of requests per search.
        // Countries are the most selective filter, then languages, then tags.
        var serverParam = ""
        var serverValues = [""]
        if (countryCodeQueries && countryCodeQueries.length > 0) {
            serverParam = "countrycode"
            serverValues = countryCodeQueries
        } else if (langQueries && langQueries.length > 0) {
            serverParam = "language"
            serverValues = langQueries
        } else if (tagQueries && tagQueries.length > 0) {
            if (tagMatchMode === "AND" && tagQueries.length > 1) {
                // All tags at once: the API supports AND via tagList
                serverParam = "tagList"
                serverValues = [tagQueries.join(",")]
            } else {
                serverParam = "tag"
                serverValues = tagQueries
            }
        }

        // Free text is searched in station names and tags
        var fields = rawQuery ? ["name", "tag"] : [""]

        var urls = []
        for (var v = 0; v < serverValues.length; v++) {
            var filterParam = serverParam
                    ? "&" + serverParam + "=" + encodeURIComponent(serverValues[v]) : ""
            for (var f = 0; f < fields.length; f++) {
                if (fields[f]) {
                    urls.push(apiBase + "search?" + fields[f] + "=" + encodeURIComponent(rawQuery)
                              + filterParam + "&limit=100&hidebroken=true")
                } else {
                    urls.push(apiBase + "search?order=clickcount&reverse=true"
                              + filterParam + "&limit=100&hidebroken=true")
                }
            }
        }

        var home = null
        if (weightByHome && tokens.length === 0 && tagQueries && tagQueries.length > 0
                && (!langQueries || langQueries.length === 0)
                && (!countryCodeQueries || countryCodeQueries.length === 0)) {
            home = CountryData.homeProfile(userCountry)
        }
        if (home) {
            var homeBase = apiBase + "search?order=clickcount&reverse=true"
            for (var ht = 0; ht < tagQueries.length; ht++) {
                var homeTag = "&tag=" + encodeURIComponent(tagQueries[ht])
                for (var hl = 0; hl < home.languages.length && hl < 3; hl++) {
                    urls.push(homeBase + homeTag + "&language=" + encodeURIComponent(home.languages[hl])
                              + "&limit=100&hidebroken=true")
                }
                urls.push(homeBase + homeTag + "&countrycode=" + encodeURIComponent(home.code)
                          + "&limit=50&hidebroken=true")
            }
        }

        if (urls.length === 0) {
            busy.running = false
            searchResultsModel.clear()
            searchDone = false
            searchFailed = false
            return
        }

        // Cache (10 minutes, see PersistentState) per set of requests: toggling
        // filters back and forth, OR/AND, sorting or bitrate then needs no
        // network at all - the local filters run again on the cached stations.
        var cacheKey = "advsearch:" + urls.slice().sort().join("|")
        var cached = appWindow.persistentState.getCachedResults(cacheKey)
        if (cached) {
            var cachedMap = {}
            for (var ci = 0; ci < cached.length; ci++) {
                cachedMap[cached[ci].url || cached[ci].stationuuid || cached[ci].name] = cached[ci]
            }
            busy.running = false
            searchDone = true
            searchFailed = false
            processAndDisplayResults(cachedMap, rawQuery, tokens, tagQueries, langQueries, countryCodeQueries, home)
            return
        }

        RadioApi.fetchAll(urls, appWindow.apiUserAgent,
            function() { return currentRequestId !== searchRequestId },
            function(merged, failed) {
                busy.running = false
                searchDone = true
                searchFailed = (failed === urls.length)
                if (!searchFailed) {
                    var list = []
                    for (var mk in merged) {
                        list.push(merged[mk])
                    }
                    appWindow.persistentState.setCachedResults(cacheKey, list)
                }
                processAndDisplayResults(merged, rawQuery, tokens, tagQueries, langQueries, countryCodeQueries, home)
            })
    }

    function processAndDisplayResults(mergedMap, rawQuery, tokens, activeTagFilters, activeLangFilters, activeCountryFilters, home) {
        var results = []

        for (var key in mergedMap) {
            var s = mergedMap[key]

            if (tokens.length > 0) {
                // Every search word must appear in name, tags, country or language
                var haystack = [s.name, s.tags, s.country, s.language].join(" ").toLowerCase()
                var matchesAllTokens = tokens.every(function(t) { return haystack.indexOf(t) !== -1 })
                if (!matchesAllTokens) continue
            }

            if (activeTagFilters && activeTagFilters.length > 0) {
                var stationTags = (s.tags || "").toLowerCase()
                if (tagMatchMode === "AND" && activeTagFilters.length > 1) {
                    var matchAllTags = true
                    for (var t = 0; t < activeTagFilters.length; t++) {
                        if (stationTags.indexOf(activeTagFilters[t].toLowerCase()) === -1) {
                            matchAllTags = false
                            break
                        }
                    }
                    if (!matchAllTags) continue
                } else {
                    var matchAnyTag = false
                    for (var tagIdx = 0; tagIdx < activeTagFilters.length; tagIdx++) {
                        if (stationTags.indexOf(activeTagFilters[tagIdx].toLowerCase()) !== -1) {
                            matchAnyTag = true
                            break
                        }
                    }
                    if (!matchAnyTag) continue
                }
            }

            if (activeLangFilters && activeLangFilters.length > 0) {
                var stationLangs = (s.language || "").toLowerCase()
                if (languageMatchMode === "AND" && activeLangFilters.length > 1) {
                    var matchAllLangs = true
                    for (var al = 0; al < activeLangFilters.length; al++) {
                        if (stationLangs.indexOf(activeLangFilters[al].toLowerCase()) === -1) {
                            matchAllLangs = false
                            break
                        }
                    }
                    if (!matchAllLangs) continue
                } else {
                    var matchAnyLang = false
                    for (var langIdx = 0; langIdx < activeLangFilters.length; langIdx++) {
                        if (stationLangs.indexOf(activeLangFilters[langIdx].toLowerCase()) !== -1) {
                            matchAnyLang = true
                            break
                        }
                    }
                    if (!matchAnyLang) continue
                }
            }

            if (activeCountryFilters && activeCountryFilters.length > 0) {
                var stationCountry = (s.countrycode || "").toUpperCase()
                if (countryMatchMode === "AND" && activeCountryFilters.length > 1) {
                    var matchAllCountries = false
                    for (var c = 0; c < activeCountryFilters.length; c++) {
                        if (stationCountry === activeCountryFilters[c].toUpperCase()) {
                            matchAllCountries = true
                            break
                        }
                    }
                    if (!matchAllCountries) continue
                } else {
                    var matchAnyCountry = false
                    for (var countryIdx = 0; countryIdx < activeCountryFilters.length; countryIdx++) {
                        if (stationCountry === activeCountryFilters[countryIdx].toUpperCase()) {
                            matchAnyCountry = true
                            break
                        }
                    }
                    if (!matchAnyCountry) continue
                }
            }

            if (minBitrate > 0 && (s.bitrate || 0) < minBitrate) {
                continue
            }

            results.push(s)
        }

        if (home && sortMode !== "alphabetical") {
            CountryData.sortByHome(results, home, ownCountryFactor, RadioApi.popularity)
        } else {
            results.sort(function(a, b) {
                if (sortMode === "alphabetical") {
                    var nameA = (a.name || "").toLowerCase()
                    var nameB = (b.name || "").toLowerCase()
                    if (nameA < nameB) return -1
                    if (nameA > nameB) return 1
                    return 0
                } else {
                    return RadioApi.popularity(b) - RadioApi.popularity(a)
                }
            })
        }
        // With a typed text: names starting with it first, then names
        // containing it, then the rest - each group in the chosen order
        // (popular / A-Z). Only filters: unchanged.
        results = RadioApi.groupByNameMatch(results, tokens.join(" "))

        searchResultsModel.clear()
        for (var j = 0; j < results.length && j < 100; j++) {
            searchResultsModel.append(results[j])
        }
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        // Ends above the collapsed PlayerBar (see appWindow.playerBarBaseHeight)
        anchors.bottomMargin: appWindow.playerBarBaseHeight

        currentIndex: -1

        header: Column {
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: qsTr("Advanced search")
            }

            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search stations")
                text: searchPage.initialSearchText
                EnterKey.iconSource: "image://theme/icon-m-search"
                EnterKey.onClicked: {
                    searchTimer.stop()
                    performAdvancedSearch(searchPage.searchFieldText, activeTags, activeLanguages, activeCountryCodes)
                    searchField.focus = false
                }
                onTextChanged: {
                    searchPage.searchFieldText = text
                    searchTimer.restart()
                }

                Connections {
                    target: searchPage
                    onSearchRequested: searchField.text = text
                }
            }

            // Active filters and reset
            Column {
                width: parent.width
                visible: searchPage.searchFieldText.length > 0 || activeTags.length > 0 || activeLanguages.length > 0 || activeCountryCodes.length > 0 || minBitrate > 0
                spacing: Theme.paddingSmall

                // "Active filters" with a clear button on the right - the same
                // clear symbol Silica uses in its search fields
                Item {
                    x: Theme.horizontalPageMargin
                    width: parent.width - (Theme.horizontalPageMargin * 2)
                    height: resetFiltersButton.height

                    Label {
                        text: qsTr("Active filters")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryHighlightColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    IconButton {
                        id: resetFiltersButton
                        anchors.right: parent.right
                        anchors.rightMargin: -Theme.paddingMedium
                        icon.source: "image://theme/icon-m-clear"
                        onClicked: {
                            searchTimer.stop()
                            searchField.text = ""
                            searchPage.searchFieldText = ""
                            activeTags = []
                            activeLanguages = []
                            activeCountryCodes = []
                            minBitrate = 0
                            sortMode = "popularity"
                            tagMatchMode = "OR"
                            languageMatchMode = "OR"
                            audioCombo.currentIndex = 0
                            sortCombo.currentIndex = 0
                            performAdvancedSearch("", [], [], [])
                        }
                    }
                }
            }

            // --- Filters ---
            // Each filter expands its selection right below it (chips that
            // wrap, no horizontal scrolling, no extra page); only one is open
            // at a time. Every tap searches right away (short delay).
            FilterSection {
                title: qsTr("Genres")
                value: searchPage.filterValueText("genres")
                expanded: searchPage.openFilter === "genres"
                flickable: listView
                clearable: activeTags.length > 0
                onClicked: searchPage.toggleFilter("genres")
                onClearClicked: searchPage.clearFilter("genres")
                contentComponent: Component {
                    AdvancedSearchFilter {
                        page: searchPage
                        kind: "genres"
                        moreTitle: qsTr("Popular genres")
                        matchAllText: qsTr("All genres must match")
                    }
                }
            }

            FilterSection {
                title: qsTr("Languages")
                value: searchPage.filterValueText("languages")
                expanded: searchPage.openFilter === "languages"
                flickable: listView
                clearable: activeLanguages.length > 0
                onClicked: searchPage.toggleFilter("languages")
                onClearClicked: searchPage.clearFilter("languages")
                contentComponent: Component {
                    AdvancedSearchFilter {
                        page: searchPage
                        kind: "languages"
                        moreTitle: qsTr("Popular languages")
                        matchAllText: qsTr("All languages must match")
                    }
                }
            }

            // A station has only one country, so there is no "all must match"
            FilterSection {
                title: qsTr("Countries")
                value: searchPage.filterValueText("countries")
                expanded: searchPage.openFilter === "countries"
                flickable: listView
                clearable: activeCountryCodes.length > 0
                onClicked: searchPage.toggleFilter("countries")
                onClearClicked: searchPage.clearFilter("countries")
                contentComponent: Component {
                    AdvancedSearchFilter {
                        page: searchPage
                        kind: "countries"
                        moreTitle: qsTr("Other countries")
                    }
                }
            }

            // ComboBox keeps its own currentIndex once the user picked an
            // entry, so "reset filters" sets it back explicitly
            ComboBox {
                id: audioCombo
                width: parent.width
                label: qsTr("Audio")
                currentIndex: 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("All") }
                    MenuItem { text: qsTr("128+ kbps") }
                }
                onCurrentIndexChanged: {
                    var bitrate = currentIndex === 1 ? 128 : 0
                    if (bitrate !== searchPage.minBitrate) {
                        searchPage.minBitrate = bitrate
                        performAdvancedSearch(searchPage.searchFieldText, activeTags, activeLanguages, activeCountryCodes)
                    }
                }
            }

            ComboBox {
                id: sortCombo
                width: parent.width
                label: qsTr("Sort")
                currentIndex: 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Popular") }
                    MenuItem { text: qsTr("A-Z") }
                }
                onCurrentIndexChanged: {
                    var mode = currentIndex === 1 ? "alphabetical" : "popularity"
                    if (mode !== searchPage.sortMode) {
                        searchPage.sortMode = mode
                        performAdvancedSearch(searchPage.searchFieldText, activeTags, activeLanguages, activeCountryCodes)
                    }
                }
            }

            SectionHeader {
                text: qsTr("Search results")
            }
        }

        model: searchResultsModel

        // The space for the PlayerBar is part of the footer instead of the
        // list's bottomMargin: with Qt 5.6, a ListView ignores bottomMargin
        // while its content is shorter than the view, so the last rows could
        // end up hidden behind the PlayerBar without the list being
        // scrollable (e.g. start page with station history expanded and
        // top stations collapsed). The footer always counts as content.
        //
        // Empty and error state below the filters
        footer: Column {
            width: listView.width

            Column {
                width: parent.width
                visible: searchPage.searchDone && !busy.running && searchResultsModel.count === 0
                height: visible ? implicitHeight : 0
                spacing: Theme.paddingMedium
                topPadding: Theme.paddingLarge
                bottomPadding: Theme.paddingLarge

                InfoLabel {
                    text: searchPage.searchFailed
                          ? qsTr("Could not reach the station database")
                          : qsTr("No stations found")
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    text: searchPage.searchFailed
                          ? qsTr("Check your internet connection and try again.")
                          : qsTr("Try fewer filters or a different search term.")
                }
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: searchPage.searchFailed
                    text: qsTr("Try again")
                    onClicked: performAdvancedSearch(searchPage.searchFieldText, activeTags, activeLanguages, activeCountryCodes)
                }
            }

            Item {
                width: parent.width
                height: appWindow.playerBarOverlap
            }
        }

        delegate: StationDelegate {
            width: listView.width
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        id: busy
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: false
    }


    ListModel { id: searchResultsModel }

    // --- One-time hint after the first search: the results are listed
    // below the filters, i.e. possibly off screen while filters are open.
    // Disappears on tap, after 8 s or when the page is left - and never
    // comes back.
    onSearchDoneChanged: {
        if (searchDone && status === PageStatus.Active && !appWindow.appSettings.searchResultsHintShown) {
            searchResultsHint.shown = true
            searchResultsHintHideTimer.restart()
        }
    }

    InteractionHintLabel {
        id: searchResultsHint
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.playerBarHeight
        width: parent.width
        z: 10
        text: qsTr("Search results appear at the bottom of the page")
        property bool shown: false
        opacity: shown && searchPage.status === PageStatus.Active ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { FadeAnimation { duration: 400 } }

        MouseArea {
            anchors.fill: parent
            onClicked: searchResultsHint.dismiss()
        }

        function dismiss() {
            if (shown) {
                shown = false
                searchResultsHintHideTimer.stop()
                appWindow.appSettings.searchResultsHintShown = true
            }
        }
    }

    Timer {
        id: searchResultsHintHideTimer
        interval: 8000
        onTriggered: searchResultsHint.dismiss()
    }

    Timer {
        id: searchTimer
        interval: 400
        onTriggered: {
            performAdvancedSearch(searchPage.searchFieldText, activeTags, activeLanguages, activeCountryCodes)
        }
    }
}
