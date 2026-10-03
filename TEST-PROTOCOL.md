# Sailwave – Test protocol

Manual tests of Sailwave 1.0 on a real device during development. The sections are in chronological order, each one belongs to a development step:

- **vNN** (e.g. v52, v73) is an internal development iteration, not a released version – the first public release is 1.0.
- **Short codes** such as C2, H5, I3 or K3 are internal planning items of that time; what was decided is described in [`DESIGN.md`](DESIGN.md).
- Earlier results are kept as history in the "Note" column ("was: …", "retest vNN: …"), so a test that failed once and was fixed later can be traced.

Status: 1.0 (development iteration v94) – all functional tests passed (up to section 28); release checks done: packages built for all three architectures, Harbour check passed, memory and QML profiler checked.
Tested on: Sailfish OS 5.1, aarch64 (Jolla Phone 2026) · Last test round: 3 October 2026

Legend: `[ ]` open · `[x]` OK · `[!]` failed (note + log excerpt in the "Note" column) · `[?]` unclear / keep watching

> **Before testing a new build:**
> 1. In Qt Creator "Clean" + qmake (new C++ and QML files).
> 2. Check the Sailjail permissions in `harbour-sailwave.desktop` (see section 0). A changed `.desktop` only takes effect after deploying + rebooting the phone.
> 3. Start with the **existing data** (do not reinstall) – this also tests the database migration.
> 4. Start from the app grid for sandbox tests (Qt Creator bypasses Sailjail). Keep the log open; note every `[W]` line with `qml/…`.

---

## 0. Preparation / permissions

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 0.1 | First start with `[X-Sailjail]` (v42) | Sailfish asks for the permissions (Internet, Audio, Documents, user folders) | [x] | Prompt appears (after deploying the new .desktop + reboot) |
| 0.1a | Data after starting under the sandbox | Favourites, groups, histories, settings as before | [x] | everything there |
| 0.1b | Lock screen under the sandbox | Station/title and image appear, play/pause works | [x] | MPRIS OK; `Audio.permission` contains the MPRIS rule |
| 0.1c | Backup / file picker under the sandbox | File in Documents/Sailwave; picker shows Documents and Downloads | [x] | folders visible, backup JSON selectable |
| 0.2 | Start with existing data | No crash; start page, favourites, history as before | [x] | OK – retested after every iteration |
| 0.3 | Log at start-up | No `[W]` lines about `FavoritesStore`, `PersistentState`, `FavoritesBackup`, `TopStationsPage` | [x] | OK – retested after every iteration |

## 1. Older open items

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 1.1 | App start (top station snapshot, v23) | Start page filled immediately, no big busy indicator | [x] | OK by observation |
| 1.2 | Advanced search: type an unknown genre into the filter field | Appears as its own chip, selectable | [x] | works |
| 1.3 | Advanced search: "All genres/languages must match" | Results change accordingly | [x] | OK – possible changes to the search logic in 1.1 (see TODO) |
| 1.4 | Similar stations from the track history (v27): music station without tags, listen to 3–4 songs with covers, then station info | "Similar stations" instead of "Popular in this country" | [x] | works (Radio Uno Kärnten), keep watching |
| 1.5 | Optional: QML profiler, sequence start → play → station info → swipe to track history | Track history build clearly below the former 466–507 ms | [x] | see 21.6 (profiler measurement before the release) |

## 2. PlayerBar background (C2, v40)

Three variants in `PlayerBar.qml` (top of the Rectangle): **adaptive** (active), `highlightDimmerColor` and the previous fixed formula (both commented out).

| # | Test | adaptive | dimmer | previous | Note |
|---|---|---|---|---|---|
| 2.1 | Dark ambience with a bright wallpaper | [x] | — | — | OK (several ambiences); retest v81: OK (variants "dimmer"/"previous" removed – not applicable) |
| 2.2 | Ambience with a very dark accent colour | [x] | — | — | OK (several ambiences); retest v81: OK (variants "dimmer"/"previous" removed – not applicable) |
| 2.3 | Light ambience with a strong accent colour (heart, moon, arrow readable?) | [x] | — | — | OK (several ambiences); retest v81: OK (variants "dimmer"/"previous" removed – not applicable) |
| 2.4 | Light ambience with a pale accent colour (bar still distinguishable?) | [x] | — | — | OK (several ambiences); retest v81: OK (variants "dimmer"/"previous" removed – not applicable) |
| 2.5 | Ambience with a very saturated accent colour (garish?) | [x] | — | — | OK (several ambiences); retest v81: OK (variants "dimmer"/"previous" removed – not applicable) |
| 2.6 | Change ambience while the app runs | Colour adapts immediately | — | — | changes immediately ✓; retest v81: still works |
| 2.7 | Decision | | | | **Adaptive** |

## 3. Block H (v35)

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 3.1 | H1: start page pulley | Only "Settings", "Manage favorites" (with favourites), "Try again" on errors | [x] | OK |
| 3.2 | H1: hint above the PlayerBar | Appears shortly after start, disappears on tap/after 8 s, does not return after a restart | [x] | OK |
| 3.3 | H2: heart on station info | Filled immediately, then "Vote counted"; second tap: "possible again tomorrow" | [x] | retest OK (time limit) |
| 3.4 | H2: "Last voted on …" | Shown below votes/clicks | [x] | OK |
| 3.5 | H3: save a station as favourite (not voted today) | No banner; heart filled on station info | [x] | OK |
| 3.6 | H3: setting off, save another station as favourite | Heart stays empty | [x] | OK |
| 3.7 | H4: settings and about text | Mention cover, album, genre | [x] | fine |
| 3.8 | H4: station with titles in CAPITALS | Normal spelling for reliable matches; genre in the 2nd line | [x] | ok |
| 3.9 | H5: favourite → "Move" | "Done" visible, all favourites with a handle, no heart/info button, all groups expanded, empty groups visible | [x] | moving OK; "Done" only visible at the very top, button did not fit → v45 text action, see 9.3 – resolved: OK in 9.3 |
| 3.9a | H5: drag at the handle, also into another/empty group; swipe elsewhere | Moving across groups; list scrolls when swiping outside the handle; tapping a row does not play | [x] | OK, verified in the retests |
| 3.9b | H5: "Done" | Mode ends, collapse states as before; order/groups kept after a restart; favourites page shows the same | [x] | OK, verified in the retests |
| 3.10 | H6: expand the PlayerBar | Titles + "Open track history" (opens at the station); no station history | [x] | only 3 entries felt odd → v44 scrollable, see 8.3 – resolved: OK in 8.3 |
| 3.11 | H7: search in the track history (artist, genre, station) | Only matching entries; no jumping while playing | [x] | search OK, but focus lost after every letter → fixed in v44, see 8.5 – resolved: OK in 8.5 |
| 3.12 | H8: broken favourite | Hint in the row; "Find alternative" opens the advanced search with the name | [x] | OK – tested with a JSON file containing a wrong UUID, hint shown |
| 3.13 | H8: station info of a broken station | "Status" row, "Find alternative" in the pulley | [x] | OK – same test as 3.12 |

## 4. Groups and favourites page (I1, I2, v37)

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 4.1 | Without groups | Start page as before ("Favorites") | [x] | fine |
| 4.2 | Favourites page → "New group" | Dialog accepts only with a name; empty group appears | [x] | OK |
| 4.3 | Drag a favourite at the handle into another group (long way) | List scrolls along at the edge; counts are correct | [x] | OK, but the bottom favourite of a long list was not draggable (system gesture) → v44 more space below the list, see 8.6 – resolved: OK in 8.6 |
| 4.4 | Start page with groups | Groups as sections, rest under "Other favorites"; collapse state kept after a restart | [x] | OK by observation |
| 4.5 | Rename / move group up / down | Start page follows | [x] | renaming OK |
| 4.6 | "Delete group" | Favourites under "Other favorites" (same name on start page and favourites page) | [x] | OK |
| 4.7 | "Delete group and favorites" (+ cancel during the countdown) | Deleted or cancelled | [x] | OK |
| 4.8 | Select: 2 favourites + 1 group → "Delete selected" | Title shows the count; deleted after the countdown | [x] | OK |
| 4.9 | Cover action "next favourite" with a favourite in a group | Changes only within the group | [x] | OK |
| 4.10 | Favourites page: "Remove from favorites" | With countdown | [x] | OK |

## 5. Backup, restore, M3U (I3, I5, v38)

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 5.1 | Change a favourite, wait 2–3 s | `Documents/Sailwave/sailwave-favorites.json` exists/updated (file manager) | [x] | covered by the tests in section 21 |
| 5.2 | Favourites page → "Back up favorites" | Message "saved in Documents/Sailwave" | [x] | OK |
| 5.3 | Favourites page → "Export as M3U playlist" | `sailwave-favorites.m3u` in Documents/Sailwave; playable in a player | [x] | file created; validated externally with VLC and ffmpeg |
| 5.4 | "Restore favorites …" | List "Automatic backups" (newest first, with counts) | [x] | covered by the tests in section 21 |
| 5.5 | Change several times within an hour | Still **one** new state (it is updated) | [x] | covered by the tests in section 21 |
| 5.6 | Delete a group with favourites, then restore the state from before | Confirmation dialog (date, content); afterwards favourites and group are back | [x] | covered by the tests in section 21 |
| 5.7 | Restoring | Behaviour as chosen in the dialog | [x] | adding only did not match the expectation of "restore" → v44 choice "replace" (default) / "add missing only" with preview, see 8.7/8.8 – resolved: OK in 8.7/8.8 |
| 5.8 | Restoring creates a state first | One additional state in the list afterwards | [x] | fine |
| 5.9 | Restoring does not vote | No automatic vote for added favourites | [x] | fine |
| 5.10 | "Choose file …" | Sailfish file picker opens, shows only JSON files; `Documents/Sailwave/sailwave-favorites.json` and a JSON from Downloads selectable; then confirmation dialog; PlayerBar hidden in the picker | [x] | OK (also covered by section 21) |
| 5.11 | Choose an unrelated JSON file | Message "not a Sailwave favorites backup" | [x] | covered by the restore tests in section 21 |
| 5.12 | File via mail/USB to a second device, restore there | Favourites and groups arrive | [x] | covered by the restore tests in section 21 |

## 6. WebDAV / Nextcloud (I4, v38)

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 6.1 | Settings → "Save favorites": "Device and WebDAV" | Fields URL, user name, password, help texts, "Test connection" appear | [x] | tested with wsgidav instead of Nextcloud: connection works, file is transferred |
| 6.2 | "Test connection" with correct data (app password) | "Connection successful"; afterwards folder `Sailwave/` with `sailwave-favorites.json` in Nextcloud | [x] | fine (wsgidav) |
| 6.3 | Wrong password | "Sign-in failed – …" | [x] | fine (wsgidav) |
| 6.4 | Wrong URL / flight mode | "Connection failed – check the URL" or "Server not reachable" | [x] | fine (wsgidav) |
| 6.5 | Change a favourite | New version of the file in Nextcloud after ~2 s | [x] | fine (wsgidav) |
| 6.6 | Flight mode, change a favourite, then online + "Sync now" | First the message "later again"; then uploaded | [x] | fine (wsgidav) |
| 6.7 | Change the file in Nextcloud (or second device), then start the app | Page "Sync conflict" | [x] | file on the server renamed by hand → sync uploaded a new `sailwave-favorites.json`; file edited by hand (favourites removed) → conflict page appears |
| 6.8 | Conflict → "Merge both" | Missing favourites from the server added, then uploaded; no new conflict | [x] | server file with more favourites → conflict page; merge added the server's favourites |
| 6.9 | Conflict → "Keep this device's" | Server file replaced; older version visible in Nextcloud "Versions" | [x] | server file correctly replaced by the local copy ("Versions" not checkable with wsgidav) |
| 6.10 | "Sync now" without changes | "Favorites are up to date" | [x] | message appears |
| 6.11 | Known limitation | Password is stored in the app database (not in Sailfish Secrets) – see TODO | — | resolved in v52, see section 15 |
| 6.12 | Invalidate a station UUID in the server JSON, then sync | Favourite arrives in the app with the hint "No longer listed at radio-browser.info"; context menu "Find alternative" | [x] | fine |

## 7. General

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 7.1 | German / French / Spanish | No truncated texts (settings, favourites page, conflict page) | [x] | OK – all checked in v81, nothing found |
| 7.2 | Light ambience on all new pages | Readable, chips/handles visible | [x] | readable |
| 7.3 | Landscape on the new pages | Usable | — | app does not rotate – `allowedOrientations` is only the default (portrait on phones) → TODO E, decision pending – 1.0 is portrait only, landscape planned for 1.1 |
| 7.4 | Log after the test run | No new `[W]` lines from `qml/` | [x] | no errors found |
| 7.5 | Track history: station with multi-line stream titles, or a long iTunes title (e.g. "To Franche (The 1984 Suite Version) [Remastered 2015]") | Title wraps to at most 2 lines, the row grows, nothing overlaps | [x] | at first the title overlaps the entry below → TODO K2 – resolved: OK in 14.10 (14.8/14.9 still open) |

## 8. Retests v44

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 8.1 | Vote offline | Heart filled immediately, empty again after ~10 s, message "Vote not possible, no connection" | [x] | ok |
| 8.2 | Setting "Song details from iTunes" | New heading, text fits | [x] | fine |
| 8.3 | PlayerBar expanded | 3 titles visible, more scrollable within the area; "Open track history" stays fixed below, smaller and quieter | [x] | ok, more elegant now |
| 8.4 | Station info: track history section | Same behaviour as 8.3 | [x] | fine |
| 8.5 | Search in the track history | Type several letters in a row without losing focus | [x] | fine |
| 8.6 | Favourites page, long list: drag the bottom favourite | After scrolling it is above the bottom edge; dragging starts no system gesture | [x] | dragging up/down works (auto-scroll, v48) |
| 8.7 | Restore → "Replace current favorites" | Preview shows added/removed/changed group; afterwards exactly the backup state (incl. groups and order) | [x] | fine |
| 8.8 | Restore → "Add missing favorites only" | Preview only "added"; nothing deleted | [x] | fine |
| 8.9 | Wrong state chosen with "replace" | Previous state can be restored from the automatic backups | [x] | accepted as is (previous state available in the automatic backups) |

## 9. Retests v45

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 9.1 | Expand the PlayerBar for a new station (0–2 titles), swipe on the bar | Nothing scrolls, not even the page behind | [x] | fine |
| 9.2 | KIS FM (or similar capitals): as soon as the cover is there | PlayerBar, app cover and lock screen show the normal spelling | [x] | fine |
| 9.3 | Start page → favourite "Move" | "Done" as text on the right between the search row and the first favourite group, immediately visible; list moves down by its height | [x] | fine |

## 10. Retests v46

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 10.1 | Move, then "Done" | List scrollable afterwards | [x] | ok since v47/v48 |
| 10.2 | "Done" | Start page stays at the top | [x] | ok since v47 |
| 10.3 | End the sort mode by tapping: a group header, a favourite row next to the handle, a station history/top station row | Mode ends in each case (no playing, no expanding/collapsing) | [x] | fine |
| 10.4 | Dragging at the handle | Works as before | [x] | fine |

## 11. Retests v47

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 11.1 | At the top: start "Move" and end with "Done" | Page stays at the top, no jumping | [x] | OK, tested with section 12 |
| 11.2 | Scroll down, drag a favourite from the bottom to the top, end by tapping (row/header) | The topmost visible row stays in place, no jumping | [x] | scrolling while dragging works (v48) |
| 11.3 | Groups were collapsed, end inside an expanded group further down | View stays at this group (or its header) | [x] | ok |
| 11.4 | Scroll afterwards | List scrollable normally | [x] | fine |

## 12. Retests v48

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 12.1 | Drag a favourite from the very bottom upwards at the handle, hold the finger at the top edge | List scrolls up by itself, the favourite can be moved to the first position | [x] | OK |
| 12.2 | Drag a favourite downwards, hold the finger just above the PlayerBar | List scrolls down by itself | [x] | OK |
| 12.3 | End afterwards (tap or "Done") | No jumping (like 11.1–11.3), list scrollable | [x] | OK |

## 13. Retests v50

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 13.1 | Scroll to the bottom of the start page, open the context menu of the last station (long press) | The list moves up so the whole menu is above the PlayerBar | [x] | retest with v51+: list moves up, context menu shown completely above the PlayerBar |
| 13.2 | Same in the track history (last entry) and in the advanced search results | Menu above the PlayerBar | [x] | retest with v51+: OK |
| 13.3 | Drag a favourite from the top down to the bottom (auto-scroll), end the sort mode | View stays at the bottom where it was dropped; its group stays expanded | [x] | OK |
| 13.4 | Drop a favourite, scroll a bit, then end the sort mode | No jump; the dropped favourite stays where it is on screen | [x] | OK |

## 14. Retests v51

Before testing: "Clean" + qmake (`qml/MenuVisibility.js` was removed from the project).

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 14.1 | Start page, bottom favourite with no favourite below, long press (finger stays down until the menu is open, then release) | Menu fully above the PlayerBar; nothing is triggered on release, the favourites page does **not** open | [x] | OK |
| 14.2 | Start page, favourite with other favourites below, near the PlayerBar | List moves up far enough, whole menu visible | [x] | OK |
| 14.3 | Last station at the very bottom of the start page (top stations), track history (last entry), advanced search results, station info (last similar station) | Menu above the PlayerBar in each case | [x] | OK |
| 14.4 | Expand the PlayerBar, scroll each of these lists to the end | Last row can still be scrolled above the expanded bar; collapsing again leaves no gap | [x] | OK |
| 14.5 | Before a station is selected (no PlayerBar) | Lists reach down to the screen edge | [x] | OK |
| 14.6 | Sort mode on the start page: drag a favourite down, hold just above the PlayerBar | Auto-scroll down works as before | [x] | OK |
| 14.7 | Scroll decorator | Ends above the PlayerBar | [x] | OK |
| 14.8 | Station with multi-line stream titles | Track history: title on two lines as sent by the station (line break kept, v53), nothing overlaps; PlayerBar, app cover, lock screen and previews: one line | [x] | OK by observation, no more problems |
| 14.9 | Long iTunes title (e.g. "To Franche (The 1984 Suite Version) [Remastered 2015]") while the track history is visible | Row grows to two lines as soon as the cover/iTunes data arrives, nothing overlaps | [x] | OK by observation, no more problems |
| 14.10 | Older history entries with line breaks (from before v51) | Track history: two lines; previews: one line. (Entries saved with v51/v52 stay one line – the break was already removed when storing.) | [x] | OK |

## 15. Sailfish Secrets for the WebDAV password (v52)

Before testing: if the build fails with a missing `sailfishsecrets` package/header, install the development package into the build target once (`sfdk tools package-install SailfishOS-5.1.0.11-aarch64 sailfishsecrets-devel`). "Clean" + qmake (new C++ class). The `.desktop` changed (permission `Secrets`) → deploy + **reboot**, then start from the app grid (Qt Creator bypasses Sailjail).

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 15.1 | First start under the sandbox | Permission prompt now also lists the secure storage; no other dialog | [x] | prompt appeared correctly |
| 15.2 | Migration: start with the WebDAV password from v51 | Settings show the password (dots); sync works; log without `[W]` about Secrets | [x] | existing login still works after the migration |
| 15.3 | After 15.2: the old password is gone from the database | `sqlite3` on the app database: no row `webdavPassword` in `settings`, row `webdavPasswordStored = true` | [x] | old password no longer in the SQLite database |
| 15.4 | Restart the app, wait for the sync after ~6 s | Sync works (password read from Secrets), no "Sign-in failed" | [x] | OK |
| 15.5 | Open the settings right after the start | Password field filled (possibly after a moment) | [x] | OK |
| 15.6 | Change the password (wrong one), restart, "Test connection" | "Sign-in failed"; then the correct one, restart → works | [x] | OK |
| 15.7 | Clear the password field, restart | Field stays empty; no `[W]` lines | [x] | OK |
| 15.8 | Any system dialog / prompt when storing or reading? | None (collection unlocked with the device) | [x] | OK |
| 15.9 | Lock the device, wait, unlock; then "Sync now" | Works | [x] | OK |
| 15.10 | Harbour check (`sfdk check -s harbour <rpm>`) | No error about `libsailfishsecrets` / permission `Secrets` | [x] | OK – no error about libsailfishsecrets / permission Secrets |

## 16. Start page without jumping (v55, TODO K3)

v55 hung at start-up when favourites existed (no window, app closed after a while): a local variable `rows` in `buildRows()` replaced the parameter of the same name → endless loop. Fixed in v56 – test this section with v56.

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 16.1 | Station history expanded, tap an entry that is not at the top | Station plays; the list does not jump, the tapped row stays where it is | [x] | OK – nothing jumps unexpectedly |
| 16.2 | Same, scrolled down so that the station history is in the middle of the screen | No jump, also not ~0.5 s later | [x] | OK – nothing jumps unexpectedly |
| 16.3 | Play a top station (station history expanded and visible above it) | The tapped row stays exactly in place and **stays in the top stations**; the station history gets the station as a new first entry, the rows above move up | [x] | OK – nothing jumps unexpectedly |
| 16.3a | Same while the very top of the start page is visible | Tapped row stays in place; the top of the page moves up out of view | [x] | OK – nothing jumps unexpectedly |
| 16.3b | Same with the station history collapsed | Nothing changes on screen | [x] | OK – nothing jumps unexpectedly |
| 16.4 | After 16.1/16.3: open station info (or swipe to the track history) and come back | Station history now in the new order (last played at the top), top stations re-scored; the played top station is now only in the station history | [x] | OK – nothing jumps unexpectedly |
| 16.5 | Same with the app in the background (cover) and back | New order applied | [x] | OK – nothing jumps unexpectedly |
| 16.6 | Make a station from the station history a favourite | It moves to the favourites right away, gone from the history | [x] | retest v58: OK (v57 failed: stayed in the station history) |
| 16.7 | Logos while playing stations from the start page | Logos do not flicker / reload | [x] | OK |
| 16.8 | Search, then clear the search field | Start page as before, at the top | [x] | OK |
| 16.9 | Sort mode (Move, drag, Done / tap) | Behaves as in sections 10–13 | [x] | OK |
| 16.10 | Collapse/expand sections and favourite groups, load more top stations | As before, no jumping | [x] | OK |

## 17. Final test round before publishing (from TODO G)

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 17.1 | Ring navigation forwards/backwards | PlayerBar on all pages | [x] | OK – used constantly during the v71–v81 retests |
| 17.2 | Sleep timer | Moon only when expanded; choose duration, stop, fade out | [x] | OK |
| 17.3 | Offline / flight mode | Error hints, "Try again", banner; afterwards online without a restart | [x] | OK |
| 17.4 | Deleting with countdown | Clear history, delete entries, remove from history, groups, favourites | [x] | OK – countdown always shown |
| 17.5 | Expanding/collapsing, loading more top stations | No jumps | [x] | OK – as 16.10 (see also 16.10) |
| 17.6 | Advanced search | Filter combinations, cache | [x] | OK – tested extensively with v76/v77 |
| 17.7 | Voting | Banner; second time "possible again tomorrow"; offline | [x] | OK (see also 3.3, 8.1) |
| 17.8 | Lock screen image in the background | Cover "next favourite", device locked | [x] | OK – cover and all actions (next favourite) work |
| 17.9 | Restart | Settings are kept | [x] | OK |
| 17.10 | Change the home country | Start page and advanced search adapt | [x] | OK |
| 17.11 | Station info | No duplicate pages, plausible similar stations, cache when reopening | [x] | OK – tested in v81 |
| 17.12 | German / French / Spanish | No truncated texts | [x] | OK – all checked in v81, nothing found (see also 7.1) |

## 18. Release preparation (v60)

Before testing: "Clean" + qmake (new file `qml/RingHint.qml`, SPDX headers in all files). To see the hints again: press and hold the app icon on the about page.

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 18.1 | Build and start | Builds without new warnings; app starts (SPDX comment before `.pragma library` in the JS files is accepted) | [x] | OK |
| 18.2 | Rotate the phone | App stays in portrait | [x] | OK |
| 18.3 | Swipe hint: reset hints, restart the app, stay on the start page | After ~1 s a circle slides from right to left (3 times), label "Swipe sideways …" above the PlayerBar; the app can be used meanwhile | [x] | OK |
| 18.4 | Swipe hint: swipe to the track history while it runs | Hint ends at once; does not come back after a restart | [x] | OK |
| 18.5 | Swipe hint and PlayerBar hint (reset, play a station right after the start) | Never both at the same time; the PlayerBar hint follows after the swipe hint | [x] | OK – swipe hint first, then PlayerBar hint |
| 18.6 | No favourites (e.g. remove all, or a fresh install) | "Favorites" heading with "Tap the heart next to a station …" below the search row; disappears with the first favourite | [x] | OK |
| 18.7 | First "Move" on the start page | Label "Groups, backup and more: pull down …" at the bottom for ~8 s or until "Done"; dragging near the bottom still works; not shown again | [x] | OK |
| 18.8 | Settings → "Load missing logos via Google" off | Stations without a usable logo show a letter instead of the website icon (lists, station info, lock screen) | [x] | OK – radio-browser favicon or letter instead of the Google logo |
| 18.9 | Switch it on again | Website icons are back | [x] | OK – Google logos loaded again |
| 18.10 | About page | Copyright line, data sources with "(can be turned off in the settings)", "Development" section with the AI note, buttons "Source code", "Privacy policy" (opens PRIVACY.md on GitHub once published), "Report a problem" (GitHub issues) | [x] | retest v71–v81: OK (see 23.7); was: wish: "(can be turned off in the settings)" also after iTunes in the data sources → v70, retest |
| 18.11 | German / French / Spanish | New texts translated and not truncated (hints, settings switch, about page) | [x] | retest v81: OK in de/fr/es (see 23.7, 7.1); was: see 18.10 → v70, retest the about page in de/fr/es |
| 18.12 | Light ambience on all pages | Readable, hints visible | [x] | OK |
| 18.13 | PlayerBar colour after removing the commented-out variants | Unchanged (adaptive colour) | [x] | OK |
| 18.14 | Harbour check (`sfdk check -s harbour <rpm>`) | No errors | [x] | v94: OK for aarch64, armv7hl and i486 (build-release.sh); was v93 aarch64: FAILED – "Recommends: qml(Amber.Mpris) not allowed in RPM" |

## 19. Backup and sync reworked (v61)

Before testing: "Clean" + qmake (new page `BackupPage.qml`). Start with the existing settings (migration).

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 19.1 | Migration: settings after the update (WebDAV was set up before) | "WebDAV server" on, "Sync automatically" on, access data kept; sync works as before | [x] | OK |
| 19.2 | Settings, section "Backup and sync" | Note "Favorites are always backed up on this device …"; switch "WebDAV server"; when on: fields, "Sync automatically", "Test connection" | [x] | OK |
| 19.3 | Switch "WebDAV server" off and on again | Fields hidden/shown; URL, user name and password kept | [x] | OK |
| 19.4 | "Sync automatically" off, change a favourite | Nothing is uploaded (server file unchanged); no "Sync now" in the pulley | [x] | OK |
| 19.5 | "Sync automatically" on again | Sync check right away (conflict page if the server changed meanwhile) | [x] | OK – sync check when switching it on again |
| 19.6 | Favourites page pulley | "Back up and share", "Restore" (de: "Sichern und teilen", "Wiederherstellen"; both without "…"); no "Export as M3U playlist"; the pages themselves are titled "Back up favorites" / "Restore favorites" | [x] | OK |
| 19.7 | Backup page → Backup (JSON) → This device | `Documents/Sailwave/sailwave-backup-YYYY-MM-DD_HHMM.json` next to `sailwave-favorites.json`; message "Backup saved as …" with the file name | [x] | OK |
| 19.8 | Backup page → Playlist (M3U) → This device | `Documents/Sailwave/sailwave-playlist-YYYY-MM-DD_HHMM.m3u`; message "Playlist saved as …" | [x] | OK |
| 19.9 | Backup page: note and subtitle | Note "The current state is saved automatically as sailwave-favorites.json …"; subtitle under "This device" shows `sailwave-backup-…` / `sailwave-playlist-…` depending on the format; no "Other folder" | [x] | OK |
| 19.10 | Same twice within a minute / later | Same minute: the file is overwritten; later: a second file; in the file manager they sort by time | [x] | OK |
| 19.11 | Restore page, section "Saved backups" | The `sailwave-backup-…` files, newest first, with date and counts; tap → confirmation dialog; without any: "No saved backups yet" | [x] | OK |
| 19.11a | Backup page → Share (JSON, then M3U) | The dated file is saved in Documents/Sailwave, then the Sailfish share menu opens (mail, Bluetooth, …); sharing by mail attaches the file | [x] | OK |
| 19.11b | Share, then cancel the share menu | Back on the backup page; the saved file stays | [x] | OK |
| 19.12 | Backup page → WebDAV server (JSON), with and without automatic sync | Busy indicator, "Saved on the WebDAV server"; server file updated; no conflict page at the next sync | [x] | OK |
| 19.13 | Backup page → WebDAV server (M3U) | `Sailwave/sailwave-favorites.m3u` on the server | [x] | OK |
| 19.14 | WebDAV with wrong password / offline | "WebDAV sign-in failed" / "WebDAV server not reachable" | [x] | OK |
| 19.15 | Without a WebDAV server set up | No "WebDAV server" entry on the backup and restore pages | [x] | OK |
| 19.16 | Restore page with a server | Section "WebDAV server": first "Loading …", then date + counts; note about older versions in Nextcloud | [x] | OK |
| 19.17 | Tap the server entry → Replace | Confirmation dialog as usual; with automatic sync the note "the WebDAV server then has this state as well"; afterwards favourites as on the server, no conflict page | [x] | OK |
| 19.18 | Server without a file yet / file not from Sailwave | "No backup on the server yet" / "… not a Sailwave favorites file", not tappable | [x] | OK |
| 19.19 | German / French / Spanish | New texts translated and not truncated (settings, backup page, restore page) | [x] | OK – all checked in v81, nothing found |

## 20. Sailfish Secrets without a question at every start (v62)

Before testing: "Clean" + qmake (C++ changed).

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 20.1 | Start the app several times with WebDAV access data stored ("Sync automatically" on) | No "Allow access" question any more; sync after ~6 s works | [x] | OK |
| 20.2 | Same with "Sync automatically" off | No question at the start; the password is read only when opening the settings, backing up/restoring via WebDAV or testing the connection | [x] | OK |
| 20.3 | Change the password in the settings, restart | New password used, no question | [x] | OK |
| 20.4 | Fresh install (or Secrets data removed), enter a password for the first time | The question appears **once** (creating the collection); afterwards never again | [x] | OK, reproduced |
| 20.5 | Settings opened right after the start (sync off) | Password field filled after a moment | [x] | password shown correctly |

## 21. Release checks from the Sailfish guidelines (v65)

Before testing: the `.desktop` changed (permission `Downloads` instead of `UserDirs`, `Categories`) → deploy + **reboot**, then start from the app grid.

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 21.1 | First start after the update | Permission prompt lists Internet, Audio, Documents, Downloads, secure storage – no longer "user folders" in general | [x] | prompt shown with the permissions |
| 21.2 | Restore → "Choose file …" → a JSON file in Downloads | Can be chosen and restored | [x] | OK – automatic and manual backups (local and WebDAV) listed, restore works |
| 21.3 | Restore → "Choose file …" → Documents/Sailwave | Still works | [x] | OK – automatic and manual backups (local and WebDAV) listed, restore works |
| 21.3a | Restore page below "Choose file …" | Hint "Files from Documents and Downloads" (de: "Dateien aus den Ordnern Dokumente und Downloads") | [x] | OK |
| 21.3b | Choose a JSON file from Pictures (if the picker offers it) | Message "This file is not a Sailwave favorites backup" or nothing happens – no crash | [x] | picker says the path cannot be accessed – explained on the restore page, OK |
| 21.4 | App grid: drag Sailwave onto another audio app | The new folder gets an audio/media name | [x] | no suitable example app found – accepted |
| 21.5 | Build for aarch64, armv7hl and i486 | All three build; Harbour check passes for each | [x] | v94: OK – all three packages built with build-release.sh (sfdk, clean shadow builds) |
| 21.6 | QML profiler: start → play → station info → swipe to the track history | No step blocks the UI noticeably (> ~100 ms); note the values | [x] | v94 debug build: OK – no step blocks the UI noticeably after start-up. Recorded 1.74 s of QML/JS in total. Start-up: compiling harbour-sailwave.qml with everything it pulls in 538 ms once (incl. AdvancedSearchPage 124 ms, TrackHistoryPage 44 ms, AdvancedSearchFilter 44 ms – the ring pages are created at start). Largest single steps afterwards: one radio-browser response 101 ms (JSON parsing in RadioApi.requestJson), top-station scoring 44–76 ms per run, 3 runs (applyTopScoring/processTopStations/scoreStation/calculateIdf), playing a station 71 ms (playStation incl. SQLite writes), ring navigation 45 ms, first page push 35 ms. Ideas for 1.1 in TODO (Performance). (Definition of Done "measure, don't assume") |
| 21.7 | Memory: `smem -P harbour-sailwave` (or `top`) after 10 min of use | Reasonable and not growing steadily (note PSS) | [x] | v94 release package, measured via SSH (VmRSS): start ~208 MB, rises while pages/logos/covers are loaded the first time (277 → 349 MB in 5 min, growth slowing), then stable 265–345 MB for 6 min and memory is given back (drops to ~266 MB) – no leak |
| 21.8 | Many favourites (~100, e.g. restore a large backup) and a full track history (200) | Start page, favourites page and track history scroll smoothly; sorting still works | [x] | OK by observation |

## 22. Logo fallback in the lists (v67)

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 22.1 | The two top stations that showed the generic/letter icon in the list but the Google logo in the PlayerBar | List shows the same logo as PlayerBar and lock screen (shortly after the first attempt fails) | [x] | OK – correct Google logo, logos consistent |
| 22.2 | Same stations in the advanced search, station history and favourites | Same logo everywhere | [x] | OK – correct Google logo, logos consistent |
| 22.3 | "Load missing logos via Google" off | Letter avatar in the list and the PlayerBar alike | [x] | OK – no Google logos when switched off |
| 22.4 | Scroll quickly through a long list (many logos) | No stutter from the change | [x] | slight stutter when scrolling very fast – accepted, hardly noticeable |

## 23. Retests v71 (findings of the extended retest)

Before testing: "Clean" + qmake (C++ changed: `secretstore.*`).

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 23.1 | Track history: tap a track of a station further down | Its group moves to the very top, is expanded, the list scrolls to the top (search field visible) | [x] | OK – whole header visible (with the v72 margin) |
| 23.2 | Same with a collapsed station (tap is not possible) / with an active search | With search: the station moves to the top within the results, expanded | [x] | OK |
| 23.3 | While the track history is open, new titles arrive | Order of the groups unchanged, no jump (as before) | [x] | OK – station does not jump, new title added |
| 23.4 | PlayerBar → "Open track history" for a station in the middle of the list | Station header fully visible at the top | [x] | OK – margin fits (v72) (earlier: v71: name still slightly cut off at the top → v72 more space above the header) |
| 23.5 | Same for the station that is first in the list (e.g. playing right now) | Like 23.4: station header at the top with some space above it, no jerk | [x] | OK (v72) (earlier: v71: jump to the very top incl. search field jerked → v72 same as the other stations) |
| 23.6 | Station info → "Open track history" | Same as 23.4 / 23.5 | [x] | OK |
| 23.7 | About page, "Data sources" | Last sentence names ipapi.co / api.country.is "only while set to automatic in the settings"; de/fr/es translated | [x] | OK |
| 23.8 | Settings → Home country | Description mentions that "Automatic" detects the country from the IP address via ipapi.co; de/fr/es not truncated | [x] | OK in all languages |
| 23.9 | Fresh install (or Secrets data removed), enter the WebDAV password for the first time, allow access | Password stored at the first attempt (restart: still there, no "could not be saved" hint); log: at most one `[SecretStore]` warning | [x] | OK (was: only stored at the second entry) |
| 23.10 | Hints reset (about page icon), play a station | First "Tap the station name for station info", then (1.5 s after it is gone) "Tap the arrow for recent tracks and the sleep timer" | [x] | OK |
| 23.11 | Expand the PlayerBar while the arrow hint is shown / before it appears | Hint disappears / is never shown | [x] | OK |
| 23.12 | Advanced search, first search (hints reset) | "Search results appear at the bottom of the page" above the PlayerBar; gone after a tap, 8 s or leaving the page; not shown again | [x] | OK – shown correctly after the first search |
| 23.13 | Spanish: back up favourites | Format "Playlist (M3U)"; messages "Playlist guardada como …" / "No se pudo guardar la playlist" | [x] | OK for now – the Spanish wording is still to be checked with a native speaker (see TODO) |
| 23.14 | Change the system language, then restart the phone normally | Secrets "Allow access" question: note whether it also comes after a normal reboot | [x] | OK – the question comes once after the language change, not again afterwards (after a language change it came once – system behaviour (UI restart)) |
| 23.15 | Start page after a system language change (es/fr) | Station names and logos shown; if not: send the `[W]` lines of the log | [x] | OK – logos etc. shown, not reproducible (seen once, fine at the next start) |

## 24. Similar stations reworked (v73)

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 24.1 | Station info of the favourite "Radio Si - Radio Slovenija International" (uuid dd56bf37…, Slovenia; local news, traffic, world music, world news; same stream as the entry "Radio Si" 961b5644… with other tags) | local news/traffic only from Slovenia; world music/world news also from abroad, Slovenia / Austria / neighbours first; no Calgary/Houston at the top | [x] | OK – comprehensible (was: Calgary, Houston. Note which stations appear) |
| 24.2 | A music station with clear genre tags (e.g. a jazz or rock station) | Still stations of that genre from all over the world, own country / neighbours / home country first | [x] | OK – Radio Swiss Jazz: Swiss stations first, then German ones (regression check) |
| 24.3 | A news/talk station (e.g. Ö1 or a German news station) | Stations from the same country only (news/talk are type tags) | [x] | OK |
| 24.4 | A station whose tags only name its country/language (e.g. only "austria", "german") | Like a station without tags: genres from the track history, otherwise "Popular in this country" | [x] | OK – example Radio UNO Kärnten |
| 24.5 | Opening station info | No noticeable slowdown (about the same number of requests as before) | [x] | OK – no slowdown, performance as before |
| 24.6 | Station info of the entry "Radio Si" (961b5644…), row "Tags" | All four tags incl. "rtvslo", separated by ", ", wrapped if needed (lists show only the first 3 tags – by design) | [x] | OK (v74) |
| 24.7 | Advanced search "radio si" several times (also after "Clear cache") | Always the same entry: "Radio Si" (961b5644…, 4 tags, 1864 votes); tags in its station info incl. "rtvslo" | [x] | OK (v75 – was random) |
| 24.8 | Favourite "Radio Si - Radio Slovenija International" | Station info still shows its own tags (local news, traffic, world music, world news); heart filled in the search result too (same stream) | [x] | OK (v75) |

## 25. Station names tidied up (v77)

Before testing: Settings → "Clear cache" (cached search results and the top stations snapshot still hold the raw names; the lists tidy them up when shown, but the A-Z order of a cached search would still be the old one).

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 25.1 | Start page quick search "Radio si" | Names start aligned under each other; no row overlaps the next one ("RADIO MARIAM ARABIC" one line); names that started with spaces are no longer at the top of the A-Z order | [x] | OK (was: overlapping rows, indented names) |
| 25.2 | Play such a station (e.g. "Blasmusikradio mit Bernd") | PlayerBar, app cover and lock screen show the name without leading spaces / on one line | [x] | OK |
| 25.3 | Station info of such a station | Header name tidied up | [x] | OK |
| 25.4 | Advanced search with the same term, sort A-Z | Same as 25.1 | [x] | OK |

## 26. Quick search order, 15 similar stations (v78)

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 26.1 | Start page quick search "Radio si" | Radio SI entries at the top (name starts with "radio si"), then names containing "radio si", then the rest A-Z | [x] | OK (v78) |
| 26.2 | Same search as "si radio" (word order swapped) | Same matches; order for the phrase "si radio" (here mostly A-Z, as no name starts with it) | [x] | OK (v78) (shares the cache with 26.1) |
| 26.3 | Quick search with one word, e.g. "jazz" | Names starting with "jazz" first, then names containing "jazz", then stations found via tags | [x] | OK (v78) |
| 26.4 | Station info of a station with many matches (e.g. Radio Swiss Jazz) | Up to 15 similar stations | [x] | OK |
| 26.5 | Start page: play a favourite | It appears at the top of the station history as well (and stays in its favourites group); the tapped row does not jump | [x] | OK – review again in 1.1 if needed (see TODO) (v79) |
| 26.6 | Station history row of a favourite | Heart filled; "Remove from favorites" in the context menu removes it from the favourites, the history row stays | [x] | OK – stays in the station history, heart no longer filled after removing (v79) |
| 26.7 | Make a station of the station history a favourite | It stays in the station history (no longer disappears) and appears in the favourites | [x] | OK – stays in the station history (v79 – was: left the history) |
| 26.8 | Advanced search, text "radio si", sort "Popular" | Radio SI (and other names starting with "radio si") at the top, then names containing it, then the rest by popularity (home country first) | [x] | OK (v80) |
| 26.9 | Same with sort "A-Z" | Same groups, A-Z within each group | [x] | OK (v80) |
| 26.10 | Advanced search with filters only (no text), both sortings | Order as before | [x] | OK as far as testable (v80 – regression check) |
| 26.11 | Quick search on the start page (repeat 26.1) | Unchanged result (now uses the shared function) | [x] | OK in v81 (v80: failed – "radio kä" found nothing, only "radio kärnten" did → v81: whole phrase also sent as name search) |
| 26.12 | Quick search: type "radio kärnten" slowly (clear cache first) | "Radio Kärnten" appears as soon as "radio kä" is typed (search starts) and stays at the top while typing on | [x] | OK (v81) |
| 26.13 | Quick search "kärnten radio" (other word order) | Radio Kärnten found (via "kärnten") | [x] | OK (v81) |
| 26.14 | Quick search with one word (e.g. "jazz") | As before (no extra request) | [x] | OK (v81) |

## 27. Country names from the country code (v85)

Before testing: start with the existing data (tests the migration of the station history).

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 27.1 | Start with existing data | No `[W]` lines from `PersistentState`; station history as before | [x] | OK (new column `countrycode`) |
| 27.2 | English UI: play BBC Radio 6 Music, look at the station history and the station info | "United Kingdom" instead of "The United Kingdom Of Great Britain And Northern Ireland" | [x] | OK |
| 27.3 | German UI: start page, favourites page, search results, station info | Country names in German ("Schweiz", "Österreich", "Vereinigtes Königreich") | [x] | OK – country names in German |
| 27.4 | French / Spanish UI | Country names in English (short form) – no empty fields | [x] | OK – English short names |
| 27.5 | Old station history entries (played before v85) | Still show the stored name; after playing them again the short name | [x] | OK – old entries keep the stored name |
| 27.6 | Station info of "Los 40" (Spain) | Country row "Spain" only once (was "Spain · Spain"); stations with a real state still show it (e.g. "United States · California") | [x] | OK (v86) |

## 28. Fresh install / emulator (v93)

Found while building for i486: on a fresh install the start page read the station history before its table existed. The emulator also lacks two system services – these warnings are not app errors there: "Unable to connect to secrets daemon" (WebDAV password cannot be stored in the emulator) and "no service found for org.qt-project.qt.mediaplayer" (no media plugin – install `qt5-qtmultimedia-plugin-mediaservice-gstmediaplayer` in the emulator to test playback).

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 28.1 | Fresh install (emulator, or uninstall on the phone incl. data) and first start | No "no such table" warning; start page, station history (empty) and settings work | [x] | OK – no "no such table" warning on a fresh install (was: "no such table: station_history") |
| 28.2 | Start with existing data on the phone | As before, favorites and histories there | [x] | OK – existing data and lock screen controls work with the v94 release package (regression check) |
| 28.3 | Logo warnings in the log ("Error transferring … Not Found") | Only for stations whose logo URL is broken at radio-browser; a letter/fallback is shown instead | [x] | OK – expected warnings only (expected, not an app error) |

