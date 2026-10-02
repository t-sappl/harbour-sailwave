# Sailwave – Decisions, Conventions and Architecture

This document records **what** is deliberately solved the way it is in Sailwave and **why** – including what was tried and **rejected**. It complements the code (English comments) and `TODO.md`.

Status: preparing version 1.0. Goal: 1.0 feature-complete and polished, afterwards bug fixing only.

---

## 1. Way of working

- Thomas also edits files **himself**. Always start from the **most recently uploaded state**; if in doubt, ask for the current file instead of using an older copy.
- Changes are delivered as a **complete ZIP** in project structure (`qml/`, `qml/cover/`, `qml/pages/`, `src/`, `rpm/`, `translations/`, `.pro`, `.desktop`) plus a list of changed files with **line counts** for checking. The ZIP always contains `README.md`, `TODO.md`, `DECISIONS.md` and `TEST-PROTOCOL.md`.
- **Project documents are in English** (published on GitHub). Test feedback and to-dos given in German are translated into English when they are added.
- Nothing is rebuilt without being asked: for analysis questions, analyse and propose first, implement after approval.
- Testing on a real device (Sailfish OS 5.1, aarch64) via Qt Creator, deployed as **RPM**. Qt Creator logs are used for debugging.
- After new C++ headers/classes: "Clean" + qmake, otherwise stale Makefile entries remain.
- Translations (de/fr/es) are maintained by Claude directly in the `.ts` files whenever `qsTr` texts change.

## 2. Code conventions

- **Code and comments entirely in English** (the source code is published).
- **Log output:** only real problems, as `console.warn` (shows as `[W]`). No info logs.
- **Theme values instead of fixed pixels/colours.** Deliberate exceptions: opaque dark pill of the moon badge, white logo badges.
- **Prefer Silica components** (`PullDownMenu`, `RemorsePopup`/`remorseAction`, `ViewPlaceholder`, `TextSwitch`, `ComboBox`, `ValueButton`, `DetailItem`, `Separator`, `InfoLabel`).
- **Every delete action has a countdown** (remorse) – everywhere. **Important:** callbacks created inside a context menu run only after the countdown – by then the menu and its QML context are destroyed and names like `appWindow` or page ids are `undefined`. Therefore take all needed objects and values into **local variables beforehand** (error "Cannot read property … of undefined", found when deleting a group).
- **Messages:** only one banner type, `MessageBanner.qml`, via `appWindow.showMessage(text)`. (`VoteBanner.qml` was removed; vote feedback uses the banner too.)
- **Never cache failed network results.**
- Expired entries in `search_cache` are deleted at start-up (`pruneSearchCache`).
- No test/development data in the code (e.g. a "radio si" special case was removed).

## 3. Texts

- Source texts in `qsTr` in **English**, consistently **sentence case** ("Track history", "Station history", "Search results").
- **No colons** in labels ("Audio", "Sort") – like Silica components and Jolla apps.
- App name everywhere **"Sailwave"** (not "Sailwave Radio"). `harbour-sailwave.desktop`: `Name=Sailwave`.
- No unclear abbreviations: "Popular" (instead of "Prio"), "128+ kbps" (instead of ">=128").
- Numbers with plural forms: `%n` or `%Ln` (locale format, e.g. "1,234 votes").
- Translations: German, French, Spanish; terms:
  - Track history = Titelverlauf / Historique des morceaux / Historial de canciones
  - Station history = Senderverlauf / Historique des stations / Historial de emisoras
  - Sleep timer = Sleep-Timer / Minuteur de sommeil / Temporizador de apagado
  - Home country = Heimatland / Pays de résidence / País de residencia
  - No direct address of the user in translations (no "Sie"/"du").

## 4. Architecture

| Component | Purpose |
|---|---|
| `harbour-sailwave.qml` | App window, player, reconnect, ring navigation, home country detection, `openStationInfo()`, `showMessage()`, voting, current track display |
| `AppSettings.qml` | Settings (SQLite table `settings`), `ensureLoaded()`; empty/NULL values are skipped |
| `PersistentState.qml` | Histories, caches (10 min), homepage corrections (in-memory cache), votes, collapse states |
| `FavoritesStore.qml` | Favourites and favourite groups (SQLite), key = stream URL; reachability check |
| `FavoritesBackup.qml` | Favourites backup, backup states, restore, M3U export, WebDAV sync |
| `RadioApi.js` + `ServerPool.js` | radio-browser requests (`.pragma library`, `ServerPool` via `Qt.include`), server failover; iTunes genre → tag mapping |
| `TrackText.js` | How a track is shown (title / artist, iTunes spelling) – shared by track history, station info, PlayerBar |
| `StationLogo.js` | **shared** logo logic for `StationIcon` and `CoverArtCache` |
| `CoverArtCache.qml` | iTunes search, logo candidates, job for the C++ helper |
| `src/artcomposer.*` | C++: composes the MPRIS image with QPainter (also works in the background) |
| `src/networkaccess.h` | Workaround for the Qt 5.6 bearer problem ("Network access is disabled" after flight mode); disk cache for images (`ImageCachingManager`) |
| `src/filehelper.h` | C++ file access for QML (`fileHelper`): backup, M3U |
| `src/webdavclient.*` | C++ WebDAV requests for QML (`webDav`) |
| `SleepTimer.qml`, `SleepBadge.qml` | Sleep timer logic and moon badge |
| `MessageBanner.qml` | the only message overlay |

## 5. Navigation

- **Ring navigation:** Top stations → Track history → Advanced search → Top stations, **both directions** by swiping. Implemented with `pushAttached` and rebuilding the stack (`[left neighbour][current page](right neighbour)`). **No `SlideshowView`.**
- The three ring pages are fixed instances (`ringMember: true`) so that state/scroll position are kept. No `initialPage` (Silica warns about an object instance); the start page is pushed in `Component.onCompleted` with `push(…, Immediate)`.
- Sub-pages (station info, settings, …) lie **on top of** the ring page; swiping back first unwinds that stack.
- **No copies of ring pages** from the pulley menu or the PlayerBar (removed because they behave differently). Only exception: "Open track history" (station info, PlayerBar) opens a **copy** of the track history page as a normal sub-page (`targetStationKey`: scrolls to the station and expands it; no ring swiping), so swiping back returns to where it came from.
- **"Similar stations" replace the station info page** (`openStationInfo(st, true)` → `pageStack.replace`), like the Maps app – no ever deeper stack.
- **Station info never twice** for the same station: `appWindow.openStationInfo()` – if it already shows this station nothing happens; if it is deeper in the stack, it jumps back there.
- Start page pulley menu: "Settings", "Manage favorites" (if there are favourites) and "Try again" on errors. "Station info" removed (duplicate – station info via the station name in the PlayerBar); instead a one-time hint above the PlayerBar ("Tap the station name for station info", `InteractionHintLabel`, flag `playerBarHintShown`; disappears on tap, after 8 s or when station info is opened).
- The glowing line at the top of pages with a pulley menu is the **Silica pulley menu indicator**, not a bug.
- A ring indicator (3-part bar) was tried and removed.

## 6. PlayerBar

- **Only one, global PlayerBar** (in `harbour-sailwave.qml`). Pages set their bottom spacing from `appWindow.playerBarHeight`. In ListViews this spacing is part of the **footer** (empty item), **not** `bottomMargin`: Qt 5.6 ignores `bottomMargin` while the content is shorter than the view – the last rows were then hidden under the PlayerBar without being scrollable.
- The bar takes all touches no element inside handles (its own `MouseArea` at the very bottom) – otherwise the page behind it scrolled when there was little content.
- Hidden on settings, about page, country picker, homepage dialog, favourites page, group name dialog, restore pages, sync conflict page and Sailfish pickers – by **name comparison** (`objectName`; pickers via `selectedContentProperties`), deliberately no "more robust" solution.
- **Cover field:** album cover fills the field, station logo as a light rounded badge bottom right. If the cover disappears, **the logo grows animated from the bottom right corner** (one shared animation value, logo is scaled, not reloaded).
- No alternating/cross-fading between logo and cover (rejected).
- **Sleep timer:** moon button **only in the expanded PlayerBar** (collapsed, the song title needs the space). Opens a row above the bar with 5, 10, 15, 30, 45, 60, 90 minutes and ✕ to stop. The last chosen duration is remembered. At the end playback is **paused**, not stopped; volume is restored. "Fade out" stays in the settings.
- Sleep timer is **not** in the pulley menu (was there, was moved).
- **Expanded: only "Track history":** titles of the current station, **3 visible, more scrollable within the area** (up to 30 loaded), below it fixed (does not scroll along) "Open track history" – quiet: small icon, same font size as the titles (was too dominant before). Shared component `TrackPreview.qml`, identical on the station info page. Station history removed from the PlayerBar (it is on the start page). The bar's height follows its content.
- **Background (C2, decided):** adaptive colour from the ambience (`adaptiveBarColor`): hue of the highlight colour, saturation ≤ 45 %, fixed lightness 17 % (dark) / 88 % (light), then contrast to highlight-coloured icons ≥ 3:1 (lightness shifted further if needed). Opaque, because the bar lies on top of scrolling lists. Tested with several ambiences on the device. **Rejected:** fixed base tones #121212/#F0F0F0 + 35 % accent (calculated problem cases with very dark/pale/saturated accents); `Theme.highlightDimmerColor` (formula undocumented, not controllable); semi-transparent like the Jolla media player (list shines through). Limit: Silica does not provide the brightness of the wallpaper.

## 7. Cover, MPRIS, album covers

- **Same image** everywhere (PlayerBar, app cover, lock screen): album cover with station logo badge bottom right, otherwise just the logo.
- App cover: moon badge with remaining time top left while the sleep timer runs.
- App cover without album cover: logo badge fixed at `Theme.iconSizeLarge` (not bound to `stationIcon.width` – that was a binding loop on `iconSize`).
- Cover actions: play/pause and "next favourite". The second action only appears if it would change the station (two `CoverActionList`s, one active). "Next favourite" stays **within the group** of the playing station; without a group, alone in its group or not a favourite: through all favourites (order as on the start page).
- **MPRIS image** is created by the C++ helper `ArtComposer` (QML `grabToImage()` did not work in the background, Canvas crashed). Until the PNG matches, MPRIS gets the image URL directly (`cachedArtFresh` / `directArtUrl`).
- Errors of the C++ helper when loading logos do **not** mark logos as broken for the app (C++ may not read `.ico`, QML can).
- The lock screen only shows MPRIS images; there is no ring/cover display there.
- **iTunes search:** only for "Artist - Title", 1.5 s delay, rough artist matching, 600×600. Results in a session cache and permanently in the track history (`art_url`, `album_name`, `genre`, `itunes_artist`, `itunes_title`) – repeated songs do not query iTunes again. Can be switched off in the settings ("Song details from iTunes").
- **iTunes spelling of the current track** (`currentTrackDisplay`): PlayerBar, app cover and lock screen (MPRIS) show it as soon as there is a reliable match; the stream text remains the basis.

## 8. Station logos

- Sources (shared in `StationLogo.js`): 1. favicon from radio-browser, 2. Google favicon of the homepage (**corrected homepage takes precedence**).
- Broken favicon URLs are remembered per session (`brokenIconUrls`), then a letter avatar.
- Letter avatar only when there is no logo (no URL or load error) – **not while loading**; the area stays empty until then. Otherwise the avatar flashes briefly, e.g. on the station info page (larger logo = separate image cache entry, loaded again).
- **Rejected:** small favicons on light tinted tiles – "it looked nicer before".
- **Rejected:** blur filter on all icons.

## 9. Pages in detail

**Start page (top stations)**
- Sections: favourites (possibly in groups), station history, top stations; or search results.
- **Every favourite belongs to exactly one group (or none) – deliberately 1:1.** Rejected: a favourite in several groups (mapping table, move vs. copy, "remove from group" vs. "delete", unclear cover action – too much complexity for users).
- **Favourite groups (I1):** table `favorite_groups` (id, name, sort_order), `favorites.group_id` (NULL = no group). Without groups: one section "Favorites" as before. With groups: one collapsible section per group (state `favGroup_<id>`), favourites without a group last under "Other favorites" (same name on the favourites page); empty groups only on the favourites page (and as drop targets while sorting).
- **Sorting favourites on the start page:** context menu "Move" (long press is the context menu in Silica lists, so no "long press and drag"; no ready-made Silica component for reordering) → all favourites get a handle, heart/info buttons hidden, all groups expanded, empty groups visible as targets. Moving **across groups** like on the favourites page (consistent, otherwise not understandable for users). Dragging only at the handle (the list stays scrollable); while dragging the list scrolls by itself at the top edge or just above the PlayerBar. "Done" as a text action (no button – does not fit the page design) on the right between the search row and the first favourite group; it pushes the list down by its height on purpose (visible feedback for the mode). **Ending also by tapping** a header, a favourite row outside the handle or any other row (known from other apps). When starting and ending, the **topmost visible row stays in place** (or its group header if the group collapses again; if the page header is visible, the page stays at the top) – otherwise the list jumped because header and groups change. The list is never left locked (`interactive` is reset on every mode change). Order in column `sort_order` (migration: existing ones numbered alphabetically, new ones at the end); the cover action follows the order.
- **Favourites page (I2, `FavoritesPage.qml`):** pure editing page (tap does not play, PlayerBar hidden). Groups: new (pulley, `GroupNameDialog.qml`), rename, move up/down, delete – **both**: "Delete group" (favourites → "Other favorites") and "Delete group and favorites", each with countdown. Favourites: handle on the right for dragging, also **between groups** (group = header above), the list scrolls along at the edge; only at the handle so the list stays scrollable otherwise; generous space below the list so the last handle is not at the screen edge (system gesture). Selection mode: mark favourites and groups, delete together (countdown); marked groups are deleted without their favourites unless those are marked too. Reachability + "Find alternative" as on the start page. Pulley: sync now (WebDAV), restore, back up, export as M3U, new group, select.
- **Reachability of favourites:** one request `stations/byuuid` for all (4 s after start, after adding, every 6 h; a failure keeps the old result). Broken favourites show "Not reachable at the moment" / "No longer listed at radio-browser.info" in the second line + context menu "Find alternative".
- **Station history shows no favourites** and at most 5 stations; if empty, the section is missing – **deliberately left like this**.
- Collapsing/expanding without rebuild: only the rows of the affected section are removed from or inserted into the list model (`toggleSection`), animated via the ListView's `add`/`remove`/`displaced` transitions (only active while toggling). **Rejected:** collapsed rows with height 0 in the model – that broke the ListView's content height (no longer scrollable to the end). Collapsed sections therefore also load no logos. Loading more top stations only appends (not while collapsed).
- Error state with "Try again" below the list and in the pulley menu.
- **Loading top stations:** triggers (favourites, station history, current station, home country) are bundled by a 500 ms timer. The loaded stations (up to ~900) stay in memory as a **station pool** and are only re-scored locally on changes. Network only if the pool is older than 10 min, the requests change (top country/language/tag of the profile) or on "Try again". Big busy indicator only while nothing is shown yet.
- **Snapshot** of the first 100 top stations in `app_state` (`top_stations`), up to 24 h old, shown immediately at start-up; written only after a real network load. "Clear cache" deletes it as well.

**Track history**
- Station logo in the header row **small** (`iconSizeSmall`) so blurry favicons do not stand out; structure via indentation.
- Track rows: cover in the same small size; **without a cover the area stays empty** (no icon), titles stay aligned.
- **Two lines** instead of truncation: song title on top (max. 2 lines), below "Artist · Genre · Time" (`TrackText.js`, also on station info and PlayerBar). No marquee.
- **iTunes spelling:** `artistName`/`trackName` are only stored (columns `itunes_artist`, `itunes_title`) if artist AND title match the stream text ignoring case, punctuation and bracket additions – iTunes only corrects the spelling; otherwise the stream text stays. `previewUrl`/`trackViewUrl` deliberately not used (browser = media break, no iTunes app on Sailfish).
- **Search:** search field at the top of the list (title, artist, genre, station); matching stations expanded, collapsing only applies to this search; also no rebuild on playing while a search is active. ListView with `currentIndex: -1` (otherwise the search field loses focus with every letter – same fix as in the advanced search) plus a safety net: focus is given back after a rebuild.
- List thumbnails in 200×200 (iTunes URL rewritten), stored stays 600×600.
- Rebuild only while the page is visible; otherwise only marked as outdated (same principle in the PlayerBar preview: only expanded and app in the foreground). The PlayerBar marquee pauses in the background.
- Pulley menu hidden when the history is empty.
- **`SilicaListView`**, not `Column` + `Repeater` (the Repeater created all ~200 rows at once: 466–507 ms at start-up and when swiping, measured with the QML profiler). Collapsing as on the start page: collapsed stations have no rows in the model, `toggleStation` inserts/removes (transitions only meanwhile). Covers load only for visible rows.
- **Deleting an entry** removes only that row (and the station header if it was the last entry) – no rebuild, the scroll position stays. The page's own `trackHistoryUpdated()` is ignored there (`_ownUpdate`); other places (PlayerBar, station info, ring instance) update.
- Jump from station info scrolls via `positionViewAtIndex`.
- **No rebuild while the page is visible:** `applyHistoryChanges` compares the stored with the shown history (station name + timestamp) and changes only affected rows – new title at the top of its group, new station as a group at the very top (expanded), cover via `setProperty`, dropped entries removed. The order of the groups stays; it is re-sorted the next time the page is opened. Reason: when playing from the history, the list jumped to the top and the group moved away.

**Station info**
- Header: logo, below it **Play centred, favourite heart on the right** (invisible placeholder on the left).
- **Similar stations:**
  - first 3 tags; per tag up to 4 requests (worldwide, station's country, station's language, home country if different), `tagExact`, by popularity, 40 each
  - points: shared tag 3, same country 4, same language 4, home country 2, popularity `log10(clicks+1) × 0.3`
  - duplicates merged via normalised name, own station excluded, top 10
  - 10-minute cache per request set
  - rows = `StationDelegate` (**tap plays**, ⓘ opens info, heart for favourites)
- **Stations without tags – first genres from the track history:** the iTunes genre (`primaryGenreName`) of each found song is stored in the track history (column `genre`; query with `lang=en_us`, according to Apple's docs the default and only `en_us`/`ja_jp`, so names are English in every store). Without tags, the genres of the station's last 50 titles are counted (each title once); up to two genres with at least 2 titles and a 30 % share, with at least 3 titles with a genre in total. Mapping to radio-browser tags in `RadioApi.tagForItunesGenre` (table, otherwise the lowercase name). Then the normal flow with the heading "Similar stations" (real musical similarity). Only with "Song details from iTunes" switched on, and only for new titles.
- **Stations without tags and without enough genres:** instead the most popular stations of the station's country (clicks; with a known language an additional request in that language, whose stations come first), own heading **"Popular in this country"** – deliberately without the country name (CountryData only has English/German) and without claiming similarity. Without country and tags: no section.
- Order: station tags → genres from the history → "Popular in this country" → no section.
- Similar stations are loaded only when the page has finished sliding in (`status === Active`) – otherwise stutter when opening (profiler).
- Loading details: small `BusyIndicator` on the left of the header (not in the layout – otherwise the page jumps after loading). Load errors as a banner (`showMessage`), the data from the list stays.
- Station properties as `DetailItem`s. **"Last server check" removed.**
- **Votes · clicks + heart for voting in one row**, below it "Last voted on …".
- **Voting:** radio-browser allows 1 vote per station and IP every 10 min; Sailwave rule: **1 vote per station and day** (`voteIntervalMs`). Heart filled and locked immediately while the request runs (a second tap used to run into the API limit); filled for 24 h after the vote, a tap shows "possible again tomorrow". **Time limit 10 s:** without an answer (offline) the vote counts as failed – heart empty again, message "Vote not possible, no connection"; a late answer is ignored.
- **Automatic vote when saving a favourite** (setting, default on): `FavoritesStore.favoriteAdded` → `voteForStation(uuid, silent)`, without banner, same daily rule. Restoring backups never votes.
- **Reachability:** `lastcheckok` from the detail request; empty answer = no longer listed. Then a "Status" row in the properties + "Find alternative" in the pulley menu (opens the advanced search with the name, filters reset).
- **Homepage editing stays** (do not remove!). Homepage as a Sailfish link (accent colour, `fontSizeSmall`, without `https://`), corrected homepage in italics. Editing via `HomepageDialog.qml` (accept/cancel by gesture; "Reset" in the pulley only resets the field to the radio-browser homepage, saving happens on accept; empty or equal to the original homepage = correction removed). Small pencil, touch area `itemSizeSmall`. PlayerBar hidden in the dialog.
- "Track history" and "Similar stations" with **own** collapsible headers, independent, default **expanded**. State **global** (same for all stations) via `getCollapseState`/`setCollapseState` (`stationInfoHistoryCollapsed`, `stationInfoSimilarCollapsed`). The earlier per-station storage never worked (`getSectionCollapsed`/`setSectionCollapsed` did not exist) and would have accumulated an entry per visited station.
- Track history preview: `TrackPreview.qml` as in the PlayerBar (3 visible, scrollable, "Open track history" fixed below). Preview rows styled like the track history page (title `primaryColor` + `fontSizeSmall`, details `secondaryColor` + `fontSizeExtraSmall`). **Rejected:** preview in highlight colours – looked like the section heading and did not stand out.

**Advanced search**
- Free text only in name + tags (no URL search); local matching in name, tags, country, language.
- Only **one filter type** is sent to the server (countries, else languages, else tags; AND tags via `tagList`), the rest is filtered locally. 10-minute cache.
- "Reset filters" as ✕ symbol (no link text, no pulley, no big button).
- No hard-coded countries; home country centrally via `appWindow.resolveUserCountry()`.
- Page title "Advanced search".
- **Filters (C1):** "Genres", "Languages", "Countries" as collapsible rows (`FilterSection.qml`: name left, selection right like a `ValueButton`, arrow like the other sections). Expanded **on the same page** (`AdvancedSearchFilter.qml`): filter field, "Suggested" (previous suggestions) and "Popular genres" / "Popular languages" / "Other countries" as wrapping chips (`FilterChip.qml`, touch area `itemSizeSmall`), for genres/languages the switch "All … must match". Only one filter open at a time; content is created only when expanded.
  - **Calm expanding/collapsing:** the filters lie in the ListView `header`, which grows **upwards** (it is attached to the first list item). Every height change of a section (expanding/collapsing, filtering the chips) is therefore compensated by moving the view by the same amount while the section's lower edge is visible (`FilterSection`). The tapped row and the filter field stay in place, only the content below moves. **Rejected:** automatically scrolling to the section after expanding (`ensureVisible`) – only fought the symptom and caused restlessness.
  - **Clear individually:** if a filter has a selection, its row shows a ✕ (`icon-m-clear`, touch area `itemSizeSmall`) between selection and arrow; it clears only this filter and searches immediately, without expanding/collapsing. The ✕ at "Active filters" still resets everything.
  - Every tap searches immediately (via the 400 ms search timer, so several taps in a row lead to one search).
  - "Popular genres/languages": the most used tags/languages of radio-browser (`tags`/`languages`, 120 items, 10-min cache), loaded the first time the page is shown (not only on expanding); "Other countries": all countries from `CountryData.js` (sorted by name, hence not "Popular"). Without filter text at most 40 chips, with filter text 60.
  - Typed filter text that matches no entry appears as its own chip (new genre/language).
  - Countries without AND (a station has only one country; the old AND mode acted like OR anyway).
  - "Audio" and "Sort" as `ComboBox`; "Search results" as `SectionHeader`. "Reset filters" (✕) also resets the combo boxes and the AND switches.
  - **Rejected:** horizontally scrolling chip rows (conflict with ring swiping, too little visible, too small touch areas); separate selection page / dialog (two more taps); `DockedPanel` (covers results, conflicts with PlayerBar and keyboard); quick-pick row above the filters (made redundant by expanding).

**Settings**
- Sections: Playback (autoplay at start – default off, fade out), Discover (home country with country picker page, automatic vote when saving a favourite), Favorites (save: only on the device / device and WebDAV, WebDAV fields with connection test), Privacy ("Song details from iTunes", save track history + length 50/100/200, clear buttons with countdown).
- "About Sailwave" as its own page, entry at the bottom of the settings. Fields `licenseName`, `sourceCodeUrl`, `privacyPolicyUrl` in `AboutPage.qml`.

**Collapsible sections in general**
- **Own solution everywhere.** Silica `ExpandingSection` is undocumented API (allowed according to Jolla, but rarely used; with `ExpandingSectionGroup` only one section open at a time). Does not fit the start page ListView, the logo in the track history headers or the fixed height of the PlayerBar. On station info it would be possible; the first attempt failed not because of the component but because of an error loading the section states.

**Favourites backup / restore / sync (I3–I5)** – `FavoritesBackup.qml`, C++ `fileHelper` (files) and `webDav` (WebDAV requests)
- `Documents/Sailwave/sailwave-favorites.json`, **fixed name**, updated 2 s after every change (sharing, restoring, WebDAV file). Format `sailwave-favorites` v1 with `savedAt`, groups (name, order), favourites (group by **name**).
- **5 automatic backup states** in the app data folder (`backups/favorites-<date>-<time>.json`), at most one per hour (time from the file name), additionally always before restoring and before "Delete group and favorites".
- **Restoring – two modes** (confirmation dialog, choice): **"Replace current favorites"** (default – favourites and groups exactly as in the backup, which is what one expects from "restore") or **"Add missing favorites only"** (nothing deleted/regrouped). The dialog shows the changes beforehand (added / removed / changed group / groups added / removed). The current state is always saved before restoring. No automatic voting. The WebDAV conflict "Merge both" still uses adding.
- Restore page: automatic states + Sailfish file picker (`FilePickerPage` from `Sailfish.Pickers`, allowed in the Jolla Store; filter `*.json`; start folder cannot be set) → confirmation dialog. Own file chooser page rejected – official Sailfish component preferred.
- **M3U:** `Documents/Sailwave/sailwave-favorites.m3u`, `#EXTINF:-1 tvg-logo="…" group-title="…",Name`, overwritten. Validated externally with VLC and ffmpeg.
- **WebDAV:** the same file in `<URL>/Sailwave/`. ETag remembered after every sync; before uploading a HEAD request – different ETag (or first sync with an existing file) = conflict → `SyncConflictPage`: "Merge both" (recommended) or "Keep this device's". Failed upload → `webdavPending`, retried at the next change, at start-up or with "Sync now". Requests in C++ because QML XHR in Qt 5.6 does not reliably support all WebDAV methods. Password currently in the app database (TODO: Sailfish Secrets).
- Sailjail: needs `Documents` (writing) and `UserDirs` (file picker outside Documents).

## 10. Network and data

- **Home country:** settings > IP (ipapi.co with user agent, fallback api.country.is) > system language; 6 s time limit.
- **API URLs** always via `RadioApi.apiUrl(path)` with the neutral host `server.api.radio-browser.info`; the real server is inserted per attempt, the URL (and thus cache keys) stays stable.
- **radio-browser:** server list from `all.api.radio-browser.info`, failover only for radio-browser URLs on 0/403/429/5xx; rotates only if the failed server is still the active one.
- **Qt 5.6 workaround** (`networkaccess.h`): network managers stay "accessible", otherwise the app hangs after flight mode.
- **Disk cache for images** (`networkaccess.h`, `QNetworkDiskCache`): the network manager of the QML image loader (own thread) gets a cache in `~/.cache/…/images/qml` (40 MB), `ArtComposer` its own in `images/composer` (20 MB) – never two caches in the same directory. GET requests with `PreferCache`: cached images come from the cache without asking the server (also after a restart and offline); logos/covers practically never change. The main thread's manager (XMLHttpRequest: radio-browser, iTunes search) gets **no** cache – API answers have their own 10-minute cache.
- **"Clear cache"** in the settings clears the search cache, the top station snapshot **and** both image caches (`imageCache.clear()`, context property from C++; `clear()` runs in each cache's thread). Images already shown stay in memory until a restart.
- The privacy policy must mention: iTunes (song titles to Apple), ipapi.co + api.country.is (country by IP), radio-browser.info (clicks, votes), WebDAV server (if configured).

## 11. App icon

- Sailfish "droplet": three rounded corners, **pointed corner bottom left**; Jolla dimensions (shape fills the area except 0.3 px per side at 86 px).
- Motif as in the accepted design: boat with main sail and jib, three yellow radio waves from the masthead to the top right, waterline starting at the pointed corner; motif scaled to 87 %.
- **Rejected:** radio waves concentric to the frame curve / bigger motif; pointed corner top right (first chosen, then changed in favour of bottom left).
- PNGs in `icons/86x86` … `icons/172x172`, template `design/harbour-sailwave.svg` (not in `icons/`).

## 11a. Sailjail (sandbox)

- `harbour-sailwave.desktop` with `[X-Sailjail]`: `OrganizationName=harbour-sailwave`, `ApplicationName=harbour-sailwave`, `Permissions=Internet;Audio;Documents;UserDirs`.
- **Organisation and application name deliberately = the previous package name** (like gPodder): the data already lived in `~/.local/share/harbour-sailwave/harbour-sailwave` and `~/.cache/harbour-sailwave/harbour-sailwave`; Sailjail provides exactly `<Org>/<App>` → no data migration needed. **Rejected:** reverse domain name (would create new folders, existing data would be gone).
- `Documents` for backup and M3U, `UserDirs` for the file picker outside Documents. MPRIS/lock screen checked under the sandbox: covered by `Audio`, no own permission needed. Data was fully kept when switching.
- Testing under the sandbox: starting from Qt Creator bypasses Sailjail → start from the app grid (or `sailjail -p harbour-sailwave.desktop /usr/bin/harbour-sailwave` for log output). A changed `.desktop` only takes effect after deploying and rebooting the phone.

## 12. Publishing

- Source code public (repository), licence GPLv3 (SPDX notation recommended).
- Channels: **Chum preferred** (builds from the repository), plus OpenRepos, possibly the Jolla Store (Harbour check, check `Recommends: qml(Amber.Mpris)`).
- **Transparency:** README/store description state that the app was developed with AI assistance (Claude), but reviewed, tested on devices and maintained by the author. Include screenshots, emphasise the few permissions.
- Always raise the version in `.spec` and `appVersion` (`harbour-sailwave.qml`) together.
