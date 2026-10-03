.pragma library

// Keeps an opening context menu above the PlayerBar. Silica scrolls a
// list so that an opened menu is inside the list's area - but the global
// PlayerBar lies on top of the lower part of that area, so a menu of the
// bottom row ended up hidden behind it. Called while the list item grows
// (menu expanding), so the list follows the animation smoothly.
function ensureAboveBar(item, barHeight) {
    if (!item || barHeight <= 0) {
        return;
    }
    var flick = item.parent;
    while (flick && (flick.contentY === undefined || flick.contentHeight === undefined)) {
        flick = flick.parent;
    }
    if (!flick) {
        return;
    }
    var bottom = item.mapToItem(flick, 0, item.height).y;
    var limit = flick.height - barHeight;
    if (bottom <= limit) {
        return;
    }
    var maxY = flick.originY + flick.contentHeight - flick.height;
    flick.contentY = Math.min(maxY, flick.contentY + bottom - limit);
}
