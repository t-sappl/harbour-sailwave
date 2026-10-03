# Sailwave – Roadmap

Open items and plans. Architecture and design decisions are in [`DESIGN.md`](DESIGN.md), tests in [`TEST-PROTOCOL.md`](TEST-PROTOCOL.md).

## Version 1.1 – planned

- [ ] **Landscape:** support landscape on all pages (1.0 is portrait only) – check the player bar height, cover, filter chips and dialogs
- [ ] **Restoring:** favourites whose station no longer exists at radio-browser.info – additionally search by stream URL or by name and country
- [ ] **Advanced search:** review the search logic based on experience – how genre, language and country filters are combined, "All genres/languages must match", sorting of the results
- [ ] **Corrections to radio-browser.info:** send station data corrections (e.g. homepage, logo) to radio-browser.info – first find out why Shortwave removed this feature again and whether there are solutions (confirmation before sending, plausibility checks of the data, …)
- [ ] **Start page – station history with favourites:** since 1.0 the station history also lists favourites (a favourite can appear in its group and in the history at the same time) – review after some use whether this duplication is useful or should be limited
- [ ] **Plural forms:** texts like "4 favorite(s) · 3 group(s)" with proper plurals via `qsTr("%n favorite(s)", "", count)` and numerus forms in the .ts files ("1 favorite / 4 favorites", "1 Favorit / 4 Favoriten", …) – needs an English .ts file with the plural forms too; about 16 texts
- [ ] **Performance** (QML profiler 1.0, test 21.6 – nothing blocks noticeably, but these are the largest items):
  - create the track history and advanced search pages only on the first swipe – about 210 ms less compiling at start-up (AdvancedSearchPage 124 ms, TrackHistoryPage 44 ms, AdvancedSearchFilter 44 ms)
  - top-station scoring runs 3 times around start-up at 44–76 ms each: compute the IDF and the tag arrays once per station pool, avoid the extra run triggered by `onOrderFrozenChanged`
  - large radio-browser responses: parsing up to ~100 ms on the UI thread – request fewer fields/rows where possible
  - measure the start-up time with the QML profiler before/after

## Later / ideas

- [ ] Back up the track history too (JSON + WebDAV), like the favourites
- [ ] Play stations directly on the favourites page (needs another way to show playback there, as the page has no player bar)
- [ ] Start page: favourite groups, station history and top stations look alike (all collapsible sections) – keep an eye on it

## Known issues

- Favourites page: dragging the bottom favourite occasionally fails the first time (not reliably reproducible).
