# Sailwave – Übergabe für einen neuen Chat

Stand: 5. Oktober 2026. Dieses Dokument fasst alles zusammen, was Claude braucht, um nahtlos weiterzuarbeiten. Im neuen Chat zuerst **`sailwave-complete_97.zip`** und diese Datei hochladen, dazu z. B.:

> Hier ist mein Projekt Sailwave (SailfishOS-Internetradio). Bitte lies zuerst HANDOVER.md, dann DESIGN.md und DESIGN-INTERNAL.md, und arbeite nach den dort beschriebenen Regeln weiter.

Ausführliche Architektur und Entscheidungen: `DESIGN.md` (öffentlich) und `DESIGN-INTERNAL.md` (intern, Historie aller Versionen v1–v95). Tests: `TEST-PROTOCOL.md`. Roadmap: `TODO.md`. Store-Texte: `STORE.md`.

---

## 1. Projekt

- **harbour-sailwave**, Anzeigename **Sailwave**: Internetradio für Sailfish OS, Daten von radio-browser.info, QML/Silica, etwas C++ (Qt 5.6).
- Entwickler: **Thomas Sappl** (GitHub `t-sappl`, Harbour-Konto `tsappl`, thomas.sappl@gmail.com). Claude unterstützt bei Code und Doku.
- Lizenz GPL-3.0-or-later. Repo: https://github.com/t-sappl/harbour-sailwave (öffentlich, Branch `main`).
- Testgerät: **Jolla Phone (2026)**, aarch64, Sailfish OS 5.1. Pakete für aarch64, armv7hl, i486.
- Sprachen: Englisch (Quelltexte), Deutsch, Französisch, Spanisch (`translations/*.ts`).

## 2. Arbeitsweise (verbindlich)

- Thomas bearbeitet Dateien teils selbst und committet direkt. **Immer vom zuletzt hochgeladenen Stand ausgehen**, nie von einer älteren eigenen Kopie.
- Jede Lieferung als **vollständiger Zip** `sailwave-complete_NN.zip` (laufende Nummer, nächste: **98**) mit allen `.md`-Dokumenten. Danach **TODO.md, DESIGN.md, DESIGN-INTERNAL.md und TEST-PROTOCOL.md zusätzlich einzeln** bereitstellen.
- Ausgabeordner **nicht leeren** – frühere Download-Links müssen gültig bleiben.
- Gelöschte oder umbenannte Dateien: Entpacken über das Projekt löscht nichts. Dann ausdrücklich `git rm`/`git mv`-Befehle mitgeben (oder einen `git am`-Patch).
- Jede Änderung in `DESIGN-INTERNAL.md` (Historie) festhalten; Entscheidungen von allgemeinem Interesse auch in `DESIGN.md`; neue Tests in `TEST-PROTOCOL.md`.
- Code und Kommentare auf **Englisch**. Neue UI-Texte immer in de/fr/es nachziehen.
- Öffentliche Doku in **amerikanischer Schreibweise** (favorites, colors, license).
- Deutsche Store-Texte: **keine direkte Anrede** (kein „du“/„Sie“), wie die App.
- C++-Änderungen: in Qt Creator **Clean + qmake**. Neue C++-Klassen in `src/harbour-sailwave.cpp` registrieren.
- `DESIGN-INTERNAL.md` und `STORE.md` sind **nicht im Repo** (über `.git/info/exclude` ausgeschlossen), ebenso der Ordner `screenshots/Jolla Store - groß`.
- Antworten an Thomas auf Deutsch, Schritt für Schritt bei Abläufen außerhalb des Codes (Git, Stores).

## 3. Umgebung

- PC: CachyOS (Arch), Shell **fish**. Sailfish SDK unter `/home/thomass/SailfishOS`, Ziel `SailfishOS-5.1.0.11-{aarch64,armv7hl,i486}`.
- Projekt: `~/Programming/harbour-sailwave` (Git-Repo). Release-RPMs: `~/Programming/RPMs/`.
- **`build-release.sh`** (liegt unter `~/Programming/`, nicht im Repo, eine Kopie liegt im Zip): baut alle drei Architekturen sauber per `sfdk` in `~/Programming/build-release/<arch>`, kopiert die RPMs, führt `sfdk check -s harbour` aus und zeigt eine Zusammenfassung. Paketname, Version und Release liest es aus der `.spec`. Optionen: einzelne Architekturen, `--no-check`.
- Telefon: Login-Shell auf **bash** umgestellt (`chsh -s /usr/bin/bash defaultuser`), fish nur interaktiv über `~/.bashrc` – fish als Login-Shell hatte `/etc/profile` und damit den QML-Profiler kaputt gemacht.
- GitHub-CLI `gh` ist auf dem PC nicht installiert (Releases bisher über die Webseite).

## 4. Aktueller Stand

**Veröffentlicht:**
- Version **1.0-1** auf GitHub: Tag `v1.0`, GitHub-Release mit den drei RPMs, Repo öffentlich.
- Seither im Repo (nach dem Tag): README/TODO-Überarbeitung von Thomas, Aufräum-Commits, `.spec` mit neuer Beschreibung, **Chum-Metadaten** (nur `%if 0%{?_chum}`) und `BuildRequires: qt5-qttools-linguist`; `%changelog` „Sat Oct 03 2026“. Letzter Commit: `7b85fe5 update description in harbour-sailwave.spec`.
- Die RPMs im GitHub-Release haben noch die alte Paketbeschreibung (funktional identisch; optional durch neu gebaute ersetzen).

**Alle Tests bestanden** (Abschnitte 0–28 im Testprotokoll), Harbour-Check OK für alle drei Architekturen, QML-Profiler und Speichertest OK.

## 5. Offene Punkte

### Jolla Store (Harbour) – blockiert
- Upload meldet **„Package name harbour-sailwave is reserved!“** (zuerst beim i486-RPM gesehen).
- Ursache laut Thomas: ein **hängender Entwurf „Sailwave“/harbour-sailwave** in seinem Konto `tsappl`.
- Mail an `harbour-qa@jolla.com` wurde abgewiesen (550 5.4.1, Adresse nimmt keine externen Mails an). Nächster Versuch: **developer-care@jolla.com** (Adresse aus 2013, aktueller Status unklar); sonst Kontakt auf harbour.jolla.com oder forum.sailfishos.org.
- Selbst versuchen: RPMs **im bestehenden Entwurf** hochladen statt in einem neuen Eintrag, bzw. den Entwurf löschen; ggf. alle drei RPMs gleichzeitig auswählen.
- **Entscheidung: keine Umbenennung**, der Paketname bleibt `harbour-sailwave`. Falls Jolla den Namen nicht freigibt, war eine Umbenennung auf `harbour-sailwave-radio` fertig vorbereitet (verworfen, aber jederzeit neu erstellbar):
  - per `git mv` umbenennen: `.pro`, `.spec`, `.desktop`, die 4 Icons, die 4 `.ts`-Dateien;
  - Inhalte: `TARGET`, `Name:`, `Exec=`, `Icon=`, Icon- und `TRANSLATIONS`-Zeilen in der `.pro`, Chum-`PackageIcon`, QML-Import `harbour.sailwave` → `harbour.sailwave.radio` (C++ + `CoverArtCache.qml`), MPRIS `serviceName`/`desktopEntry`, Icon-Pfad in `AboutPage.qml`, Verweise in README/DESIGN/STORE/TEST-PROTOCOL, Kommentar in `src/filehelper.h`;
  - **bewusst behalten:** `OrganizationName`/`ApplicationName` im `.desktop` (Datenordner `~/.local/share/harbour-sailwave/harbour-sailwave`, sonst Datenverlust), DB-Namen, User-Agent `harbour-sailwave/<version>` (in PRIVACY.md genannt), `qml/harbour-sailwave.qml`, `src/harbour-sailwave.cpp`;
  - danach überall (Harbour, OpenRepos, Chum, GitHub) einheitlich den neuen Namen verwenden; auf dem Telefon das alte Paket vorher entfernen.
- Store-Texte stehen in `STORE.md`. Kurzbeschreibung: „Internet radio with thousands of stations from radio-browser.info – in native Sailfish style“. Beschreibung endet mit dem KI-Hinweis („Developed with AI assistance; all changes are reviewed and tested on a Jolla Phone (2026) by the developer.“ / deutsch entsprechend).
- **Screenshots:** Store verlangt 1–3 Bilder, mind. 1080 px breit. Originale sind 1032×2272, daher hochskaliert auf 1080×2378 (Lanczos): `store-start-page.png`, `store-player.png`, `store-advanced-search.png` (Ersatz: `store-track-history.png`). Thomas hat eigene große Versionen in `screenshots/Jolla Store - groß` (nicht im Repo).

### Chum – noch nicht eingereicht
1. Konto auf https://build.sailfishos.org.
2. Im Home-Projekt Paket `harbour-sailwave` anlegen; Repositories prüfen (aarch64, armv7hl, i486; standardmäßig gegen sailfishos:latest).
3. Datei `_service` hinzufügen (Vorlage in `STORE.md`, Abschnitt Chum, Service `tar_git`), `revision` = Commit-Hash des Stands mit den Chum-Metadaten (aktuell `7b85fe5` oder neuer).
4. Build abwarten (alle drei „succeeded“), sonst Build-Log ansehen.
5. „Submit package“ an `sailfishos:chum:testing`; Maintainer prüfen und übernehmen nach `sailfishos:chum`. Kontakt bei Fragen: piggz oder rinigus, IRC #sailfishos auf OFTC.
- Spätere Versionen: Tag setzen, `revision` anpassen, neu einreichen.

### OpenRepos – noch nicht veröffentlicht
- Texte, Kategorie, Tags, alle 8 Screenshots (Reihenfolge in `STORE.md`), die drei RPMs ohne debuginfo/debugsource.

### Kleinigkeiten
- `qml/MenuVisibility.js` liegt noch im Repo, wird nirgends verwendet (Rest einer alten Version) → `git rm qml/MenuVisibility.js`.
- README, Abschnitt „Installation“: „Planned“ ersetzen, sobald Chum/OpenRepos/Jolla Store live sind.
- Spanische Übersetzung von einem Muttersprachler prüfen lassen (z. B. „Playlist (M3U)“, Test 23.13).
- Die `.ts`-Dateien im Repo hat Thomas mit lupdate bereinigt (veraltete Einträge entfernt) – diese Fassung ist maßgeblich.

## 6. Architektur in Kürze

| Datei | Zweck |
|---|---|
| `qml/harbour-sailwave.qml` (858 Z.) | App-Fenster, Wiedergabe (`playStation`), PlayerBar-Hinweise, Seitenring |
| `qml/pages/TopStationsPage.qml` (1721) | Startseite: Favoritengruppen, Senderverlauf, Top-Sender (Scoring nach Hörprofil), Schnellsuche |
| `qml/pages/AdvancedSearchPage.qml` (1088) | Erweiterte Suche mit Genre-/Sprach-/Länderfiltern |
| `qml/pages/StationInfoPage.qml` (892) | Senderinfo, Stimmen, Homepage-Korrektur, ähnliche Sender |
| `qml/pages/TrackHistoryPage.qml` (819) | Titelverlauf nach Sendern gruppiert, iTunes-Details |
| `qml/PlayerBar.qml` | globale Player-Leiste, Sleep-Timer, kurzer Titelverlauf |
| `qml/RadioApi.js` (314) | radio-browser-API, Dublettenbereinigung (`betterDuplicate`), `cleanName`, `groupByNameMatch`, `isTypeTag` |
| `qml/CountryData.js` (380) | Ländernamen (`displayName`, lokalisiert), Nachbarländer, Sprachen |
| `qml/AppSettings.qml` (303) | Einstellungen und Einmal-Hinweis-Flags |
| `qml/PersistentState.qml` (657) | Senderverlauf, Titelverlauf, Zustand (LocalStorage; Tabellen beim ersten `db()`-Zugriff anlegen) |
| `qml/FavoritesStore.qml` (468) | Favoriten und Gruppen |
| `qml/FavoritesBackup.qml` | JSON-/M3U-Sicherung, WebDAV-Sync mit Konfliktbehandlung |
| `src/secretstore.*` | WebDAV-Passwort in Sailfish Secrets |
| `src/webdavclient.*`, `src/artcomposer.*`, `src/filehelper.h`, `src/networkaccess.h` | WebDAV, Cover-Komposition für MPRIS, Dateizugriff, Netzwerk |
| `qml/MprisIntegration.qml` | Sperrbildschirm über Amber.Mpris (per Loader, optional) |
| `rpm/harbour-sailwave.spec` | Paket; `Recommends: qml(Amber.Mpris)` nur in Chum-Builds (Harbour verbietet es) |

Wichtige Erkenntnisse (Details in DESIGN.md):
- Harbour verbietet `Recommends:` und versionierte `Requires:`.
- Sailjail-Berechtigungen: Internet, Audio, Documents, Downloads, Secrets. Start aus Qt Creator umgeht Sailjail.
- Datenordner hängt an `OrganizationName`/`ApplicationName` im `.desktop` – nie ändern ohne Migration.
- Profiler 1.0: einmaliges Kompilieren beim Start 538 ms (210 ms davon durch sofort erzeugte Ring-Seiten), sonst nichts über ~100 ms. Speicher stabil 265–345 MB.

## 7. Nächste Version (1.1)

Siehe `TODO.md`: Querformat, Wiederherstellen nicht mehr existierender Favoriten, Überprüfung der erweiterten Suche, Korrekturen an radio-browser.info, Senderverlauf mit Favoriten prüfen, Pluralformen, Performance (Ring-Seiten erst beim ersten Wischen, Top-Sender-Scoring nur einmal, kleinere API-Antworten), Sicherung des Titelverlaufs.
