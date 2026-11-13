# Sailwave – Roadmap

Open items and plans. Architecture and design decisions are in [`DESIGN.md`](DESIGN.md), tests in [`TEST-PROTOCOL.md`](TEST-PROTOCOL.md).

## Version 1.1 – released (October 2026)

- [x] **Package name `harbour-sailwave-radio`** with a transitional `harbour-sailwave` for OpenRepos users (see DESIGN 10b)
- [x] **Screenshot** `landscape-tiles.png` (tiles + player panel in landscape) for README, Jolla Store, OpenRepos
- [x] **Lock screen / car controls:** `Requires: qml(Amber.Mpris)`, next/previous also while paused
- [x] **Landscape:** support landscape on all pages (1.0 is portrait only; requested by users, e.g. for use in the car) – player panel on the right (see DESIGN 5a), tested
- [x] **Favorite tiles:** large favourite tiles as an extra ring page, setting off / always / only in landscape + open when turning (see DESIGN 5b), tested

## Version 1.1.1 – bugfix (November 2026, tested, ready to publish)

- [x] **Large system font:** rows, headings, the player bar and the favorite tiles grow with the font size (forum report: overlapping rows with a large font) – see DESIGN 10c
- [x] **Advanced search:** long filter values (genres, countries) start at the left and fade out instead of losing their beginning
- [x] **App icon:** more depth, no rim (see DESIGN 10)
- [x] **English plural forms:** new `translations/harbour-sailwave-radio-en.ts` ("1 favorite / 2 favorites"); the other languages already had them since 1.0

## Version 1.2 – built (build 127b), in device test

Not published yet. Package: `sailwave-complete_127b.zip` (10/11 Nov 2026). Tests: TEST-PROTOCOL sections 35–45.

### Built since 1.1.1 (all done, see DESIGN and CHANGELOG)

- [x] **Usability update** (blind test of 7 Nov, v116–v120): neighbour line, Settings start page, Backup and sync page, "Advanced ›" chip, playing station marked, hints, texts (details below)
- [x] **Code review fixes** (v122, REVIEW-121.md): pause is not undone by a reconnect, backup states are not overwritten, no "missing" marks after an empty answer, partial search results are not cached, safe backup writing and checked restore
- [x] **Pausing other players** over `Nemo.DBus` (v127, code of Sailcast 292). The earlier `MprisOthers.qml` (`MprisManager`) never loaded on the device, so this is the first time it really exists
- [x] **Header repair** on the ring pages (v125e: strict check after each activation; v125f: scroll formula via `headerItem.y`). Root cause not understood
- [x] **Backup and restore:** reasons shown, single backups deletable, manual backups limited to 10, track history inside saved backups, lost stations found by stream URL or name + country
- [x] **Sleep timer** as in Sailcast (5, 10, 20, 30, 45, 60 min) plus "…" for a manual time
- [x] **New group:** Accept active at once, then a picker for the stations (All/None, "now in X")
- [x] **Advanced search:** result bar with count ("100+"), also after a chip tap; filters hidden while typing; "Clear filters"; limits and language/country fixes
- [x] **Track history:** station menu (Play, Show station, Do not record / record again, Delete tracks of this station); text-only stations (SRF4) are not recorded
- [x] **Player bar:** swipe up/down to open and close
- [x] **Start page:** rows with a fixed role set (empty rows after the start), top-station tag weights computed once

### Open before the release

- [ ] **Built in 128: Nextcloud sign-in in the browser (Login Flow v2)** for WebDAV (`src/nextcloudlogin.*`, button in Settings → Backup and sync). Tests: section 46 (all passed on the device, 128c).
- [ ] **Built in 128d: start page header without a jump** (header grows after the start, `_topPinned`). Tests: section 47 (passed on the device).
- [ ] **Built in 128e: design alignment with Sailcast 293** (ActionPill instead of Button, Nextcloud wait state, MessageBanner, RingHint backing). Tests: section 48.
- [ ] **Built in 128h: station logos as tiles that work on every ambience and cover** (list, cover badge, lock screen). Tests: section 49.
- [ ] **Device tests still open:** 41.1–41.13 (history in the backup, lost stations).
- [x] **Harbour check (11 Nov, build 128d, all three architectures OK):** `Secrets` permission, `Sailfish.Share`, `Nemo.DBus` (spec has no `Requires` for it, as in Sailcast)
- [ ] **README screenshot** `screenshots/landscape-tiles.png` (from Thomas; the README links it, the file is missing)
- [x] **STORE.md, README, PRIVACY** brought up to the state of build 128d (11 Nov); the sentence about the headset key was removed (untested, Sailfish routes the key).
- [ ] **Final check:** version 1.2 in spec and `appVersion` (equal), translations de/es/fr complete, CHANGELOG and `%changelog` complete
- [ ] **Release:** upload to OpenRepos, then Thomas commits, tags and pushes; then submit to the Jolla Store (1.1.1 is already submitted there with its known errors)
- [ ] (optional, device) mini-player marquee start; second blind round with screenshots (broken favourite with "Find alternative", first start without favourites, running sleep timer, selected filter chip, bottom of Settings, backup dialog, info page with tags)
- [ ] **Watch:** header fault (root cause unknown; if it comes back: what was done just before, `journalctl -b | grep "Sailwave scroll"`); empty rows after the start (cause not confirmed, test 45); also check `FavoritesPage` and `TrackHistoryPage` for the same role pattern

### Postponed (after 1.2)

- [ ] **Headset key with two active players:** Sailfish routes the key to one "current" player (seen 11 Nov: key went to Sailcast while Sailwave was playing; Sailcast then paused Sailwave by its own rule). Same behaviour is possible with any MPRIS app; decide later whether Sailwave needs its own rule.

- [ ] Create the track history and advanced search pages only at the first swipe (about 210 ms less at start-up); only after the header fault stays away
- [ ] Rest of the performance list: large radio-browser responses (parsing up to ~100 ms on the UI thread: request fewer fields/rows), the extra scoring run triggered by `onOrderFrozenChanged`, measure start-up before/after (QML profiler, test 21.6)
- [ ] Advanced search: review the search logic from experience – how genre, language and country filters are combined, "All genres/languages must match", sorting (needs Thomas' experience)
- [ ] Corrections to radio-browser.info (station data such as homepage, logo): first find out why Shortwave removed this feature and how to confirm and check the data
- [ ] Start page: station history lists favourites too (a favourite can show up in its group and in the history) – decide after some use; the sections (groups, history, top stations) look alike
- [ ] Play stations directly on the favourites page (needs another way to show playback there)
- [ ] From the code review, on purpose not done: request timeouts (no timer in the JS library), warning for WebDAV over http and redirects, scrolling when a filter section collapses, the low-priority list in REVIEW-121.md

### Usability update 1.2 – details

- [x] **Usability update 1.2 (from the blind test of 7 Nov 2026, build 115)** – done in v116, to be tested on the device (TEST-PROTOCOL 35). Sources: usability audit, a blind reviewer, Gemini (two runs), Sailcast as a pattern library:
  1. [x] Neighbour line under the title of the four ring pages ("‹ Name" / "Name ›", tappable, as Sailcast)
  2. [x] Settings: short start page with four entries and live summaries (Playback, Discover, Backup and sync, Privacy), About + version at the bottom
  3. [x] Own "Backup and sync" page: "Back up now", "Back up and share …", "Restore …", last backup, WebDAV moved there
  4. [x] Advanced search: "Filters" chip (as "More options" in Sailcast; the funnel icon was tried in v116–v118 and dropped in v119: too big and bright); explaining text before the first search
  5. [x] Playing station marked in lists (accent colour + background band)
  6. [x] Manage favorites: visible "New group" entry; one-time hint "Press and hold a station for more options"
  7. [x] Texts: "Top stations for you", "plays" instead of "clicks"; landscape: previous/next 20 % larger
  - [x] Polish after the second review (7 Nov, v117, not built yet): quieter (i), tag filter, faint logo plate (variant 2; variant 3 = plate only for transparent logos, if it looks bad), station info like the Sailcast podcast page (tiles, vote button), Sailcast-like player bar buttons, About like Sailcast, landscape heading margin
  - [x] Advanced search active filters as chips + "Clear all"; start page "Last heard" row (v117)
  - [x] About: copyright once, richer text, "Thanks"; Settings: section headers and shorter texts (v118, not built)
  - [x] Track history headings left-aligned next to the logo (v118, not built); placeholders for missing covers rejected
  - [x] Filter field in the open filter named per kind ("Filter genres" ...; a merge with the station search is not possible: it narrows the chips, the top field searches stations); note under "Popular in this country"; message when a favourite is added (v118, not built)
  - Already existing, not changed: remaining sleep-timer time (SleepBadge; missing in the screenshots only because no timer was running), single track-history entries can be deleted, German translation exists
  - "Select" on Manage favorites stays "Select" (it is multi-select-delete, not move)
  - Later done: "Clear filters" (v126). Checked, nothing to do: the note under "Popular in this country" and the message naming where a favorite went exist already. Open: check of the mini-player marquee start (the cut title in the screenshot was the marquee mid-scroll)
  - **For a second blind round** (screenshots missing): broken favourite with "Find alternative", first start without favourites, running sleep timer, selected filter chip, bottom of Settings, backup dialog, info page with tags

## Later / ideas

- [ ] See "Postponed" above

## Known issues

- Headset buttons with two media apps (e.g. Sailcast) running: after a pause, the play button may start the other app – Sailfish OS decides which player gets the buttons. Keep watching.
- Headset "next" occasionally went to the previous favorite in a test (cover and lock screen were correct) – probably the earbud gesture (triple instead of double tap). Keep watching.

- Favourites page: dragging the bottom favourite occasionally fails the first time (not reliably reproducible).

## After 1.2
- [ ] Favourites keep the logo data (favicon/homepage) from the time they were saved; a dead favicon then stays (seen with ORF Radio Kärnten). When a favourite is played, update favicon/homepage from the fresh radio-browser.info data.
