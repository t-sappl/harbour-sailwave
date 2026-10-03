# Sailwave – Privacy Policy

Last updated: 2 October 2026

Sailwave is an internet radio app for Sailfish OS. This policy explains which data the app stores on your device and which online services it contacts.

## Summary

- No account, no registration.
- No tracking, no analytics, no advertising.
- The developer does not run any server and does **not** receive any data from the app.
- Your favorites, histories and settings stay on your device – unless you set up your own WebDAV server for backups or sync.
- To work, the app contacts the online services listed below directly from your device. Like every internet connection, each of them sees your device's IP address.

## Data stored on your device

| Data | Purpose | How to delete |
|---|---|---|
| Favorites and favorite groups | Your station list | In the app (favorites page) or by uninstalling |
| Station history and track history | "Station history" on the start page, track history with song titles | In the app ("Clear station history", "Clear track history", single entries via "Remove from history"); saving the track history can be turned off in the settings ("Save track history") |
| Settings | Your choices in the app | Uninstalling the app |
| Station logos and album covers (cache) | Faster display, less data traffic | Settings → "Clear cache" |
| Favorites backups (`Documents/Sailwave`) | Automatic backup, manual backup, M3U export | With a file manager; they are **not** removed when uninstalling |
| WebDAV password (only if a WebDAV server is set up) | Sign-in to your WebDAV server | Stored encrypted in the system's secure storage (Sailfish Secrets), not in the app's database; removed when you clear the password field |

## Online services the app contacts

Every request includes your IP address and the app's identifier `harbour-sailwave/<version>` (User-Agent). The services process this data under their own privacy policies.

### radio-browser.info (station database)
- **When:** loading top stations, searching, station info, checking whether favorites still work.
- **What:** your search terms and filters; when you **play** a station, a "click" for that station is counted (station ID only); when you **vote** for a station – manually, or automatically when you save a favorite (setting "Vote when saving a favorite", on by default) – a vote for that station is sent.
- Website: https://www.radio-browser.info

### The radio stations
- **When:** you play a station.
- **What:** the audio stream is loaded directly from the station's server (or its streaming provider), which sees your IP address like any listener's.

### Station logos
- **When:** a station is shown in a list or on the station info page.
- **What:** the logo is loaded from the address stored for the station in radio-browser.info, usually the station's own website.
- **Fallback via Google – optional:** if a station has no usable logo, the domain of the station's homepage (e.g. `example-radio.com`) is sent to Google's favicon service (`www.google.com/s2/favicons`) to get the website's icon. This is on by default and can be turned off in the settings ("Load missing logos via Google"); a letter is then shown instead. Privacy policy: https://policies.google.com/privacy

### iTunes Search API (Apple) – optional
- **When:** only if "Song details from iTunes" is turned on (on by default; can be turned off in the settings).
- **What:** artist and title of the song currently playing, and the store country derived from your device's language settings, are sent to Apple to look up the album cover, album name and genre. The cover image is then loaded from Apple's servers.
- Privacy policy: https://www.apple.com/legal/privacy/

### Country detection – only if no home country is set
- **When:** the home country is set to "automatic" (default) – used to suggest stations from your country.
- **What:** a request to ipapi.co (fallback: api.country.is) returns the country for your IP address. No other data is sent. Set your home country in the settings to avoid this.
- Websites: https://ipapi.co · https://country.is

### Your WebDAV server – optional
- **When:** only if you set up a WebDAV server in the settings – when you back up to or restore from the server, and after every change if "Sync automatically" is on.
- **What:** your favorites file (`Sailwave/sailwave-favorites.json`, or the playlist `sailwave-favorites.m3u` if you back up a playlist there) and your user name and password are sent to the server **you** entered (e.g. your own Nextcloud). Nobody else receives them.

### Links you open
Tapping a station's homepage (or other links) opens your web browser; from then on the browser and the website's own privacy policy apply.

## Permissions

Sailwave runs in the Sailfish OS sandbox (Sailjail) and only asks for: Internet, Audio (playback and lock screen controls), Documents (backups in `Documents/Sailwave`), Downloads (choosing a backup file from Downloads) and Secrets (encrypted storage of the WebDAV password).

## Your rights

As the developer receives no personal data, there is no data about you to look up, correct or delete on our side. For data processed by the services listed above, please contact them directly. Data on your device can be deleted at any time as described above.

## Changes

If the app's handling of data changes, this policy will be updated; the date at the top shows the latest version. The history of changes is visible in the repository.

## Contact

Responsible for this app (developer): Thomas Sappl
E-mail: thomas.sappl@gmail.com
Questions and bug reports can also be posted publicly as an issue: https://github.com/t-sappl/harbour-sailwave/issues

Source code: https://github.com/t-sappl/harbour-sailwave/
