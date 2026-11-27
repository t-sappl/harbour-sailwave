# Changelog – Sailwave

Package: `harbour-sailwave-radio` · License GPL-3.0-or-later

## Unreleased – Car screen (Sailplay) and reliable resume

### New
- Sailplay (wireless CarPlay for Sailfish OS): Favorites (with their groups), Station history and a search are offered on the car screen; tapping a station plays it, and the car can start Sailwave. The Jolla Store build has it too: Sailwave needs no extra sandbox profile for it.

### Fixed
- After a phone call or an announcement of the car, Sailfish resumed the paused stream, which had gone stale: playback failed with "Internal data stream error". Any resume now joins the live stream again, as if the station had just been opened.
- Reconnects did not reconnect: setting the same stream address again kept the broken player, so the three attempts failed the same way. They now open the stream anew, after 2, 4 and 6 seconds.
- A paused stream that fails (paused by the user, a call or another player such as a podcast app) no longer starts playing again behind the other player.
- Log lines `[Stream]` (debug level) for pauses, resumes, reopens and reconnects.

## 1.2.1-1 – Bugfix (November 2026)

### Fixed
- No sound after resuming: after several hours with many pauses the app could show the station as playing without any sound until it was restarted. Resuming now connects to the stream again (reported on GitHub for 1.1).
- Favorites repair a dead logo: when the saved logo no longer loads, the current logo and homepage from radio-browser.info are taken over. Before, a favorite kept the logo address from the day it was saved, even when it no longer worked.
- The current station gets the refreshed logo too, without playing it again.
- A station whose own logo fails late (e.g. ROCK RADIO SI) no longer shows an empty light tile in the lists.
- Manage favorites shows the country names in the app language.
- The page for a sync conflict with the WebDAV server opens again (it could not be loaded in 1.2).

### New
- Hint under the WebDAV address when it uses plain http (password and backups can be read on the way).

## 1.2-1 – Usability and unified design (November 2026)

### Usability and unified design
- Same controls as in Sailcast and Sailfeed: one button style, subtle arrows on rows that open a page, unified hint texts and messages (several messages stack, a tap hides them).
- Clear settings: short main page with summaries and sub-pages Playback, Discover, Backup and sync, Privacy. Redesigned About page.
- Neighbour pages are named under the page title. The page title stays visible and no longer jumps.
- Calmer lists: the playing station is highlighted, logos on a faint plate, cleaner names and tags.
- Player bar: larger icons, swipe up/down to open and close. Sleep timer 5 to 60 minutes or an own time.
- Station info with tiles for votes, plays and format.

### New
- Nextcloud: sign in in the browser, no typing of user name and password; the app gets its own app password.
- Backups: they contain the track history, show their reason and can be deleted one by one (the 10 newest manual ones are kept). When restoring, stations that are gone from the station database are looked up again.
- Advanced search: "Advanced" chip, result count while typing and after a tap on a filter chip ("100+"), filters as chips, "Clear filters".
- Start page: "Last heard" row, faster top stations.
- Favorites: choose the stations when creating a group; fold handles as in Sailcast.
- Track history: "Play" and "Show station" in the menu, recording can be switched off per station, text-only stations are not recorded.
- Starting a station pauses other players that are playing, e.g. a podcast.

### Fixed
- A pause is no longer undone by a pending reconnect.
- The WebDAV password is no longer lost after a restart.
- Empty rows on the start page right after the start.
- The search keyboard no longer closes while typing.
- Backups are written safely and checked before restoring; favorites are not all marked as missing after an empty server answer.
- Station logos look the same everywhere and work on every ambience and album cover: transparent logos (e.g. Radio Aktual) sit on a light tile (a dark one for very bright logos), logos that fill their square (e.g. SRF) get the same rounded corners; the badge on the album cover and on the lock screen image uses the same tile.

## 1.1.1-1 – Bug fix (November 2026)

- Fix: with a large system font, lists, headings, the player bar and the favorite tiles no longer overlap – they grow with the font size.
- Advanced search: long selections (genres, countries) start at the left and fade out.
- Refined app icon with more depth.
- English plural forms ("1 favorite", "2 favorites").

## 1.1-1 – October 2026

- New package name harbour-sailwave-radio – favorites and settings are kept.
- Landscape: player panel on the right with large previous/play/next buttons.
- Favorite tiles: large tiles as an extra page left of the start page – always or only in landscape.
- Lock screen, headset and car controls: the package installs Amber.Mpris, which was missing on some devices.
- Next and previous also work while paused and only appear when there is another favorite.
- Setting renamed to "Stay within favorite group"; its value is kept after a restart.

## 1.0.1-1

- Next and previous favorite on the lock screen (and headset/car), setting to stay within the favorite group.
- WebDAV: the bare server address of a Nextcloud is enough.

## 1.0-1

First public release.
