// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Amber.Mpris 1.0

// Registers the app as an MPRIS player (org.mpris.MediaPlayer2.*) so that
// Sailfish OS shows it on the lock screen, in the multitasking view and
// for Bluetooth/headset/car controls with station/title, play/pause and
// next/previous favourite - just like the built-in music apps. Sailfish automatically detects when
// a player has the status "Paused" and then shows it as the "recently
// used media app" with a play button, even when nothing is playing.
// Docs: https://sailfishos.org/develop/docs/amber-qml-plugin-mpris/
//
// Cover art comes in via appWindow.currentCoverArtUrl (see CoverArtCache.qml)
// as a plain string property - MprisPlayer itself deliberately has NO
// visual children (no Image/Canvas in here): on the first attempt that
// broke the whole MPRIS registration.

MprisPlayer {
    id: mprisPlayer

    // serviceName becomes "org.mpris.MediaPlayer2.harbour-sailwave" on D-Bus
    // (kept after the package rename - it matches the Sailjail application
    // name harbour-sailwave)
    serviceName: "harbour-sailwave"
    identity: "Sailwave"
    // Name of the .desktop file (package name since 1.1) - the lock screen
    // takes the icon from it
    desktopEntry: "harbour-sailwave-radio"

    canControl: true
    canPlay: appWindow.currentStation !== null
    canPause: appWindow.currentStation !== null
    // Only when there is another favourite to switch to (same rule as the
    // cover action), so the lock screen does not show dead buttons
    canGoNext: appWindow.canPlayNextFavorite
    canGoPrevious: appWindow.canPlayNextFavorite
    canSeek: false
    canQuit: false
    canRaise: false

    // Deliberately NOT Mpris.Stopped while a station is "remembered" (even
    // when paused) - Stopped makes the player disappear from the lock screen,
    // Paused keeps it visible as "recently used" with a play button, which
    // is exactly the desired behaviour.
    playbackStatus: {
        if (!appWindow.currentStation) {
            return Mpris.Stopped
        }
        return appWindow.isPlaying ? Mpris.Playing : Mpris.Paused
    }

    // Station name as "artist", current song title (if any, otherwise the
    // station name again) as "title" - so the lock screen shows
    // "song title - station name", or just the station name without ICY metadata.
    metaData.title: appWindow.currentTrackDisplay.length > 0
                    ? appWindow.currentTrackDisplay
                    : (appWindow.currentStation ? appWindow.currentStation.name : "")
    metaData.contributingArtist: appWindow.currentStation ? [appWindow.currentStation.name] : []
    metaData.artUrl: appWindow.currentCoverArtUrl

    onPlayRequested: {
        if (!appWindow.isPlaying && appWindow.currentStation) {
            appWindow.togglePlayback()
        }
    }
    onPauseRequested: {
        if (appWindow.isPlaying) {
            appWindow.togglePlayback()
        }
    }
    // Next/previous favourite (headset, lock screen, car) - also while
    // paused: switching then starts the new station, like the cover action
    onNextRequested: appWindow.playNextFavorite()
    onPreviousRequested: appWindow.playPrevFavorite()
    onPlayPauseRequested: appWindow.togglePlayback()
    onStopRequested: appWindow.stopPlayback()
}
