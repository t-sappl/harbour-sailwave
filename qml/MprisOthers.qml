// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Nemo.DBus 2.0

// Sailfish has no audio focus: when an app starts playing, other players
// keep playing. So when Sailwave starts (by any route: app, cover, lock
// screen, headset button), this pauses every OTHER MPRIS player that is
// playing at that moment (e.g. a podcast in Sailcast).
//
// (v127) Through plain D-Bus (Nemo.DBus, same code as Sailcast 292): the
// first version used the type MprisManager, which does not exist in
// Amber.Mpris (it is in the older module org.nemomobile.mpris) - "MprisManager
// is not a type", the file never loaded (device log of 9 Nov).
//
// How: the services "org.mpris.MediaPlayer2.*" on the session bus are
// listed (ListNames, every 5 s); the playback status of each is read every
// 2 s (org.freedesktop.DBus.Properties.Get, asynchronous) and kept in
// "status". When Sailwave starts, every player is also asked again at once
// and paused if it answers "Playing" (the kept status can be 2 s old).
// Pause is sent to /org/mpris/MediaPlayer2.
//
// Loaded through a Loader (like MprisIntegration): without Nemo.DBus access
// the app keeps running, just without this function. Everything is logged
// ("MprisOthers: ...") - Sailjail may filter the bus names of other apps.
//
// No loop: only the transition to "playing" pauses others; a paused app
// never starts Sailwave again.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property string ownName: "org.mpris.MediaPlayer2.harbour-sailwave"
    readonly property string prefix: "org.mpris.MediaPlayer2."
    // Foreign players found on the bus
    property var services: []
    // service -> last read "Playing" / "Paused" / "Stopped"
    property var status: ({})

    function isOwn(service) {
        // also covers suffixed instance names (".instance1234")
        return service === ownName || service.indexOf(ownName + ".") === 0
    }

    // --- Services on the bus ---
    DBusInterface {
        id: lister
        bus: DBus.SessionBus
        service: "org.freedesktop.DBus"
        path: "/org/freedesktop/DBus"
        iface: "org.freedesktop.DBus"
    }

    function refreshServices() {
        lister.call("ListNames", [], function(names) {
            var found = []
            for (var i = 0; i < names.length; ++i) {
                var name = "" + names[i]
                if (name.indexOf(root.prefix) === 0 && !root.isOwn(name)) {
                    found.push(name)
                }
            }
            found.sort()
            if (found.join("|") !== root.services.join("|")) {
                console.log("MprisOthers: other players: " + (found.length > 0 ? found.join(", ") : "none"))
                root.services = found
            }
        }, function(error) {
            console.log("MprisOthers: ListNames failed: " + error)
        })
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshServices()
    }

    // --- Status of the others ---
    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: root.services.length > 0
        onTriggered: {
            for (var i = 0; i < players.count; ++i) {
                var e = players.itemAt(i)
                if (e) {
                    e.poll(false)
                }
            }
        }
    }

    function noteStatus(service, value) {
        var now = "" + value
        var before = status[service]
        if (before === now) {
            return
        }
        console.log("MprisOthers: " + service + " " + (before || "?") + " -> " + now)
        status[service] = now
    }

    Repeater {
        id: players
        model: root.services
        delegate: Item {
            id: entry
            property string name: modelData

            DBusInterface {
                id: props
                bus: DBus.SessionBus
                service: entry.name
                path: "/org/mpris/MediaPlayer2"
                iface: "org.freedesktop.DBus.Properties"
            }

            DBusInterface {
                id: ctl
                bus: DBus.SessionBus
                service: entry.name
                path: "/org/mpris/MediaPlayer2"
                iface: "org.mpris.MediaPlayer2.Player"
            }

            // Reads the status; with pauseNow a player that answers
            // "Playing" is paused right away
            function poll(pauseNow) {
                props.typedCall("Get", [
                                    { "type": "s", "value": "org.mpris.MediaPlayer2.Player" },
                                    { "type": "s", "value": "PlaybackStatus" }
                                ], function(value) {
                                    root.noteStatus(entry.name, value)
                                    if (pauseNow && ("" + value) === "Playing") {
                                        entry.pause()
                                    }
                                }, function(error) {
                                    console.log("MprisOthers: status of " + entry.name + " failed: " + error)
                                })
            }

            function pause() {
                console.log("MprisOthers: pausing " + entry.name)
                ctl.call("Pause", [], function() {}, function(error) {
                    console.log("MprisOthers: Pause failed: " + error)
                })
                root.status[entry.name] = "Paused"
            }

            // Pauses a player that was last seen playing; true if so
            function pauseIfPlaying() {
                if (root.status[entry.name] !== "Playing") {
                    return false
                }
                entry.pause()
                return true
            }
        }
    }

    // Pauses all other players that are playing: the ones last seen playing
    // at once (their number is returned), and every player is asked again
    // (the kept status can be 2 s old) and paused if it answers "Playing"
    function pauseOthers() {
        var n = 0
        for (var i = 0; i < players.count; ++i) {
            var e = players.itemAt(i)
            if (e) {
                if (e.pauseIfPlaying()) {
                    ++n
                } else {
                    e.poll(true)
                }
            }
        }
        return n
    }

    // Debounce: a short stop/play that the app causes itself (reconnect after
    // a stall, station change, swapping the stream URL: all use stop()) must
    // not count as a real pause and start, otherwise other players that the
    // user started meanwhile are paused again. A pause by the user
    // (PausedState) is real at once: starting again soon afterwards pauses the
    // others as usual.
    Timer {
        id: settle
        interval: 1500
    }

    // Right after the app start the D-Bus data (services, playback status) may
    // not have arrived yet when the first start happens: one retry
    Timer {
        id: retry
        interval: 700
        onTriggered: {
            if (appWindow.isPlaying) {
                root.pauseOthers()
            }
        }
    }

    Connections {
        target: appWindow
        onIsPlayingChanged: {
            if (appWindow.isPlaying) {
                if (settle.running) {
                    // short restart: pause nothing
                    settle.stop()
                } else if (root.pauseOthers() === 0) {
                    retry.restart()
                }
            } else if (appWindow.isPausedByUser) {
                settle.stop()
            } else {
                settle.restart()
            }
        }
    }

    Component.onCompleted: console.log("MprisOthers: ready (D-Bus)")
}
