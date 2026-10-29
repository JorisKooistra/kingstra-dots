import QtQuick
import QtQuick.Shapes
import ".."

// Volumewiel in de zijkant van een staande walkman: een geribbelde schijf
// waarvan de as van voor naar achter loopt, zoals op een echte speler. Je
// ziet de voorkant van de schijf en de rand met ribbels, die langs de diepte
// van de kast lopen (dx, dy: de verschuiving naar achteren in beeld). Het
// deel dat in de kast zit, knipt de ouder weg. Omhoog slepen of scrollen is
// harder; tijdens slepen volgt het wiel de muis, daarna het systeem, zodat
// het niet terugspringt.
Item {
    id: sideWheel

    required property var skin
    property real value: -1
    property bool flat: false
    // Straal (in beeld als ellips rx, ry) en dikte (verschuiving naar
    // achteren in beeld, dy omhoog positief).
    property real r: 30
    property real rx: r
    property real ry: r
    property real dx: 6
    property real dy: 8
    signal requested(real value)

    property bool dragging: false
    property real dragValue: 0
    property real holdValue: -1
    readonly property real shown: dragging ? dragValue : holdValue >= 0 ? holdValue : Math.max(0, Math.min(1, value))
    onValueChanged: if (holdValue >= 0 && Math.abs(value - holdValue) < 0.015) holdValue = -1
    Timer { id: holdTimer; interval: 1200; onTriggered: sideWheel.holdValue = -1 }
    enabled: value >= 0
    opacity: enabled ? 1 : 0.5

    width: 2 * rx + dx
    height: 2 * ry + dy
    // Middens van voor- en achterkant.
    readonly property real fx: rx
    readonly property real fy: ry + dy
    readonly property real bx: rx + dx
    readonly property real by: ry
    // Raakpunten van de rand evenwijdig aan de as (in beeld).
    readonly property real len: Math.max(0.001, Math.sqrt(dx * dx + dy * dy))
    readonly property real phi: Math.atan2(-ry * dx, rx * -dy)
    readonly property real nx: rx * Math.cos(phi)
    readonly property real ny: ry * Math.sin(phi)

    // Metaal of kunststof van het wiel; standaard de knopkleuren.
    property color face: skin.capA
    property color rim: skin.capB
    readonly property color rimA: Qt.lighter(rim, flat ? 1 : 1.25)
    readonly property color rimB: Qt.darker(rim, flat ? 1 : 1.5)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Achterkant van de schijf.
        ShapePath {
            strokeWidth: sideWheel.flat ? 1.5 : 0
            strokeColor: sideWheel.flat ? sideWheel.skin.capBorder : "transparent"
            fillColor: sideWheel.rimB
            PathAngleArc { centerX: sideWheel.bx; centerY: sideWheel.by; radiusX: sideWheel.rx; radiusY: sideWheel.ry; startAngle: 0; sweepAngle: 360 }
        }
        // Rand: verbindt voor- en achterkant langs de raaklijnen.
        ShapePath {
            strokeWidth: sideWheel.flat ? 1.5 : 0
            strokeColor: sideWheel.flat ? sideWheel.skin.capBorder : "transparent"
            fillGradient: LinearGradient {
                x1: sideWheel.fx - sideWheel.nx; y1: sideWheel.fy - sideWheel.ny
                x2: sideWheel.fx + sideWheel.nx; y2: sideWheel.fy + sideWheel.ny
                GradientStop { position: 0.0; color: sideWheel.rimA }
                GradientStop { position: 0.5; color: sideWheel.rim }
                GradientStop { position: 1.0; color: sideWheel.rimB }
            }
            startX: sideWheel.fx - sideWheel.nx; startY: sideWheel.fy - sideWheel.ny
            PathLine { x: sideWheel.bx - sideWheel.nx; y: sideWheel.by - sideWheel.ny }
            PathLine { x: sideWheel.bx + sideWheel.nx; y: sideWheel.by + sideWheel.ny }
            PathLine { x: sideWheel.fx + sideWheel.nx; y: sideWheel.fy + sideWheel.ny }
        }
        // Ribbels op de rand: alleen op het deel dat naar je toe staat, en
        // ze draaien mee met het volume.
        ShapePath {
            strokeWidth: Math.max(1, sideWheel.r * 0.035)
            strokeColor: Qt.rgba(0, 0, 0, sideWheel.flat ? 0.7 : 0.45)
            fillColor: "transparent"
            PathSvg {
                path: {
                    let d = "", n = 28, ax = sideWheel.dx / sideWheel.len, ay = -sideWheel.dy / sideWheel.len;
                    for (let i = 0; i < n; i++) {
                        let a = (i / n + sideWheel.shown * 0.5) * Math.PI * 2;
                        let cx = Math.cos(a), cy = Math.sin(a);
                        // Zichtbaar als de rand naar de achterkant wijst (kant van de as).
                        if (cx / sideWheel.rx * ax + cy / sideWheel.ry * ay <= 0.05 / Math.min(sideWheel.rx, sideWheel.ry)) continue;
                        let x = sideWheel.fx + sideWheel.rx * cx, y = sideWheel.fy + sideWheel.ry * cy;
                        d += " M " + x.toFixed(1) + " " + y.toFixed(1) + " L " + (x + sideWheel.dx).toFixed(1) + " " + (y - sideWheel.dy).toFixed(1);
                    }
                    return d === "" ? "M 0 0" : d;
                }
            }
        }
        // Voorkant van de schijf met een ring en een groefje.
        ShapePath {
            strokeWidth: sideWheel.flat ? 1.5 : 1
            strokeColor: sideWheel.skin.capBorder
            fillGradient: LinearGradient {
                x1: sideWheel.fx - sideWheel.rx; y1: sideWheel.fy - sideWheel.ry
                x2: sideWheel.fx + sideWheel.rx; y2: sideWheel.fy + sideWheel.ry
                GradientStop { position: 0.0; color: Qt.lighter(sideWheel.face, sideWheel.flat ? 1 : 1.15) }
                GradientStop { position: 1.0; color: Qt.darker(sideWheel.face, sideWheel.flat ? 1 : 1.25) }
            }
            PathAngleArc { centerX: sideWheel.fx; centerY: sideWheel.fy; radiusX: sideWheel.rx; radiusY: sideWheel.ry; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeWidth: Math.max(1, sideWheel.r * 0.04)
            strokeColor: Qt.rgba(0, 0, 0, 0.25)
            fillColor: "transparent"
            PathAngleArc { centerX: sideWheel.fx; centerY: sideWheel.fy; radiusX: sideWheel.rx * 0.72; radiusY: sideWheel.ry * 0.72; startAngle: 0; sweepAngle: 360 }
        }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        cursorShape: Qt.SizeVerCursor
        preventStealing: true
        property real startY: 0
        property real startValue: 0
        onPressed: mouse => {
            startY = mouse.y;
            startValue = sideWheel.shown;
            sideWheel.dragValue = startValue;
            sideWheel.dragging = true;
        }
        onPositionChanged: mouse => {
            if (!pressed) return;
            let v = Math.max(0, Math.min(1, startValue + (startY - mouse.y) / Math.max(60, sideWheel.r * 4)));
            v = Math.round(v * 100) / 100;
            if (v === sideWheel.dragValue) return;
            sideWheel.dragValue = v;
            sideWheel.requested(v);
        }
        onReleased: {
            sideWheel.holdValue = sideWheel.dragValue;
            holdTimer.restart();
            sideWheel.dragging = false;
        }
        onCanceled: sideWheel.dragging = false
        onWheel: ev => {
            let v = Math.max(0, Math.min(1, Math.round((sideWheel.shown + (ev.angleDelta.y > 0 ? 0.05 : -0.05)) * 100) / 100));
            sideWheel.holdValue = v;
            holdTimer.restart();
            sideWheel.requested(v);
        }
    }
}
