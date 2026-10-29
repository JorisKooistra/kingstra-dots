import QtQuick
import QtQuick.Effects
import ".."

// Bovenkant van een direct-drive draaitafel, gedeeld door de mediakaart op
// het bureaublad (klein, plat) en VinylStage (groot, in perspectief): grote
// draaischijf links, armvoet rechtsboven, pitch rechtsonder, start/stop en
// toerental linksonder. De afwerking volgt het thema (skin).
Item {
    id: table

    required property var mocha
    property color accent: mocha.primary
    property string artUrl: ""
    property string trackKey: ""
    property bool playing: false
    property bool tracking: false
    property bool canSeek: false
    property real progress: 0
    // Kleine uitvoering: geen merk- en pitchtekst, geen 33/45.
    property bool compact: false
    property alias vinyl: vinyl

    signal togglePlay()
    signal seek(real fraction)

    // Uitvoering per thema: Organic walnoot met messing, Neon zwart glas met
    // lichtlijnen, Paper inkt op papier, de rest geborsteld en neutraal.
    property string look: {
        let f = ThemeConfig.styleFamily;
        return f === "organic" ? "wood" : f === "neon" ? "neon" : f === "paper" ? "paper" : "mono";
    }
    readonly property var skin: {
        let m = mocha, a = accent;
        let ink = m.text;
        if (look === "wood") return {
            plinthA: "#7a4a2b", plinthB: "#55311b", border: "#a8764a", borderW: 2, radius: 18,
            frontA: "#4a2a17", frontB: "#2e190d", frontEdge: "#c9a55f",
            capA: "#f1e8d4", capB: "#d6c9ac", capHover: "#fff8e8", capSide: "#7d6c50",
            capText: "#3a2616", capBorder: "#b39f7a", lit: "#ffb347",
            dispBg: "#1a1008", dispText: "#ffb347", dispBorder: "#6b4a2a",
            brand: "KINGSTRA · WALNUT", brandColor: Qt.rgba(0.93, 0.85, 0.68, 0.7),
            screw: "#c9a55f", track: Qt.rgba(1, 0.92, 0.78, 0.16), fill: "#ffb347",
            needle: "#c9a55f", hint: "#e8d3a8"
        };
        if (look === "neon") return {
            plinthA: "#0b1122", plinthB: "#03050a", border: a, borderW: 1.5, radius: 6,
            frontA: "#070a14", frontB: "#020308", frontEdge: a,
            capA: "#0d1426", capB: "#060a14", capHover: "#14203a", capSide: "#000000",
            capText: a, capBorder: Qt.rgba(a.r, a.g, a.b, 0.55), lit: m.pink,
            dispBg: "#000000", dispText: a, dispBorder: Qt.rgba(a.r, a.g, a.b, 0.6),
            brand: "KINGSTRA // NEON DRIVE", brandColor: Qt.rgba(a.r, a.g, a.b, 0.75),
            screw: a, track: Qt.rgba(a.r, a.g, a.b, 0.14), fill: a,
            needle: a, hint: a
        };
        if (look === "paper") return {
            plinthA: m.base, plinthB: m.base, border: ink, borderW: 2, radius: 8,
            frontA: Qt.darker(m.base, 1.04), frontB: Qt.darker(m.base, 1.08), frontEdge: ink,
            capA: m.base, capB: m.base, capHover: Qt.tint(m.base, Qt.rgba(a.r, a.g, a.b, 0.15)), capSide: ink,
            capText: ink, capBorder: ink, lit: a,
            dispBg: ink, dispText: m.base, dispBorder: ink,
            brand: "kingstra — platenspeler", brandColor: Qt.rgba(ink.r, ink.g, ink.b, 0.7),
            screw: ink, track: Qt.rgba(ink.r, ink.g, ink.b, 0.15), fill: ink,
            needle: ink, hint: ink
        };
        return {
            plinthA: Qt.lighter(m.surface0, 1.18), plinthB: m.surface0,
            border: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.16), borderW: 1,
            radius: Math.max(14, ThemeConfig.styleWidgetRadius + 6),
            frontA: Qt.darker(m.surface0, 1.25), frontB: Qt.darker(m.surface0, 1.7),
            frontEdge: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.18),
            capA: Qt.lighter(m.surface1, 1.1), capB: m.surface1, capHover: Qt.lighter(m.surface1, 1.25),
            capSide: Qt.darker(m.surface1, 1.6), capText: m.text,
            capBorder: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.14), lit: a,
            dispBg: Qt.rgba(0, 0, 0, 0.55), dispText: a, dispBorder: Qt.rgba(a.r, a.g, a.b, 0.25),
            brand: "KINGSTRA · DIRECT DRIVE", brandColor: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.45),
            screw: m.overlay1, track: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.12), fill: a,
            needle: m.overlay2, hint: m.subtext0
        };
    }

    property int rpm: 33
    // Pitch in procent, -8..8 zoals op een echte draaitafel.
    property real pitch: 0

    Rectangle {
        id: plinth
        anchors.fill: parent
        radius: table.compact ? Math.min(10, table.skin.radius) : table.skin.radius
        border.width: table.skin.borderW
        border.color: table.skin.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: table.skin.plinthA }
            GradientStop { position: 1.0; color: table.skin.plinthB }
        }

        // Walnoot: getekende nerf met een paar noesten, steeds dezelfde.
        Canvas {
            id: grain
            anchors.fill: parent
            anchors.margins: 3
            visible: table.look === "wood"
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                let seed = 7;
                function rnd() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }
                let w = width, h = height;
                for (let i = 0; i < 70; i++) {
                    let y0 = rnd() * h;
                    let amp = 2 + rnd() * 9;
                    let freq = 0.6 + rnd() * 1.6;
                    let phase = rnd() * 6.28;
                    ctx.beginPath();
                    for (let x = 0; x <= w; x += 12) {
                        let y = y0 + Math.sin(x / w * Math.PI * 2 * freq + phase) * amp
                            + Math.sin(x / w * 17 + i) * 1.2;
                        if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    let dark = rnd() < 0.7;
                    ctx.strokeStyle = dark ? Qt.rgba(0.16, 0.08, 0.03, 0.10 + rnd() * 0.16)
                                           : Qt.rgba(1, 0.86, 0.66, 0.04 + rnd() * 0.06);
                    ctx.lineWidth = 0.6 + rnd() * 1.8;
                    ctx.stroke();
                }
                for (let k = 0; k < 3; k++) {
                    let kx = w * (0.15 + rnd() * 0.7), ky = h * (0.1 + rnd() * 0.8);
                    for (let r = 0; r < 5; r++) {
                        ctx.beginPath();
                        ctx.ellipse(kx - (8 + r * 6), ky - (3 + r * 2.2), (8 + r * 6) * 2, (3 + r * 2.2) * 2);
                        ctx.strokeStyle = Qt.rgba(0.14, 0.07, 0.02, 0.22 - r * 0.035);
                        ctx.lineWidth = 1;
                        ctx.stroke();
                    }
                }
            }
        }

        // Neon: raster van lichtlijnen en hoekhaken.
        Canvas {
            anchors.fill: parent
            visible: table.look === "neon"
            readonly property color line: table.accent
            onLineChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                let step = Math.max(24, width / 28);
                ctx.strokeStyle = Qt.rgba(line.r, line.g, line.b, 0.07);
                ctx.lineWidth = 1;
                for (let x = step; x < width; x += step) {
                    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                }
                for (let y = step; y < height; y += step) {
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                }
                let b = Math.max(18, width * 0.035), m = 10;
                ctx.strokeStyle = Qt.rgba(line.r, line.g, line.b, 0.9);
                ctx.lineWidth = 2;
                let corners = [[m, m, 1, 1], [width - m, m, -1, 1], [m, height - m, 1, -1], [width - m, height - m, -1, -1]];
                for (let c of corners) {
                    ctx.beginPath();
                    ctx.moveTo(c[0], c[1] + c[3] * b);
                    ctx.lineTo(c[0], c[1]);
                    ctx.lineTo(c[0] + c[2] * b, c[1]);
                    ctx.stroke();
                }
            }
        }

        // Fijne lijnen bij de neutrale uitvoering.
        Repeater {
            model: table.look === "mono" ? 14 : 0
            Rectangle {
                required property int index
                x: 10
                y: 10 + index * (plinth.height - 20) / 14
                width: plinth.width - 20
                height: 1
                color: Qt.rgba(table.mocha.text.r, table.mocha.text.g, table.mocha.text.b, 0.025)
            }
        }
        // Schroefjes in de hoeken.
        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: 6; height: 6; radius: 3
                x: index % 2 ? plinth.width - 16 : 10
                y: index < 2 ? 10 : plinth.height - 16
                visible: table.look !== "neon"
                color: table.skin.screw
            }
        }
    }

    // Indeling zoals een klassieke direct-drive draaitafel: grote
    // draaischijf links, armvoet rechtsboven, pitch rechtsonder,
    // start/stop en toerental linksonder.

    MediaVinyl {
        id: vinyl
        readonly property real side: table.height * 0.98
        width: side
        height: side
        x: table.width * 0.385 - side / 2
        y: table.height * 0.01
        mocha: table.mocha
        accent: table.accent
        showPlinth: false
        showArm: true
        vinylMode: true
        playerStyle: "vinyl"
        finish: table.look === "mono" ? "" : table.look
        strobe: true
        armPivot: Qt.point(table.width * 0.835 - x, table.height * 0.2 - y)
        armReach: 2.05
        armBase: 1.9
        artUrl: table.artUrl
        trackKey: table.trackKey
        playing: table.playing
        tracking: table.tracking
        progress: table.progress
        canSeek: table.canSeek
        spinSpeed: (table.rpm === 45 ? 64 : 48) * (1 + table.pitch / 100)
        onSeekRequested: fraction => table.seek(fraction)
    }

    // 45-toerenadapter linksboven.
    Rectangle {
        x: table.width * 0.035
        y: table.height * 0.06
        width: table.height * 0.1
        height: width
        radius: width / 2
        color: table.look === "wood" ? "#c9a55f" : table.look === "neon" ? "#05070c" : table.mocha.overlay1
        border.width: table.look === "neon" || table.look === "paper" ? 1.5 : 1
        border.color: table.look === "neon" ? table.accent : table.look === "paper" ? table.mocha.text : Qt.rgba(0, 0, 0, 0.3)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.62
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.25)
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.16
            height: width
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.5)
        }
    }

    // Naaldlampje linksonder; brandt tijdens afspelen.
    Item {
        x: table.width * 0.04
        y: table.height * 0.66
        width: table.height * 0.075
        height: width
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.8
            height: width
            radius: width / 2
            color: table.skin.lit
            opacity: table.playing ? 0.35 : 0
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(500) } }
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: 1.0 }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: table.look === "paper" ? table.mocha.base : "#15171c"
            border.width: table.look === "paper" ? 1.5 : 2
            border.color: table.look === "wood" ? "#c9a55f" : table.look === "paper" ? table.mocha.text : table.mocha.overlay1
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.45
                height: width
                radius: width / 2
                color: table.playing ? table.skin.lit : Qt.rgba(0.5, 0.5, 0.5, 0.35)
                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(500) } }
            }
        }
    }

    // Start/stop en toerental linksonder.
    DeckKey {
        mocha: table.mocha
        accent: table.accent
        skin: table.skin
        x: table.width * 0.03
        y: table.height * 0.82
        label: "START"
        lit: table.playing
        keyWidth: table.height * 0.15
        keyHeight: table.height * 0.11
        onActivated: table.togglePlay()
    }
    Row {
        visible: !table.compact
        x: table.width * 0.03 + table.height * 0.17
        y: table.height * 0.82 + table.height * 0.11 - table.height * 0.045
        spacing: table.height * 0.015
        Repeater {
            model: [33, 45]
            delegate: DeckKey {
                mocha: table.mocha
                accent: table.accent
                skin: table.skin
                required property int modelData
                label: String(modelData)
                lit: table.rpm === modelData
                keyWidth: table.height * 0.085
                keyHeight: table.height * 0.045
                onActivated: table.rpm = modelData
            }
        }
    }

    // Armlift-hendel naast de armvoet (sier).
    Rectangle {
        x: table.width * 0.9
        y: table.height * 0.42
        width: table.height * 0.045
        height: table.height * 0.11
        radius: width / 2
        color: table.look === "paper" ? table.mocha.base : Qt.rgba(0, 0, 0, 0.35)
        border.width: 1
        border.color: table.skin.border
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: vinyl.armLift > 0.5 ? parent.height * 0.08 : parent.height * 0.55
            Behavior on y { NumberAnimation { duration: ThemeConfig.duration(200); easing.type: Easing.OutCubic } }
            width: parent.width * 1.5
            height: width * 0.6
            radius: height / 2
            color: table.skin.needle
        }
    }

    // Pitch-schuif rechtsonder: verstelt het toerental een paar procent.
    Item {
        id: pitchFader
        x: table.width * 0.915
        y: table.height * 0.58
        width: table.height * 0.06
        height: table.height * 0.34
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.28
            height: parent.height
            radius: width / 2
            color: table.look === "paper" ? table.mocha.base : Qt.rgba(0, 0, 0, 0.55)
            border.width: 1
            border.color: table.look === "neon" ? Qt.rgba(table.accent.r, table.accent.g, table.accent.b, 0.6)
                : table.look === "paper" ? table.mocha.text : Qt.rgba(1, 1, 1, 0.08)
        }
        Repeater {
            model: 9
            Rectangle {
                required property int index
                x: -parent.width * 0.35
                y: index * (pitchFader.height / 8)
                width: index === 4 ? parent.width * 0.3 : parent.width * 0.18
                height: 1
                color: table.skin.brandColor
            }
        }
        Rectangle {
            id: faderCap
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 1.1
            height: parent.width * 0.55
            radius: table.look === "neon" ? 2 : 4
            y: (table.pitch + 8) / 16 * (pitchFader.height - height)
            color: table.look === "wood" ? "#c9a55f" : table.skin.capA
            border.width: 1
            border.color: table.skin.capBorder
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.8
                height: 2
                color: table.skin.lit
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.SizeVerCursor
            preventStealing: true
            function setAt(my) {
                let f = Math.max(0, Math.min(1, (my - 8 - faderCap.height / 2) / (pitchFader.height - faderCap.height)));
                let v = f * 16 - 8;
                table.pitch = Math.abs(v) < 0.6 ? 0 : Math.round(v * 10) / 10;
            }
            onPressed: mouse => setAt(mouse.y)
            onPositionChanged: mouse => { if (pressed) setAt(mouse.y); }
            onDoubleClicked: table.pitch = 0
        }
    }

    Text {
        visible: !table.compact
        anchors.right: parent.right
        anchors.rightMargin: table.width * 0.13
        y: table.height * 0.92
        text: table.skin.brand
        font.family: ThemeConfig.monoFont
        font.pixelSize: Math.max(9, table.width * 0.017)
        font.letterSpacing: 2
        color: table.skin.brandColor
    }
    Text {
        visible: !table.compact
        anchors.horizontalCenter: pitchFader.horizontalCenter
        y: pitchFader.y - height - table.height * 0.02
        text: (table.pitch > 0 ? "+" : "") + table.pitch.toFixed(1) + "%"
        font.family: ThemeConfig.monoFont
        font.pixelSize: Math.max(8, table.width * 0.014)
        color: table.skin.brandColor
    }
}
