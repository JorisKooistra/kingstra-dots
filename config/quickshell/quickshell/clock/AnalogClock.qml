import QtQuick

Item {
    id: root
    required property var shell
    required property var mocha
    property bool showSecondHand: false

    readonly property string activeTheme: String(shell.activeThemeName || "botanical").toLowerCase()
    readonly property bool botanicalStyle: activeTheme === "botanical"

    property date now: new Date()
    readonly property real hourAngle: ((now.getHours() % 12) + now.getMinutes() / 60 + now.getSeconds() / 3600) * 30
    readonly property real minuteAngle: (now.getMinutes() + now.getSeconds() / 60) * 6
    readonly property real secondAngle: now.getSeconds() * 6

    readonly property int clockSize: shell.s(botanicalStyle ? 40 : 34)
    implicitWidth: clockSize
    implicitHeight: clockSize

    readonly property color outerRingColor: botanicalStyle
                                           ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.72)
                                           : Qt.rgba(mocha.overlay2.r, mocha.overlay2.g, mocha.overlay2.b, 0.60)
    readonly property color innerDialColor: botanicalStyle
                                           ? Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.70)
                                           : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.72)
    readonly property color minuteTickColor: botanicalStyle
                                            ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.42)
                                            : Qt.rgba(mocha.overlay2.r, mocha.overlay2.g, mocha.overlay2.b, 0.32)
    readonly property color hourTickColor: botanicalStyle
                                          ? Qt.rgba(mocha.peach.r, mocha.peach.g, mocha.peach.b, 0.88)
                                          : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.72)
    readonly property color hourHandColor: botanicalStyle ? mocha.peach : mocha.text
    readonly property color minuteHandColor: botanicalStyle ? mocha.green : mocha.blue
    readonly property color secondHandColor: mocha.red
    readonly property color capColor: botanicalStyle ? mocha.yellow : mocha.text

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    onNowChanged: clockCanvas.requestPaint()
    onWidthChanged: clockCanvas.requestPaint()
    onHeightChanged: clockCanvas.requestPaint()
    onOuterRingColorChanged: clockCanvas.requestPaint()
    onInnerDialColorChanged: clockCanvas.requestPaint()
    onMinuteTickColorChanged: clockCanvas.requestPaint()
    onHourTickColorChanged: clockCanvas.requestPaint()
    onHourHandColorChanged: clockCanvas.requestPaint()
    onMinuteHandColorChanged: clockCanvas.requestPaint()
    onSecondHandColorChanged: clockCanvas.requestPaint()
    onCapColorChanged: clockCanvas.requestPaint()
    onShowSecondHandChanged: clockCanvas.requestPaint()

    Canvas {
        id: clockCanvas
        anchors.fill: parent
        antialiasing: true
        smooth: true

        onPaint: {
            let ctx = getContext("2d");
            let w = width;
            let h = height;
            let cx = w / 2;
            let cy = h / 2;
            let radius = Math.min(w, h) / 2;

            function rgba(c) {
                return Qt.rgba(c.r, c.g, c.b, c.a !== undefined ? c.a : 1);
            }

            function drawHand(angleDeg, lengthFactor, backFactor, halfWidth, color, useRoundCap) {
                let angle = (angleDeg - 90) * Math.PI / 180.0;
                let ux = Math.cos(angle);
                let uy = Math.sin(angle);
                let px = -uy;
                let py = ux;
                let front = radius * lengthFactor;
                let back = radius * backFactor;

                ctx.beginPath();
                ctx.moveTo(cx + px * halfWidth, cy + py * halfWidth);
                ctx.lineTo(cx + ux * front, cy + uy * front);
                ctx.lineTo(cx - px * halfWidth, cy - py * halfWidth);
                ctx.lineTo(cx - ux * back, cy - uy * back);
                ctx.closePath();
                ctx.fillStyle = color;
                ctx.fill();

                if (useRoundCap) {
                    ctx.beginPath();
                    ctx.arc(cx + ux * front, cy + uy * front, Math.max(1.1, halfWidth * 0.62), 0, Math.PI * 2);
                    ctx.fillStyle = color;
                    ctx.fill();
                }
            }

            ctx.reset();
            ctx.clearRect(0, 0, w, h);

            // Outer ring
            ctx.beginPath();
            ctx.arc(cx, cy, radius - 0.9, 0, Math.PI * 2);
            ctx.fillStyle = rgba(root.outerRingColor);
            ctx.fill();

            // Inner dial
            ctx.beginPath();
            ctx.arc(cx, cy, radius - 2.6, 0, Math.PI * 2);
            ctx.fillStyle = rgba(root.innerDialColor);
            ctx.fill();

            // Minute and hour ticks
            for (let i = 0; i < 60; i += 1) {
                let angle = (i * 6 - 90) * Math.PI / 180.0;
                let isHour = (i % 5) === 0;
                let tickLen = isHour ? radius * 0.14 : radius * 0.07;
                let tickWidth = isHour ? Math.max(1.6, radius * 0.038) : Math.max(0.7, radius * 0.018);
                let outer = radius - 4.0;
                let inner = outer - tickLen;
                let ux = Math.cos(angle);
                let uy = Math.sin(angle);
                let px = -uy;
                let py = ux;

                ctx.beginPath();
                ctx.moveTo(cx + ux * inner + px * tickWidth, cy + uy * inner + py * tickWidth);
                ctx.lineTo(cx + ux * outer + px * tickWidth, cy + uy * outer + py * tickWidth);
                ctx.lineTo(cx + ux * outer - px * tickWidth, cy + uy * outer - py * tickWidth);
                ctx.lineTo(cx + ux * inner - px * tickWidth, cy + uy * inner - py * tickWidth);
                ctx.closePath();
                ctx.fillStyle = rgba(isHour ? root.hourTickColor : root.minuteTickColor);
                ctx.fill();
            }

            // Botanical accent petals at cardinal points
            if (root.botanicalStyle) {
                for (let p = 0; p < 4; p += 1) {
                    let a = (p * 90 - 90) * Math.PI / 180.0;
                    let x = cx + Math.cos(a) * (radius * 0.78);
                    let y = cy + Math.sin(a) * (radius * 0.78);
                    ctx.beginPath();
                    ctx.arc(x, y, Math.max(0.8, radius * 0.048), 0, Math.PI * 2);
                    ctx.fillStyle = rgba(Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.68));
                    ctx.fill();
                }
            }

            drawHand(root.hourAngle, 0.46, 0.08, Math.max(1.3, radius * 0.055), rgba(root.hourHandColor), true);
            drawHand(root.minuteAngle, 0.68, 0.10, Math.max(1.0, radius * 0.036), rgba(root.minuteHandColor), true);

            if (root.showSecondHand) {
                drawHand(root.secondAngle, 0.78, 0.14, Math.max(0.6, radius * 0.017), rgba(root.secondHandColor), false);
            }

            // Center cap
            ctx.beginPath();
            ctx.arc(cx, cy, Math.max(1.8, radius * 0.105), 0, Math.PI * 2);
            ctx.fillStyle = rgba(root.capColor);
            ctx.fill();
        }
    }
}
