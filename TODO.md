# Sailwave – To-do list up to version 1.0

Goal: version 1.0 should be feature-complete and polished. Afterwards bug fixing only.

Legend: `[ ]` open · `[x]` done · **(D)** = discuss together first

---

## S. Sailjail / sandbox – done except S7 (Harbour check)

Background: `harbour-sailwave.desktop` had **no** `[X-Sailjail]` section, so the app ran without a sandbox (full access to the home directory). The section is mandatory for the Jolla Store. It changes data paths and access rights – database, settings, histories, favourites/groups, backup states, image cache and all network/file access – so it was done **before** further features.

- [x] **S1 Names (decided):** **`OrganizationName=harbour-sailwave`** and **`ApplicationName=harbour-sailwave`** – all data paths stay **identical**, no data migration needed (same approach as gPodder: organisation and app name = previous package name). Allowed characters: A–Z, a–z, 0–9, `_`, `-`, plus `.` in the organisation name. Only cosmetic drawback (no reverse domain name). Decision Thomas.
- [x] **S2 Data paths analysed** (device, without sandbox): `~/.local/share/harbour-sailwave/harbour-sailwave` (database, backup states), `~/.cache/harbour-sailwave/harbour-sailwave` (image cache), `~/.config/harbour-sailwave` (empty). So the `<Org>/<App>` pattern with Org = App = `harbour-sailwave` was already in use (Qt/libsailfishapp default). Sailjail provides `~/.local/share/<Org>/<App>`, `~/.cache/<Org>/<App>` and `~/.config/<Org>/<App>` → exactly the same folders with S1.
- [x] **S3 Data migration:** **not needed** with S1 – `~/.config/harbour-sailwave` is empty (checked), the data already lives in `<Org>/<App>` subfolders.
- [x] **S4 Permissions decided:** `Internet;Audio;Documents;UserDirs` (+ `Base` automatically). MPRIS/lock screen is covered by `Audio` (checked: `Audio.permission` contains the MPRIS rule, lock screen works).
- [x] **S5 Section added (v42):**
  ```
  [X-Sailjail]
  OrganizationName=harbour-sailwave
  ApplicationName=harbour-sailwave
  Permissions=Internet;Audio;Documents;UserDirs
  ```
- [x] **S6 Test under the sandbox (core):** own profile active (only Internet, Audio, Documents, UserDirs, Base), permission prompt ✓, data unchanged ✓, playback + lock screen/MPRIS ✓, backup + file picker ✓. All other functions (network, image cache, WebDAV …) are now tested under the sandbox anyway. Notes: a new `.desktop` only takes effect after deploying + rebooting; starting from Qt Creator bypasses Sailjail (for sandbox tests start from the app grid or with `sailjail -p harbour-sailwave.desktop /usr/bin/harbour-sailwave`).
- [ ] **S7 Harbour check** (`sfdk check -s harbour`).

---

## A. Sailfish guidelines (Common Pitfalls / Definition of Done)

- [x] **Edit homepage as a dialog** instead of "Save"/"Cancel" buttons (accept/cancel by gesture, "Reset" as pulley entry) – `StationInfoPage.qml`, new dialog page
- [x] **Touch areas at least `Theme.itemSizeSmall`**
  - [x] Chips, filter buttons, OR/AND switch – `AdvancedSearchPage.qml` (depends on C1)
  - [x] Homepage pencil icon – `StationInfoPage.qml` (with the homepage dialog)
  - [x] "Show all … tracks" – `StationInfoPage.qml` (replaced by "Open track history")
  - [x] Moon button – `PlayerBar.qml`
- [x] **Hide pulley menu if it only has disabled entries** ("Clear track history" with empty history) – `TrackHistoryPage.qml`
- [x] **Label colours:** static headings ("Genres", "Languages", "Countries", "Audio", "Sort", "Active filters") from `secondaryColor` to `secondaryHighlightColor` – `AdvancedSearchPage.qml`
- [x] **Scroll indicators** (`VerticalScrollDecorator`) in the lists of the expanded PlayerBar – `PlayerBar.qml`
- [x] **Cover action "next favourite"** re-added (second action next to play/pause) – `CoverPage.qml`
- [x] **Avoid deep station info stacks:** from "Similar stations" via `pageStack.replace()` instead of `push()` (like the Maps app) – `harbour-sailwave.qml` (`openStationInfo`)

## B. Consistency of the UI

- [x] **Unify font sizes:** filter headings of the search (`fontSizeExtraSmall`) aligned with the rest of the app (`fontSizeSmall`) – `AdvancedSearchPage.qml`
- [x] **Collapsible sections:** check Silica `ExpandingSection` instead of the own solution **(D)** → own solution kept (see DECISIONS)
- [x] **Placeholder server in URLs** (`de1.api.radio-browser.info`) replaced by `RadioApi.apiUrl()` (neutral placeholder `server.api…`)
- [x] **Start-up warning** `initialPage … sub-optimal` removed (start page via `push` in `Component.onCompleted`)

## C. Design topics to discuss together

- [x] **C1 Chips in the advanced search (D):** too few chips visible, horizontal scrolling collides with page swiping, touch areas too small → **implemented:** filters expand on the same page (see DECISIONS)
- [x] **C2 PlayerBar background (D):** own colour values vs. Silica style → **decided: adaptive formula** (tested with several ambiences on the device; revisit if anything looks off)
  - Hue of the highlight colour, saturation ≤ 45 %, fixed lightness 17 % dark / 88 % light, contrast to accent icons ≥ 3:1. Commented out for comparison: `highlightDimmerColor` and the previous fixed formula. Limit: Silica does not provide the wallpaper brightness.

## D. Performance / stutter

- [x] **Really hide collapsed rows:** start page and track history: collapsed rows are not in the model at all; track history is a `SilicaListView` since the profiler measurement
- [x] **Small thumbnails in the track history:** 200×200 variant of the iTunes URL instead of 600×600, only for list thumbnails. 600×600 stays stored; PlayerBar, app cover and lock screen still use 600×600 – `TrackHistoryPage.qml`
- [x] **Pause the PlayerBar marquee in the background** (`Qt.application.state`) – `PlayerBar.qml`
- [x] **Only update lists while visible:** track history page and PlayerBar lists – `TrackHistoryPage.qml`, `PlayerBar.qml`
- [ ] **Create pages on demand:** track history and advanced search only on the first swipe – `harbour-sailwave.qml` (ring navigation)
- [x] ~~**Move top station scoring into a `WorkerScript`**~~ → **dropped**: profiler measurement (v22) shows `processTopStations` at only 25 ms (below the 30 ms threshold); with the station pool the scoring also runs less often
- [x] **Shrink / write the big top station cache entry less often** – snapshot of the first 100, only after a network load; reloads bundled, station pool in memory, expired search cache entries deleted at start-up
- [x] **Disk cache for images** (`QNetworkDiskCache`), station logos and album covers available immediately after the first load (also after a restart and offline); images only, no API answers – `src/networkaccess.h`
- [ ] Measure start-up time with the QML profiler in Qt Creator (before/after)
  - Measurement before (v22): track history build 466–507 ms (start + swipe), top stations from the network ~180 ms (98 ms answer, 25 ms scoring, 54 ms cache write), opening station info 45–95 ms, drops down to 5 fps when similar stations arrive, binding loop `iconSize` in the app cover
  - Fixed since: track history as `SilicaListView`, small snapshot instead of a big cache entry, similar stations only after sliding in, binding loop
  - [ ] Measurement after, same sequence (start, play, open station info, swipe to the track history)

## E. Polish / features

- [x] **Track history on station info:** short preview plus entry "Open track history" instead of "Show all … tracks". Opens the track history page **on the stack above station info** (not the ring page), scrolls to the station and expands it.
- [ ] **First-start hints:**
  - [ ] Hint line in the empty favourites section
  - [ ] One-time swipe hint for the ring navigation (Silica `TouchInteractionHint` + `InteractionHintLabel`)
    - Plan (discussed, not implemented yet):
      - Only **once** on the first start on the start page, about 1 s after loading
      - `TouchInteractionHint` with `direction: TouchInteraction.Left` (circle slides from right to left), 2–3 runs
      - `InteractionHintLabel` at the bottom (dark gradient with text); above the PlayerBar if it is visible
      - Ends on swipe/touch or after the last run; does not block interaction
      - Flag in `AppSettings.qml` (e.g. `ringHintShown`) so it never appears again; a hidden way to reset it for testing (e.g. on the about page)
      - New file `qml/RingHint.qml`, included in `harbour-sailwave.qml` above the pages, below the PlayerBar
      - **Open: text** – proposals: "Swipe to switch between stations, track history and search" / "Swipe left for track history and search" / "Swipe sideways to switch pages" (+ de/fr/es)
  - [x] **Hint on the tappable station name in the PlayerBar** ("Tap the station name for station info"), once when the PlayerBar first appears (reason: pulley entry "Station info" removed, see H1).
- [x] **Replacement for "Similar stations" for stations without tags:** most popular stations of the station's country, own heading **"Popular in this country"** (no country name, no claimed similarity) – `StationInfoPage.qml`
- [x] **Track history jumped to the top while playing:** while the page is visible, only differences are applied (old/new history compared by station name + timestamp); group order stays, re-sorted on the next opening – `TrackHistoryPage.qml`
- [x] **Similar stations from the track history** for stations without tags: store iTunes genres (`lang=en_us`), count them, map to radio-browser tags – before the country replacement
- [x] **Favourites management:** reorder (H5), groups / favourites page / backup (block I) – done
- [ ] **Landscape** on all pages: check and adapt if needed
- [ ] **Light ambience** on all pages: check

## H. New items for 1.0 (from the test round, analysis in the conversation)

- [x] **H1 Remove the pulley entry "Station info" on the start page** – duplicate, station info is reachable via the station name in the PlayerBar; one-time hint above the PlayerBar.
- [x] **H2 Fix voting** – heart filled and locked immediately while the request runs; own daily rule (filled + locked for 24 h, afterwards "Last voted on …"); 10 s time limit when offline.
- [x] **H3 Automatic vote when saving a favourite** – setting, **default on**, respects the daily rule.
- [x] **H4 iTunes: text, title/artist, genre** – settings text ("Song details from iTunes"); `artistName`/`trackName` stored and shown **only for reliable matches**; genre in the second line of the track history. `previewUrl`/`trackViewUrl` deliberately not used (browser = media break).
- [x] **H5 Reorder favourites on the start page** – no ready-made Silica component; long press is the context menu → context menu "Move" starts a sort mode (handles, "Done"). Across groups since the test round.
- [x] **H6 Simplify the PlayerBar** – expanded: titles of the current station (3 visible, scrollable) + "Open track history"; station history removed.
- [x] **H7 Search in the track history** – filters by title, artist, genre and station.
- [x] **H8 Reachability of favourites** – radio-browser's `lastcheckok`, one request for all favourites; warning in the row, "Find alternative" (start page, station info, favourites page).

---

## I. For 1.1 / v2 (discussed; partly already implemented)

- [x] **I1 Favourite groups** (user-named) – start page sections, moving across groups, "Other favorites" for favourites without a group, two delete options (group only / group with favourites), cover action within the group.
- [x] **I2 Own favourites page** – groups create/rename/move/delete, drag (also between groups), select and delete several, reachability; pulley: sync now (WebDAV), restore, back up, export M3U, new group, select.
- [x] **I3 JSON backup** – `Documents/Sailwave/sailwave-favorites.json` (fixed name), 5 automatic states (at most one per hour, plus before restoring and before deleting a group with favourites), restore page with automatic states + Sailfish file picker, confirmation dialog with **"Replace current favorites"** (default) or **"Add missing favorites only"** and a preview of the changes.
- [x] **I4 WebDAV / Nextcloud** – settings section (URL with placeholder and help text, user name, password with app password hint, connection test), upload after every change, conflict page (merge both / keep this device's), retries.
- [x] **I5 M3U export** – `Documents/Sailwave/sailwave-favorites.m3u`, extended M3U with logo and group; validated with VLC and ffmpeg.
- [ ] **Follow-ups to I3/I4:**
  - [ ] WebDAV password in **Sailfish Secrets** instead of the app database (permission `Secrets` is allowed in the Jolla Store; check the API). Until then: app password hint.
  - [ ] Restoring: for favourites whose UUID no longer exists at radio-browser, additionally search by stream URL or name + country (currently: UUID → fresh data, otherwise saved data; afterwards the H8 reachability hint with "Find alternative" applies).
  - [x] File picker: Sailfish `FilePickerPage` (`Sailfish.Pickers 1.0` is allowed in the Jolla Store). Limitation: the start folder cannot be set according to the docs.
  - [x] `.desktop`: `[X-Sailjail]` with `Documents;UserDirs` (see block S).
- [ ] **I6 Back up the track history (JSON + WebDAV)** – technically the same mechanism as I3/I4; later, because more personal and frequently changing.
- [ ] **I7 Playing on the favourites page** (some day): tapping a station plays it. Drawback: there is no PlayerBar there (editing page) – playback feedback would need another solution.
- [ ] **I8 Rework the settings "Save favorites"** (feedback Thomas: the choice "only on this device" / "device and WebDAV" is confusing; the current solution works, redesign to be discussed later).
- [ ] **I9 Watch the start page:** favourite groups, station history and top stations look alike (all collapsible sections). OK for now – on the first start one only sees station history and top stations; groups appear with one's own favourites. Distinguish later if it confuses.
- [ ] **8.9 Restoring after choosing the wrong state** – look at it together (wish Thomas).
- [ ] **8.6 Favourites page:** dragging the bottom favourite sometimes fails "the first time" (not reliably reproducible) – keep watching, save a log when it happens.

## F. Publishing

- [ ] Version 1.0: `Version: 1.0`, `Release: 1` in `rpm/harbour-sailwave.spec`, `appVersion: "1.0"` in `harbour-sailwave.qml`
- [ ] `URL:` in the `.spec` (repository address)
- [ ] `AboutPage.qml`: `licenseName`, `sourceCodeUrl`, `privacyPolicyUrl`
- [ ] `LICENSE` file in the repository
- [x] `harbour-sailwave.desktop`: `Name=Sailwave`
- [ ] Privacy policy: iTunes (song titles to Apple), ipapi.co + api.country.is (country by IP), radio-browser.info (clicks, votes), WebDAV server (if configured)
- [x] README with a note on AI assistance (`README.md`); screenshots for Chum/OpenRepos still missing
- [ ] Harbour check: `sfdk check -s harbour <package>.rpm` (see S7)
- [ ] Update `lupdate`/translations after all text changes
- [ ] Clean up the project: remove the commented-out colour variants in `PlayerBar.qml` (if C2 is unchanged by then); delete `qml/VoteBanner.qml` (if still present), SVG not in `icons/172x172/`
- [x] Sailjail: see **block S**

## G. Tests before publishing

- [ ] Ring navigation forwards/backwards, PlayerBar on all pages
- [ ] Sleep timer (moon only when expanded, choose duration, stop, fade out)
- [ ] Offline/flight mode: error hints, "Try again", banner; afterwards online without restart
- [ ] Deleting with countdown (clear history, delete entries, remove from history, groups, favourites)
- [ ] Expanding/collapsing without jumps, loading more top stations
- [ ] Advanced search: filter combinations, cache
- [ ] Voting (banner, second time "possible again tomorrow", offline)
- [ ] Lock screen image in the background (cover "next favourite", device locked)
- [ ] Settings are kept after a restart
- [ ] Change home country → start page and advanced search adapt
- [ ] Station info: no duplicate pages, plausible similar stations, cache when reopening
- [ ] German / French / Spanish: no truncated texts
