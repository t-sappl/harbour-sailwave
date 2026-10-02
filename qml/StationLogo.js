.pragma library

// Shared station logo resolution.
//
// Used by StationIcon (every logo inside the app) AND by CoverArtCache (the
// image for MPRIS / the lock screen), so that both always pick the same logo
// from the same sources in the same order:
//
//   1. the station's favicon from radio-browser.info
//   2. Google's favicon service for the station homepage (a manually
//      corrected homepage from the station info page takes precedence)
//
// Whether a URL is known to be broken is checked by the callers
// (appWindow.isIconUrlBroken), because that state lives in the app window.

// Extracts the host name from a homepage URL ("https://oe3.orf.at/player"
// -> "oe3.orf.at"). Tolerates missing schemes and surrounding whitespace.
function extractDomain(url) {
    if (!url || typeof url !== "string") return "";
    var cleanUrl = url.trim();

    // Add http:// if the scheme is missing
    if (cleanUrl.indexOf("://") === -1) {
        cleanUrl = "http://" + cleanUrl;
    }

    var start = cleanUrl.indexOf("://") + 3;
    var end = cleanUrl.indexOf("/", start);
    if (end === -1) end = cleanUrl.indexOf("?", start);
    if (end === -1) end = cleanUrl.indexOf("#", start);

    var host = end === -1 ? cleanUrl.substring(start) : cleanUrl.substring(start, end);
    return host.split("/")[0].trim();
}

// The homepage to use for a station: a manual override wins over the value
// from radio-browser.info.
function resolveHomepage(homepage, override) {
    return (override && override.length > 0) ? override : (homepage || "");
}

// Google favicon URL for a homepage, "" if no domain can be extracted.
// size: requested edge length in pixels (Google returns at most what exists).
function googleFaviconUrl(homepage, size) {
    var domain = extractDomain(homepage);
    return domain.length > 0
            ? "https://www.google.com/s2/favicons?domain=" + domain + "&sz=" + (size || 64)
            : "";
}
