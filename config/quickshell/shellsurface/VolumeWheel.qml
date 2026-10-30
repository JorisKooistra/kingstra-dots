import QtQuick
import ".."

// Volumewieltje zoals op een walkman of discman: een geribbelde rol die uit
// het voorpaneel steekt. De ribbels liggen op een echte cilinder (dichter op
// elkaar naar boven en onder) en draaien mee met het volume. Omhoog slepen
// of scrollen is harder; tijdens slepen volgt het wiel de muis, daarna het
// systeem, zodat het niet terugspringt.
Item {
    id: volWheel

    required property var skin
    // 0..1, of onder 0 als het volume onbekend is.
    property real value: -1
    // Plat (Paper): geen schaduw.
    property bool flat: false
    property real viewLean: 0
    signal requested(real value)

    property bool dragging: false
    property real dragValue: 0
    // Na loslaten even het gesleepte volume vasthouden tot het systeem het
    // heeft overgenomen, anders tikt het wiel even terug.
    property real holdValue: -1
    readonly property real shown: dragging ? dragValue : holdValue >= 0 ? holdValue : Math.max(0, Math.min(1, value))
    onValueChanged: if (holdValue >= 0 && Math.abs(value - holdValue) < 0.015) holdValue = -1
    Timer { id: holdTimer; interval: 1200; onTriggered: volWheel.holdValue = -1 }
    enabled: value >= 0
    opacity: enabled ? 1 : 0.45

    // Uitsparing in het paneel.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Math.max(1.5, volWheel.width * 0.08)
        radius: Math.max(2, volWheel.width * 0.25)
        color: volWheel.flat ? "transparent" : Qt.rgba(0, 0, 0, 0.5)
        border.width: volWheel.flat ? 1.5 : 0
        border.color: volWheel.skin.capBorder
    }
    // Zachte schaduw onder de rol op het paneel.
    Rectangle {
        visible: !volWheel.flat
        x: volWheel.width * 0.1 + volWheel.viewLean * volWheel.width * 0.15
        y: volWheel.height * 0.18
        width: volWheel.width
        height: volWheel.height
        radius: volWheel.width * 0.3
        color: Qt.rgba(0, 0, 0, 0.28)
    }
    // De rol: licht van boven, dus de bovenkant van de cilinder is het
    // lichtst en de onderkant verdwijnt in de schaduw.
    Rectangle {
        id: drum
        anchors.fill: parent
        radius: Math.min(width, height) * 0.22
        clip: true
        border.width: volWheel.flat ? 1.5 : 1
        border.color: volWheel.skin.capBorder
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.darker(volWheel.skin.capB, volWheel.flat ? 1 : 1.9) }
            GradientStop { position: 0.28; color: volWheel.flat ? volWheel.skin.capA : Qt.lighter(volWheel.skin.capA, 1.12) }
            GradientStop { position: 0.55; color: volWheel.skin.capB }
            GradientStop { position: 1.0; color: Qt.darker(volWheel.skin.capB, volWheel.flat ? 1 : 2.4) }
        }
        Repeater {
            model: 16
            Rectangle {
                required property int index
                readonly property real phi: (index / 16 + volWheel.shown * 0.6) * Math.PI * 2
                readonly property real facing: Math.cos(phi)
                visible: facing > 0.08
                x: 1
                width: drum.width - 2
                height: Math.max(1, drum.height * 0.035 * facing)
                y: drum.height / 2 - Math.sin(phi) * drum.height * 0.48 - height / 2
                color: Qt.rgba(0, 0, 0, volWheel.flat ? 0.6 : 0.42 * facing)
                Rectangle {
                    visible: !volWheel.flat
                    y: parent.height
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.16 * parent.facing)
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -10
        cursorShape: Qt.SizeVerCursor
        preventStealing: true
        property real startY: 0
        property real startValue: 0
        onPressed: mouse => {
            startY = mouse.y;
            startValue = volWheel.shown;
            volWheel.dragValue = startValue;
            volWheel.dragging = true;
        }
        onPositionChanged: mouse => {
            if (!pressed) return;
            let v = Math.max(0, Math.min(1, startValue + (startY - mouse.y) / Math.max(40, volWheel.height * 2.5)));
            v = Math.round(v * 100) / 100;
            if (v === volWheel.dragValue) return;
            volWheel.dragValue = v;
            volWheel.requested(v);
        }
        onReleased: {
            volWheel.holdValue = volWheel.dragValue;
            holdTimer.restart();
            volWheel.dragging = false;
        }
        onCanceled: volWheel.dragging = false
        onWheel: ev => {
            let v = Math.max(0, Math.min(1, Math.round((volWheel.shown + (ev.angleDelta.y > 0 ? 0.05 : -0.05)) * 100) / 100));
            volWheel.holdValue = v;
            holdTimer.restart();
            volWheel.requested(v);
        }
    }
}
