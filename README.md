# Sailwave Radio (harbour-sailwave)

Ein einfacher Internet-Radio-Player für Sailfish OS.
Nutzt die freie Senderdatenbank von
[radio-browser.info](https://www.radio-browser.info/).

## Funktionen

- **Eine Übersichtsseite** (`TopStationsPage.qml`), additiv statt ersetzend aufgebaut: ganz oben eine **Suchergebnis**-Sektion, die nur beim aktiven Suchen erscheint, darunter Favoriten, darunter der **Sender-Verlauf** (letzte gehörte, noch nicht favorisierte Sender, max. 3, in SQLite dedupliziert nach URL) und dauerhaft Top-Sender. Alle drei Bereiche (Favoriten, Sender-Verlauf, Top-Sender) lassen sich per Antippen der Überschrift ein-/ausklappen (kleiner "▸"-Pfeil zeigt den eingeklappten Zustand an). Während des Scrollens zeigt ein kleines Label am rechten Rand, welcher Bereich gerade in der Bildschirmmitte ist. Suchen blendet nur eine zusätzliche Sektion oben ein, statt die restliche Liste zu verdecken, und scrollt automatisch nach ganz oben, sobald Ergebnisse da sind. Keine separate Favoriten-Seite mehr – Favoriten sind direkt an `favoritesStore.favorites` gebunden und daher immer sofort aktuell, ganz ohne Zwischen-Cache.
- **Personalisierte Top-Sender-Empfehlungen**: Hat man Favoriten, wird daraus ein Profil abgeleitet (häufigstes Land, häufigste Sprache, bis zu 5 häufigste Tags). Fehlen einem älteren Favoriten noch Tags/Sprache/Land (weil er hinzugefügt wurde, bevor die App das erfasst hat), werden sie automatisch per Sammel-Request (`byuuid` mit allen betroffenen UUIDs) nachgeladen, bevor das Profil berechnet wird. Für jeden häufigen Tag läuft eine eigene Suchanfrage bei radio-browser.info; Bewertung: Land am stärksten gewichtet (3 Punkte), dann Sprache (2 Punkte), dann pro Tag-Treffer 1 Punkt. Die 20 besten werden gezeigt. Ohne Favoriten laufen stattdessen die globalen meistgeklickten Sender (`/json/stations/topclick/50`). Beides wird 10 Minuten gecacht (der Cache-Schlüssel enthält bei Empfehlungen das Profil, sodass er sich automatisch erneuert, sobald sich die Favoriten spürbar ändern).
- **Kombinierte Suche über ein einziges Feld**: Eingaben wie "kiss fm czech" werden in einzelne Wörter zerlegt und über Name, Tags, Land und Sprache gleichzeitig gesucht (ein Treffer muss jedes Wort in irgendeinem dieser Felder enthalten). Technisch: das längste Wort dient als Anker für eine parallele API-Abfrage über alle vier Felder, der Rest wird clientseitig gefiltert. Verlässt das Suchfeld den Fokus (z. B. durch Antippen eines Treffers), springt die Ansicht automatisch zurück zur vollständigen Liste (Favoriten/Verlauf/Top-Sender) – der eingegebene Suchtext bleibt dabei erhalten und die Suche läuft beim erneuten Antippen des Felds direkt (aus dem Cache) wieder an.
- Sender per Herz-Symbol als Favorit markieren/entfernen
- Wiedergabe über `QtMultimedia` (MediaPlayer)
- **Automatischer Reconnect** bei Aussetzern: hält der Stream länger als 8 Sekunden (`Stalled`) oder bricht mit Fehler ab, wird bis zu 3-mal automatisch neu verbunden; die Player-Leiste zeigt währenddessen "Puffert…" an
- **Zuletzt gespielter Sender wird gemerkt** und beim nächsten App-Start automatisch ausgewählt (Name/Icon sichtbar, auch am Sperrbildschirm) – aber bewusst **nicht automatisch abgespielt**, kein Autostart-Verhalten
- **Klick- und Voting-System der API angebunden**: Beim Abspielen wird automatisch ein Klick an `/json/url/{uuid}` gemeldet (fließt in die Popularitätsstatistik der API ein). Die Wiedergabe startet sofort mit der schon geladenen `url_resolved`; liefert die Klick-Antwort eine davon abweichende, frischere URL und läuft noch derselbe Sender, wechselt die App kurz auf diese um. Auf der Sender-Info-Seite kann für den angezeigten Sender gevotet werden (`/json/vote/{uuid}`, API-seitig auf 1x pro Sender und IP alle 10 Minuten begrenzt), mit kurzer Rückmeldung als Banner
- Eigener `User-Agent`-Header (`harbour-sailwave/0.1`) bei allen API-Anfragen, wie von radio-browser.info verlangt
- **"Jetzt läuft"-Anzeige**: liest den Songtitel live aus den ICY-Metadaten des Streams (`player.metaData.title`, von GStreamer automatisch aus dem Audiodatenstrom herausgefiltert) und zeigt ihn unter dem Sendernamen in der Player-Leiste an
- **Titelverlauf** (`TrackHistoryPage.qml`, über Pulldown-Menü erreichbar): speichert die letzten 50 empfangenen Songtitel mit Sendername und Uhrzeit in SQLite, aktualisiert sich live während der Wiedergabe
- **Sender-Info** (`StationInfoPage.qml`): über ein Info-Symbol links vom Herz in jeder Sender-Zeile direkt für diesen Sender aufrufbar, oder über das Pulldown-Menü für den gerade laufenden Sender. Lädt frische Detaildaten direkt von `/json/stations/byuuid` – Land/Bundesland, Sprache, Codec/Bitrate, Tags, Stimmen, Gesamt-Klicks, letzter Server-Check, Homepage (öffnet im Standardbrowser), und ganz unten abgesetzt der Abstimmen-Button sowie der **Titelverlauf dieses Senders** (die letzten 50 dort gespielten Titel). Wurde für den Sender schon mal abgestimmt, zeigt das Icon dauerhaft den ausgefüllten statt des Umriss-Zustands (persistent in SQLite gespeichert); nach dem Abstimmen wird die Sender-Info automatisch neu geladen, damit die aktualisierte Stimmenzahl sichtbar wird.
- **Aufklappbare Player-Leiste** (`PlayerBar.qml`): normalerweise nur Play/Pause/Stop, per Pfeil-Symbol links davon auf bis zu die halbe Bildschirmhöhe ausklappbar (mit Animation) – zeigt dann zusätzlich zum Sendernamen und aktuellen Songtitel (die schon oben in der Leiste stehen) den Titelverlauf des aktiven Senders, analog zur Sender-Info-Seite
- **Dreistufiges Sender-Icon** (`StationIcon.qml`): (1) echtes Favicon von radio-browser.info, (2) fehlt das, wird per Google-Favicon-Dienst (`s2/favicons`) ein Icon anhand der Domain aus dem `homepage`-Feld des Senders nachgeladen, (3) schlägt auch das fehl, ein generierter Avatar mit den Anfangsbuchstaben des Sendernamens auf einer Flächenfarbe aus einer eigenen, zwölfteiligen Palette (kräftige Farben passend zum Sailfish-Look), per Hash des Sendernamens ausgewählt. Kommt in der Senderliste, der Sender-Info-Seite und der Cover-Ansicht zum Einsatz. Der generierte Avatar ist immer sofort als Basis sichtbar (kein leeres Icon während des Ladens), verschwindet aber wieder, sobald ein echtes Bild geladen ist, statt dauerhaft mitgerendert zu werden. Bilder haben ein explizites `sourceSize` (vermeidet das Dekodieren mancher Favicons in unnötig hoher Auflösung); bereits als kaputt erkannte URLs werden für die laufende Sitzung gemerkt (`appWindow.brokenIconUrls`) und beim erneuten Anzeigen derselben Zeile nicht nochmal übers Netz versucht.
- **Homepage manuell korrigierbar**: Liefert radio-browser eine falsche/veraltete Homepage-URL, lässt sie sich auf der Sender-Info-Seite über ein kleines Stift-Symbol unter der zentriert angezeigten URL editieren (überschriebene Homepages werden fett/farblich hervorgehoben). Der Override wird pro `stationuuid` persistent in SQLite gespeichert (`homepage_overrides`-Tabelle) und wirkt sich überall aus, wo das Sender-Icon erscheint (Senderliste, Sender-Info-Seite, Player-Leiste, Cover-Ansicht) – auch nachträglich in bereits angezeigten Listenzeilen, über ein eigenes Update-Signal. Ein echtes Favicon-Feld von radio-browser.info hat dabei immer Vorrang vor dem Override – der Override wirkt nur auf die Domain, die für Stufe 2 (Google-Favicon-Dienst) herangezogen wird, falls kein echtes Favicon vorliegt. Leeres Feld speichern setzt auf die API-Homepage zurück.
- Cover-Ansicht im Ereignisbildschirm zeigt Favicon (bzw. Fallback-Icon), Sendername und den aktuellen "Jetzt läuft"-Titel, dazu Play/Pause-Aktion
- **Sperrbildschirm-Integration über MPRIS** (`MprisIntegration.qml`, `Amber.Mpris`-QML-Plugin, per `Loader` optional eingebunden): Sendername/Titel und Play/Pause-Steuerung erscheinen auf dem Sperrbildschirm, in der Multitasking-Ansicht und bei Bluetooth-/Headset-Steuerung, genau wie bei den eingebauten Musik-Apps. Läuft/pausiert gerade ein Sender, bleibt die App auch als "zuletzt verwendete Medien-App" mit Play-Knopf sichtbar. Cover-Art: `CoverArtCache.qml` rendert das Sender-Favicon per `Canvas` und speichert es als lokale PNG-Datei unter `StandardPaths.cache` (Dateiname enthält die `stationuuid`); `MprisIntegration` liest davon nur eine simple `file://`-String-Property (`appWindow.currentCoverArtUrl`). Wichtig: Die Cache-Komponente hängt bewusst **nicht** als Kind an `MprisPlayer` – Image/Canvas direkt darin hatten einmal die komplette MPRIS-Registrierung lahmgelegt. In der Spec-Datei als `Recommends: qml(Amber.Mpris)` eingetragen (weiche Abhängigkeit auf die QML-Capability, nicht auf einen konkreten Paketnamen – so machen es andere Sailfish-Apps auch) statt einer harten `Requires`: Ist das Modul verfügbar, wird es automatisch mitinstalliert; ist es das nicht, blockiert das die Installation der App nicht, sie läuft dann nur ohne diese eine Funktion weiter.

## Build mit dem Sailfish SDK

1. Sailfish OS SDK installieren und ein Target einrichten (z. B. `SailfishOS-4.x.x-armv7hl` oder `-i486` für den Emulator).
2. Projekt in Qt Creator (Teil des SDKs) öffnen: `harbour-sailwave.pro`.
3. Build → Deploy auf Emulator oder Gerät.

## Build per Kommandozeile (im SDK-Chroot/MerSDK)

```bash
mb2 -t SailfishOS-4.6.0.11-armv7hl build
```

Das fertige RPM liegt danach unter `RPMS/`.

## Noch offen / To-do

- Fehlerbehandlung bei Streams ohne gültige URL / Timeout.
- Zuletzt-gehört-Liste (analog zu den Favoriten via SQLite).
- Zertifizierung für den Harbour-Store: `harbour-` Präfix ist bereits korrekt
  gesetzt, RPM-Name muss mit dem OrganizationName/Package aus `.desktop`
  übereinstimmen (bereits der Fall).

## API-Hinweis

`radio-browser.info` bietet mehrere Mirror-Server (`de1.api...`, `at1.api...`,
`nl1.api...` usw.). Für Produktivbetrieb empfiehlt es sich, per DNS-SRV-Record
(`_api._tcp.radio-browser.info`) einen Server dynamisch auszuwählen, statt
fest `de1` zu verwenden.
