# Sailwave – Store texts

Texts for the Jolla Store (Harbour), OpenRepos and Chum. Copy them into the respective forms; adapt them when features change. The German texts address nobody directly (no "du"/"Sie"), like the app itself.

## Common facts

| | |
|---|---|
| Name | Sailwave |
| Package | `harbour-sailwave` |
| Version | 1.0-1 |
| License | GPL-3.0-or-later |
| Source code | https://github.com/t-sappl/harbour-sailwave |
| Bug reports | https://github.com/t-sappl/harbour-sailwave/issues |
| Privacy policy | https://github.com/t-sappl/harbour-sailwave/blob/main/PRIVACY.md |
| Contact | Thomas Sappl, thomas.sappl@gmail.com |
| Tested on | Sailfish OS 5.1 (Jolla Phone 2026, aarch64) |
| Architectures | aarch64, armv7hl, i486 |
| Languages | English, German, French, Spanish |
| Screenshots | README and Jolla Store: `screenshots/start-page.png`, `player.png` (expanded player bar over the station info), `track-history.png`, `advanced-search.png`, `settings.png` – additionally for Chum and OpenRepos: `cover.png`, `lock-screen.png`, `backup.png` |

---

## Jolla Store (Harbour)

**Title:** Sailwave

**Category:** Music & Audio (or the closest audio/media category offered)

**Summary (one line):**
Internet radio with thousands of stations – in native Sailfish style

**Description (English):**

Sailwave brings thousands of internet radio stations to Sailfish OS – from the community database radio-browser.info, in a native Silica interface.

• Discover: top stations matched to your listening, your station history and a quick search
• Advanced search: genres, languages, countries, audio quality and sorting
• Favorites: your own groups, sorting by drag and drop, a hint for stations that stopped working – with "Find alternative"
• Track history: what was playing, with album covers, album and genre (optional, via iTunes)
• Station info: details, votes, similar stations
• Player: player bar on every page, sleep timer with fade-out, app cover with actions, lock screen controls
• Backup and sync: automatic backup on the device, backups and playlists (M3U) with date and time, sharing via the share menu, optional sync with your own WebDAV server (e.g. Nextcloud) – the password is kept in Sailfish's secure storage
• Privacy: no account, no tracking, no ads

Languages: English, German, French, Spanish.
Open source (GPL-3.0-or-later): https://github.com/t-sappl/harbour-sailwave

**Beschreibung (Deutsch):**

Sailwave bringt tausende Internetradiosender auf Sailfish OS – aus der Community-Datenbank radio-browser.info, in einer nativen Silica-Oberfläche.

• Entdecken: Top-Sender passend zum eigenen Hörverhalten, Senderverlauf und Schnellsuche
• Erweiterte Suche: Genres, Sprachen, Länder, Audioqualität und Sortierung
• Favoriten: eigene Gruppen, Sortieren per Ziehen, Hinweis bei Sendern, die nicht mehr funktionieren – mit „Alternative finden“
• Titelverlauf: was gelaufen ist, mit Albumcover, Album und Genre (optional, über iTunes)
• Senderinfo: Details, Stimmen, ähnliche Sender
• Player: Player-Leiste auf jeder Seite, Sleep-Timer mit Ausblenden, App-Cover mit Aktionen, Steuerung am Sperrbildschirm
• Sicherung und Synchronisierung: automatische Sicherung auf dem Gerät, Sicherungen und Playlists (M3U) mit Datum und Uhrzeit, Teilen über das Teilen-Menü, optional Synchronisierung mit dem eigenen WebDAV-Server (z. B. Nextcloud) – das Passwort liegt im sicheren Speicher von Sailfish
• Datenschutz: kein Konto, kein Tracking, keine Werbung

Sprachen: Englisch, Deutsch, Französisch, Spanisch.
Open Source (GPL-3.0-or-later): https://github.com/t-sappl/harbour-sailwave

**Message for QA:**

Sailwave is an internet radio player using the public radio-browser.info database; no account is needed. To test: start the app and tap any station under "Top stations" – it plays and the player bar appears.
Permissions: Internet (station data, streams, album covers), Audio (playback, lock screen controls via Amber.Mpris), Documents (favorites backups in Documents/Sailwave), Downloads (choosing a backup file received e.g. by mail when restoring), Secrets (only used if the optional WebDAV sync is set up: the WebDAV password is stored with Sailfish Secrets; the system asks once for access when it is saved for the first time).
Optional online services, all described in the privacy policy (linked on the about page): iTunes Search API for album covers (can be turned off), Google's favicon service for missing station logos (can be turned off), ipapi.co / api.country.is for the home country (unless set manually), the user's own WebDAV server.
The source code is public (GPL-3.0-or-later). The app was developed with the assistance of an AI model; all changes were reviewed and tested on a real device by the developer.

---

## OpenRepos

**Title:** Sailwave

**Category:** Applications → Multimedia (audio)

**Tags:** radio, internet radio, streaming, music, radio-browser, nextcloud

**Description:** use the English description from the Jolla Store section above (optionally followed by the German one). Add at the end:

> Bug reports and wishes: https://github.com/t-sappl/harbour-sailwave/issues
> Privacy policy: https://github.com/t-sappl/harbour-sailwave/blob/main/PRIVACY.md

**Changelog 1.0-1:**
First public release.

**Screenshots:** all eight in this order – start page, player, track history, advanced search, settings, cover, lock screen, backup.

**Packages to upload:** `harbour-sailwave-1.0-1.aarch64.rpm`, `harbour-sailwave-1.0-1.armv7hl.rpm`, `harbour-sailwave-1.0-1.i486.rpm` (not the `-debuginfo` / `-debugsource` packages).

---

## Chum

Chum takes its metadata from the `%description` of the `.spec`. The block below goes at the end of `%description` in `rpm/harbour-sailwave.spec` once the screenshots are in the repository (check the field names against the current Chum documentation before the first submission).

```
%description
Sailwave brings thousands of internet radio stations to Sailfish OS - from
the community database radio-browser.info, in a native Silica interface:
top stations matched to your listening, advanced search, favorites with
groups, track history with album covers, sleep timer, lock screen controls,
backups and optional WebDAV sync. No account, no tracking, no ads.

%if 0%{?_chum}
Title: Sailwave
Type: desktop-application
DeveloperName: Thomas Sappl
Categories:
 - Audio
 - AudioVideo
 - Player
Custom:
  Repo: https://github.com/t-sappl/harbour-sailwave
PackageIcon: https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/icons/172x172/harbour-sailwave.png
Screenshots:
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/start-page.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/player.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/track-history.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/advanced-search.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/settings.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/cover.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/lock-screen.png
 - https://raw.githubusercontent.com/t-sappl/harbour-sailwave/main/screenshots/backup.png
Links:
  Homepage: https://github.com/t-sappl/harbour-sailwave
  Bugtracker: https://github.com/t-sappl/harbour-sailwave/issues
%endif
```

**Submitting:** Chum packages are built on the Sailfish OBS from the GitHub repository (tag `v1.0`); the request to include the package goes through the Chum project (see its documentation for the current procedure).
