import QtQuick 2.6

// Sleep timer: pauses playback after an adjustable time, optionally
// fading the volume out slowly during the last seconds. The volume is
// restored afterwards so that the next playback starts at normal
// volume.
//
// Works with the wall clock instead of counting seconds - if the system
// ever delays the timer in the background, the end time is still correct.

Item {
    id: sleepTimer

    // MediaPlayer whose volume is faded out
    property var mediaPlayer: null
    property bool fadeOut: true
    property int fadeDurationMs: 30000

    property bool active: false
    property real endTime: 0
    property int remainingMinutes: 0

    // Emitted at the end - pause playback there
    signal expired()

    property real _savedVolume: 1.0
    property bool _fading: false

    function start(minutes) {
        cancel()
        _savedVolume = mediaPlayer ? mediaPlayer.volume : 1.0
        endTime = Date.now() + minutes * 60000
        active = true
        tick()
    }

    function cancel() {
        if (_fading) {
            fadeAnimation.stop()
            _fading = false
            if (mediaPlayer) {
                mediaPlayer.volume = _savedVolume
            }
        }
        active = false
        remainingMinutes = 0
    }

    function tick() {
        var left = endTime - Date.now()
        remainingMinutes = Math.max(0, Math.ceil(left / 60000))
        if (left <= 0) {
            finish()
            return
        }
        if (fadeOut && !_fading && left <= fadeDurationMs && mediaPlayer) {
            _fading = true
            fadeAnimation.from = mediaPlayer.volume
            fadeAnimation.duration = left
            fadeAnimation.start()
        }
    }

    function finish() {
        fadeAnimation.stop()
        active = false
        remainingMinutes = 0
        expired()
        if (mediaPlayer) {
            mediaPlayer.volume = _savedVolume
        }
        _fading = false
    }

    Timer {
        interval: 1000
        repeat: true
        running: sleepTimer.active
        onTriggered: sleepTimer.tick()
    }

    NumberAnimation {
        id: fadeAnimation
        target: sleepTimer.mediaPlayer
        property: "volume"
        to: 0
    }
}
