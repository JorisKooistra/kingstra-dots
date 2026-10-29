import QtQuick

// Spoelen voor de cassettespeler en de discman: slepen over een balk,
// spoelknoppen vasthouden of pijltjes. Tijdens het slepen of winden toont
// `shown` meteen de nieuwe plek (geen wachten op de speler, dus geen lag);
// na loslaten blijft die plek staan tot de speler hem heeft overgenomen, in
// plaats van even terug te springen.
Item {
    id: seeker

    property real progress: 0
    // In seconden.
    property real length: 0
    property bool canSeek: false
    signal seek(real fraction)

    property bool dragging: false
    property real dragFraction: 0
    property real seekHold: -1
    // -1 terug, 1 vooruit, 0 stil: een spoelknop wordt vastgehouden.
    property int windDir: 0
    readonly property real shown: dragging ? dragFraction : seekHold >= 0 ? seekHold : Math.max(0, Math.min(1, progress))

    onProgressChanged: if (seekHold >= 0 && Math.abs(progress - seekHold) < 0.02) seekHold = -1
    Timer { id: holdTimer; interval: 2500; onTriggered: seeker.seekHold = -1 }

    function clamp(f) { return Math.max(0, Math.min(1, f)); }
    function begin(f) {
        if (!canSeek) return;
        dragFraction = clamp(f);
        dragging = true;
    }
    function move(f) { if (dragging) dragFraction = clamp(f); }
    function commit(f) {
        if (!canSeek) { dragging = false; windDir = 0; return; }
        let target = clamp(f !== undefined ? f : dragFraction);
        windDir = 0;
        seekHold = target;
        holdTimer.restart();
        dragging = false;
        seeker.seek(target);
    }
    function cancel() { dragging = false; windDir = 0; }
    function nudge(seconds) {
        if (!canSeek || length <= 0) return;
        commit(shown + seconds / length);
    }
    function startWind(dir) {
        if (!canSeek || length <= 0) return;
        dragFraction = shown;
        dragging = true;
        windDir = dir;
    }
    function stopWind() { if (windDir !== 0) commit(dragFraction); }

    // Winden: ongeveer 30 seconden muziek per seconde vasthouden, en sneller
    // naarmate je langer vasthoudt.
    property real windTime: 0
    FrameAnimation {
        running: seeker.windDir !== 0
        onRunningChanged: seeker.windTime = 0
        onTriggered: {
            let dt = Math.min(0.1, Math.max(0, frameTime));
            seeker.windTime += dt;
            let secsPerSec = 30 * (1 + Math.min(3, seeker.windTime));
            seeker.dragFraction = seeker.clamp(seeker.dragFraction + seeker.windDir * secsPerSec * dt / Math.max(1, seeker.length));
        }
    }
}
