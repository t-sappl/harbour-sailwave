.pragma library

// How a track history entry is shown (track history page, station info,
// PlayerBar): title, and artist separately.
//
// Artist and title as written by iTunes are used when they were stored -
// that only happens when they match the stream text (see CoverArtCache), so
// iTunes just fixes the spelling (e.g. streams that send everything in
// CAPITALS). Otherwise the stream text "Artist - Title" is split.

function split(raw) {
    var text = raw || "";
    var i = text.indexOf(" - ");
    if (i > 0 && i < text.length - 3) {
        return { artist: text.substring(0, i).trim(), title: text.substring(i + 3).trim() };
    }
    return { artist: "", title: text };
}

// entry: { title (stream text), itunesArtist, itunesTitle }
function parts(entry) {
    if (entry && entry.itunesArtist && entry.itunesTitle) {
        return { artist: entry.itunesArtist, title: entry.itunesTitle };
    }
    return split(entry ? entry.title : "");
}

// Second line: "Artist · Genre · Time" - empty parts are left out
function details(artist, genre, time) {
    var list = [];
    if (artist) list.push(artist);
    if (genre) list.push(genre);
    if (time) list.push(time);
    return list.join(" · ");
}
