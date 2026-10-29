import QtQuick

// Spoel in een cassette: een tapepakket dat groeit of krimpt met de
// voortgang, en daarin de witte naaf met tandjes. Alleen de naaf draait
// (rotation), het pakket ziet er gedraaid hetzelfde uit en het licht erop
// staat stil. De naaf wordt één keer getekend.
Item {
    id: reel

    // Straal van het tapepakket en van de naaf, in pixels.
    property real packRadius: 20
    property real hubRadius: 8
    property real angle: 0
    property color tape: "#3a2618"
    property color hub: "#eeeeee"
    property color hubShade: "#999999"
    property bool flat: false
    property color ink: "black"

    width: hubRadius * 2
    height: hubRadius * 2

    // Tapepakket: donker, met een zachte glans boven (licht staat stil).
    Rectangle {
        anchors.centerIn: parent
        width: reel.packRadius * 2
        height: width
        radius: width / 2
        visible: reel.packRadius > reel.hubRadius * 1.02
        border.width: reel.flat ? 1.5 : 1
        border.color: reel.flat ? reel.ink : Qt.darker(reel.tape, 1.5)
        gradient: Gradient {
            GradientStop { position: 0.0; color: reel.flat ? reel.tape : Qt.lighter(reel.tape, 1.45) }
            GradientStop { position: 0.45; color: reel.tape }
            GradientStop { position: 1.0; color: reel.flat ? reel.tape : Qt.darker(reel.tape, 1.35) }
        }
        // Wikkelranden.
        Rectangle {
            visible: !reel.flat && parent.width > reel.hubRadius * 3
            anchors.centerIn: parent
            width: (reel.packRadius + reel.hubRadius) * 1.0
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.22)
        }
    }
    // Naaf met zes tandjes; draait mee.
    Canvas {
        id: hubCanvas
        anchors.centerIn: parent
        width: Math.ceil(reel.hubRadius * 2) + 2
        height: width
        rotation: reel.angle
        readonly property color fill: reel.hub
        readonly property color shade: reel.hubShade
        onFillChanged: requestPaint()
        onShadeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let c = width / 2, r = c - 1;
            ctx.beginPath();
            ctx.arc(c, c, r, 0, Math.PI * 2);
            ctx.fillStyle = fill;
            ctx.fill();
            ctx.lineWidth = Math.max(1, r * 0.08);
            ctx.strokeStyle = reel.flat ? reel.ink : shade;
            ctx.stroke();
            // Gat met zes tandjes naar binnen.
            let hole = r * 0.58;
            ctx.beginPath();
            ctx.arc(c, c, hole, 0, Math.PI * 2);
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.55);
            ctx.fill();
            ctx.fillStyle = fill;
            for (let i = 0; i < 6; i++) {
                let a = i / 6 * Math.PI * 2;
                ctx.save();
                ctx.translate(c, c);
                ctx.rotate(a);
                ctx.fillRect(hole * 0.55, -r * 0.09, hole * 0.5, r * 0.18);
                ctx.restore();
            }
            // Drie kleine gaatjes in de flens.
            for (let i = 0; i < 3; i++) {
                let a = i / 3 * Math.PI * 2 + 0.5;
                ctx.beginPath();
                ctx.arc(c + Math.cos(a) * r * 0.8, c + Math.sin(a) * r * 0.8, r * 0.07, 0, Math.PI * 2);
                ctx.fillStyle = shade;
                ctx.fill();
            }
        }
    }
}
