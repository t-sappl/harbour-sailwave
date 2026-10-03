// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// How a track history entry is shown (track history page, station info,
// PlayerBar): title, and artist separately.
//
// Artist and title as written by iTunes are used when they were stored -
// that only happens when they match the stream text (see CoverArtCache), so
// iTunes just fixes the spelling (e.g. streams that send everything in
// CAPITALS). Otherwise the stream text "Artist - Title" is split.

// Some stations send multi-line titles. clean() keeps the line breaks (the
// track history shows such a title on two lines, as the station meant it)
// but tidies them up: \r\n / \r become \n, spaces and tabs inside a line
// become one space, empty lines are dropped. Applied at the source
// (rawTrackTitle) and when shown (older history entries, iTunes values).
function clean(text) {
    var lines = String(text || "").split(/\r\n|\r|\n/);
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/\s+/g, " ").trim();
        if (line.length > 0) out.push(line);
    }
    return out.join("\n");
}

// Everything on one line - for places with room for a single line only
// (PlayerBar, app cover, lock screen/MPRIS, previews) and the iTunes search
function oneLine(text) {
    return String(text || "").replace(/\s+/g, " ").trim();
}

function split(raw) {
    var text = clean(raw);
    var i = text.indexOf(" - ");
    if (i > 0 && i < text.length - 3) {
        return { artist: text.substring(0, i).trim(), title: text.substring(i + 3).trim() };
    }
    return { artist: "", title: text };
}

// entry: { title (stream text), itunesArtist, itunesTitle }
function parts(entry) {
    if (entry && entry.itunesArtist && entry.itunesTitle) {
        return { artist: clean(entry.itunesArtist), title: clean(entry.itunesTitle) };
    }
    return split(entry ? entry.title : "");
}

// Second line: "Artist · Genre · Time" - empty parts are left out
function details(artist, genre, time) {
    var list = [];
    if (artist) list.push(oneLine(artist));
    if (genre) list.push(genre);
    if (time) list.push(time);
    return list.join(" · ");
}
