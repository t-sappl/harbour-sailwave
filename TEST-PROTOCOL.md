# Sailwave – Test protocol

Status: package `sailwave-complete_49` (contains everything up to and including I3–I5).
Tested on: Sailfish OS 5.1, aarch64 · Date: __________

Legend: `[ ]` open · `[x]` OK · `[!]` failed (note + log excerpt in the "Note" column) · `[?]` unclear / keep watching

> **Before the first start:**
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
| 0.2 | Start with existing data | No crash; start page, favourites, history as before | [ ] | |
| 0.3 | Log at start-up | No `[W]` lines about `FavoritesStore`, `PersistentState`, `FavoritesBackup`, `TopStationsPage` | [ ] | |

## 1. Older open items

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 1.1 | App start (top station snapshot, v23) | Start page filled immediately, no big busy indicator | [ ] | |
| 1.2 | Advanced search: type an unknown genre into the filter field | Appears as its own chip, selectable | [x] | works |
| 1.3 | Advanced search: "All genres/languages must match" | Results change accordingly | [ ] | |
| 1.4 | Similar stations from the track history (v27): music station without tags, listen to 3–4 songs with covers, then station info | "Similar stations" instead of "Popular in this country" | [x] | works (Radio Uno Kärnten), keep watching |
| 1.5 | Optional: QML profiler, sequence start → play → station info → swipe to track history | Track history build clearly below the former 466–507 ms | [ ] | |

## 2. PlayerBar background (C2, v40)

Three variants in `PlayerBar.qml` (top of the Rectangle): **adaptive** (active), `highlightDimmerColor` and the previous fixed formula (both commented out).

| # | Test | adaptive | dimmer | previous | Note |
|---|---|---|---|---|---|
| 2.1 | Dark ambience with a bright wallpaper | [x] | [ ] | [ ] | OK (several ambiences) |
| 2.2 | Ambience with a very dark accent colour | [x] | [ ] | [ ] | OK (several ambiences) |
| 2.3 | Light ambience with a strong accent colour (heart, moon, arrow readable?) | [x] | [ ] | [ ] | OK (several ambiences) |
| 2.4 | Light ambience with a pale accent colour (bar still distinguishable?) | [x] | [ ] | [ ] | OK (several ambiences) |
| 2.5 | Ambience with a very saturated accent colour (garish?) | [x] | [ ] | [ ] | OK (several ambiences) |
| 2.6 | Change ambience while the app runs | Colour adapts immediately | — | — | changes immediately ✓ |
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
| 3.8 | H4: station with titles in CAPITALS | Normal spelling for reliable matches; genre in the 2nd line | [!] | track history OK; PlayerBar/cover/MPRIS still capitals (KIS FM) → fixed in v45, see 9.2 |
| 3.9 | H5: favourite → "Move" | "Done" visible, all favourites with a handle, no heart/info button, all groups expanded, empty groups visible | [!] | moving OK; "Done" only visible at the very top, button did not fit → v45 text action, see 9.3 |
| 3.9a | H5: drag at the handle, also into another/empty group; swipe elsewhere | Moving across groups; list scrolls when swiping outside the handle; tapping a row does not play | [ ] | v43 |
| 3.9b | H5: "Done" | Mode ends, collapse states as before; order/groups kept after a restart; favourites page shows the same | [ ] | v43 |
| 3.10 | H6: expand the PlayerBar | Titles + "Open track history" (opens at the station); no station history | [!] | only 3 entries felt odd → v44 scrollable, see 8.3 |
| 3.11 | H7: search in the track history (artist, genre, station) | Only matching entries; no jumping while playing | [!] | search OK, but focus lost after every letter → fixed in v44, see 8.5 |
| 3.12 | H8: broken favourite | Hint in the row; "Find alternative" opens the advanced search with the name | [ ] | |
| 3.13 | H8: station info of a broken station | "Status" row, "Find alternative" in the pulley | [ ] | |

## 4. Groups and favourites page (I1, I2, v37)

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 4.1 | Without groups | Start page as before ("Favorites") | [x] | fine |
| 4.2 | Favourites page → "New group" | Dialog accepts only with a name; empty group appears | [x] | OK |
| 4.3 | Drag a favourite at the handle into another group (long way) | List scrolls along at the edge; counts are correct | [!] | OK, but the bottom favourite of a long list was not draggable (system gesture) → v44 more space below the list, see 8.6 |
| 4.4 | Start page with groups | Groups as sections, rest under "Other favorites"; collapse state kept after a restart | [ ] | |
| 4.5 | Rename / move group up / down | Start page follows | [x] | renaming OK |
| 4.6 | "Delete group" | Favourites under "Other favorites" (same name on start page and favourites page) | [x] | OK |
| 4.7 | "Delete group and favorites" (+ cancel during the countdown) | Deleted or cancelled | [x] | OK |
| 4.8 | Select: 2 favourites + 1 group → "Delete selected" | Title shows the count; deleted after the countdown | [x] | OK |
| 4.9 | Cover action "next favourite" with a favourite in a group | Changes only within the group | [x] | OK |
| 4.10 | Favourites page: "Remove from favorites" | With countdown | [x] | OK |

## 5. Backup, restore, M3U (I3, I5, v38)

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 5.1 | Change a favourite, wait 2–3 s | `Documents/Sailwave/sailwave-favorites.json` exists/updated (file manager) | [ ] | |
| 5.2 | Favourites page → "Back up favorites" | Message "saved in Documents/Sailwave" | [x] | OK |
| 5.3 | Favourites page → "Export as M3U playlist" | `sailwave-favorites.m3u` in Documents/Sailwave; playable in a player | [x] | validated externally with VLC and ffmpeg |
| 5.4 | "Restore favorites …" | List "Automatic backups" (newest first, with counts) | [ ] | |
| 5.5 | Change several times within an hour | Still **one** new state (it is updated) | [ ] | |
| 5.6 | Delete a group with favourites, then restore the state from before | Confirmation dialog (date, content); afterwards favourites and group are back | [ ] | |
| 5.7 | Restoring | Behaviour as chosen in the dialog | [!] | adding only did not match the expectation of "restore" → v44 choice "replace" (default) / "add missing only" with preview, see 8.7/8.8 |
| 5.8 | Restoring creates a state first | One additional state in the list afterwards | [ ] | |
| 5.9 | Restoring does not vote | No automatic vote for added favourites | [ ] | |
| 5.10 | "Choose file …" | Sailfish file picker opens, shows only JSON files; `Documents/Sailwave/sailwave-favorites.json` and a JSON from Downloads selectable; then confirmation dialog; PlayerBar hidden in the picker | [ ] | |
| 5.11 | Choose an unrelated JSON file | Message "not a Sailwave favorites backup" | [ ] | |
| 5.12 | File via mail/USB to a second device, restore there | Favourites and groups arrive | [ ] | |

## 6. WebDAV / Nextcloud (I4, v38)

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 6.1 | Settings → "Save favorites": "Device and WebDAV" | Fields URL, user name, password, help texts, "Test connection" appear | [ ] | |
| 6.2 | "Test connection" with correct data (app password) | "Connection successful"; afterwards folder `Sailwave/` with `sailwave-favorites.json` in Nextcloud | [ ] | |
| 6.3 | Wrong password | "Sign-in failed – …" | [ ] | |
| 6.4 | Wrong URL / flight mode | "Connection failed – check the URL" or "Server not reachable" | [ ] | |
| 6.5 | Change a favourite | New version of the file in Nextcloud after ~2 s | [ ] | |
| 6.6 | Flight mode, change a favourite, then online + "Sync now" | First the message "later again"; then uploaded | [ ] | |
| 6.7 | Change the file in Nextcloud (or second device), then start the app | Page "Sync conflict" | [ ] | |
| 6.8 | Conflict → "Merge both" | Missing favourites from the server added, then uploaded; no new conflict | [ ] | |
| 6.9 | Conflict → "Keep this device's" | Server file replaced; older version visible in Nextcloud "Versions" | [ ] | |
| 6.10 | "Sync now" without changes | "Favorites are up to date" | [ ] | |
| 6.11 | Known limitation | Password is stored in the app database (not in Sailfish Secrets) – see TODO | — | |

## 7. General

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 7.1 | German / French / Spanish | No truncated texts (settings, favourites page, conflict page) | [ ] | |
| 7.2 | Light ambience on all new pages | Readable, chips/handles visible | [x] | readable |
| 7.3 | Landscape on the new pages | Usable | [ ] | |
| 7.4 | Log after the test run | No new `[W]` lines from `qml/` | [ ] | |

## 8. Retests v44

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 8.1 | Vote offline | Heart filled immediately, empty again after ~10 s, message "Vote not possible, no connection" | [x] | see 3.3 (retest OK) |
| 8.2 | Setting "Song details from iTunes" | New heading, text fits | [x] | fine |
| 8.3 | PlayerBar expanded | 3 titles visible, more scrollable within the area; "Open track history" stays fixed below, smaller and quieter | [!] | OK, but with < 3 titles the page behind the bar scrolled → fixed in v45, see 9.1 |
| 8.4 | Station info: track history section | Same behaviour as 8.3 | [x] | fine |
| 8.5 | Search in the track history | Type several letters in a row without losing focus | [x] | fine |
| 8.6 | Favourites page, long list: drag the bottom favourite | After scrolling it is above the bottom edge; dragging starts no system gesture | [?] | sometimes fails the first time, not reproducible – keep watching |
| 8.7 | Restore → "Replace current favorites" | Preview shows added/removed/changed group; afterwards exactly the backup state (incl. groups and order) | [x] | fine |
| 8.8 | Restore → "Add missing favorites only" | Preview only "added"; nothing deleted | [x] | fine |
| 8.9 | Wrong state chosen with "replace" | Previous state can be restored from the automatic backups | [ ] | to be looked at separately |

## 9. Retests v45

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 9.1 | Expand the PlayerBar for a new station (0–2 titles), swipe on the bar | Nothing scrolls, not even the page behind | [x] | fine |
| 9.2 | KIS FM (or similar capitals): as soon as the cover is there | PlayerBar, app cover and lock screen show the normal spelling | [x] | fine |
| 9.3 | Start page → favourite "Move" | "Done" as text on the right between the search row and the first favourite group, immediately visible; list moves down by its height | [x] | fine |

## 10. Retests v46

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 10.1 | Move, then "Done" | List scrollable afterwards | [!] | still jumped after scrolling down before → v47, see 11 |
| 10.2 | "Done" | Start page stays at the top | [!] | see 10.1 → v47 |
| 10.3 | End the sort mode by tapping: a group header, a favourite row next to the handle, a station history/top station row | Mode ends in each case (no playing, no expanding/collapsing) | [x] | fine |
| 10.4 | Dragging at the handle | Works as before | [x] | fine |

## 11. Retests v47

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 11.1 | At the top: start "Move" and end with "Done" | Page stays at the top, no jumping | [ ] | |
| 11.2 | Scroll down, drag a favourite from the bottom to the top, end by tapping (row/header) | The topmost visible row stays in place, no jumping | [!] | while dragging the list could not be scrolled up to the top → v48 auto-scroll at the edge, see 12 |
| 11.3 | Groups were collapsed, end inside an expanded group further down | View stays at this group (or its header) | [ ] | |
| 11.4 | Scroll afterwards | List scrollable normally | [x] | fine |

## 12. Retests v48

| # | Test | Expected | Result | Note |
|---|---|---|---|---|
| 12.1 | Drag a favourite from the very bottom upwards at the handle, hold the finger at the top edge | List scrolls up by itself, the favourite can be moved to the first position | [ ] | |
| 12.2 | Drag a favourite downwards, hold the finger just above the PlayerBar | List scrolls down by itself | [ ] | |
| 12.3 | End afterwards (tap or "Done") | No jumping (like 11.1–11.3), list scrollable | [ ] | |
