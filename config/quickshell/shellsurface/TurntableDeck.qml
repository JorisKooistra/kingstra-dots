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
    // Onderrand recht, zodat hij naadloos op de voorkant van VinylStage past.
    property bool squareBottom: false
    property alias vinyl: vinyl
    // Volume 0..1 voor de schuif rechts; onder 0 is er geen volume bekend.
    property real volume: -1

    signal togglePlay()
    signal seek(real fraction)
    signal volumeRequested(real value)

    // Uitvoering per thema: Organic walnoot met messing, Neon zwart glas met
    // lichtlijnen, Paper inkt op papier, de rest geborsteld en neutraal.
    property string look: {
        let f = ThemeConfig.styleFamily;
        return f === "organic" ? "wood" : f === "neon" ? "neon" : f === "paper" ? "paper" : "mono";
    }
    readonly property var skin: {
        let m = mocha, a = accent;
        let ink = m.text;
        // Hout en neon houden hun vormen; de kleuren komen uit het thema.
        // Hout: warm en ambachtelijk. Themakleuren, maar geen gloed:
        // crèmekleurige knoppen, geborsteld metaal, een donkere rand.
        if (look === "wood") {
            let wood = Qt.tint(m.surface1, Qt.rgba(a.r, a.g, a.b, 0.14));
            let cream = Qt.tint(m.text, Qt.rgba(a.r, a.g, a.b, 0.14));
            let metal = Qt.tint(m.subtext1, Qt.rgba(a.r, a.g, a.b, 0.22));
            return {
                plinthA: Qt.lighter(wood, 1.08), plinthB: Qt.darker(wood, 1.35),
                border: Qt.darker(wood, 2.2), borderW: 3, radius: 14,
                frontA: Qt.darker(wood, 1.5), frontB: Qt.darker(wood, 2.3), frontEdge: Qt.darker(wood, 2.6),
                capA: cream, capB: Qt.darker(cream, 1.12), capHover: Qt.lighter(cream, 1.08),
                capSide: Qt.darker(cream, 1.8), capText: m.crust, capBorder: Qt.darker(cream, 1.4), lit: a,
                capShine: 0.5,
                dispBg: m.crust, dispText: a, dispBorder: Qt.darker(wood, 2.2),
                brand: "KINGSTRA · ORGANIC", brandColor: Qt.rgba(cream.r, cream.g, cream.b, 0.55),
                screw: metal, metal: metal, track: Qt.rgba(0, 0, 0, 0.35), fill: a,
                needle: metal, hint: m.subtext0
            };
        }
        if (look === "neon") return {
            plinthA: Qt.tint(m.mantle, Qt.rgba(a.r, a.g, a.b, 0.08)), plinthB: m.crust, border: a, borderW: 1.5, radius: 6,
            frontA: Qt.tint(m.crust, Qt.rgba(a.r, a.g, a.b, 0.05)), frontB: m.crust, frontEdge: a,
            capA: Qt.tint(m.mantle, Qt.rgba(a.r, a.g, a.b, 0.10)), capB: m.crust,
            capHover: Qt.tint(m.surface0, Qt.rgba(a.r, a.g, a.b, 0.18)), capSide: Qt.darker(m.crust, 1.5),
            capText: a, capBorder: Qt.rgba(a.r, a.g, a.b, 0.55), lit: m.pink,
            dispBg: Qt.darker(m.crust, 1.4), dispText: a, dispBorder: Qt.rgba(a.r, a.g, a.b, 0.6),
            brand: "KINGSTRA // NEON DRIVE", brandColor: Qt.rgba(a.r, a.g, a.b, 0.75),
            screw: a, track: Qt.rgba(a.r, a.g, a.b, 0.14), fill: a,
            needle: a, hint: a
        };
        if (look === "paper") return {
            plinthA: m.base, plinthB: m.base, border: ink, borderW: 2, radius: 8,
            frontA: Qt.darker(m.base, 1.04), frontB: Qt.darker(m.base, 1.08), frontEdge: ink,
            capA: m.base, capB: m.base, capHover: Qt.tint(m.base, Qt.rgba(a.r, a.g, a.b, 0.15)), capSide: ink,
            capText: ink, capBorder: ink, lit: a, capShine: 0,
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
    // Pitch in procent; de schuif is nu volume, dit blijft 0.
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

        // Rechte onderhoeken voor de schermvullende speler.
        Rectangle {
            visible: table.squareBottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: plinth.radius + plinth.border.width
            color: table.skin.plinthB
            border.width: plinth.border.width
            border.color: plinth.border.color
            Rectangle {
                x: plinth.border.width
                y: -1
                width: parent.width - 2 * plinth.border.width
                height: plinth.border.width + 1
                color: table.skin.plinthB
            }
        }
        // Hout: lichte bovenrand en donkere onderrand geven de plint dikte.
        Rectangle {
            visible: table.look === "wood"
            anchors.fill: parent
            anchors.margins: plinth.border.width
            radius: Math.max(0, plinth.radius - plinth.border.width)
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(1, 1, 1, 0.07)
        }

        // Nerf met een paar noesten, steeds dezelfde.
        // Altijd op dezelfde grootte getekend en daarna geschaald (met
        // mipmaps), zodat de kleine speler dezelfde nerf heeft als de grote
        // in plaats van een dicht opeengepakt patroon.
        Canvas {
            id: grain
            readonly property real fit: (plinth.width - 6) / width
            x: 3
            y: 3
            width: 900
            height: Math.max(1, Math.round(900 * (plinth.height - 6) / Math.max(1, plinth.width - 6)))
            transformOrigin: Item.TopLeft
            scale: fit
            layer.enabled: visible
            layer.mipmap: true
            layer.smooth: true
            visible: table.look === "wood"
            // Nerf in de donkerste en lichtste themakleur.
            readonly property color dark: table.mocha.crust
            readonly property color light: table.mocha.text
            onDarkChanged: requestPaint()
            onLightChanged: requestPaint()
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
                    let isDark = rnd() < 0.7;
                    let c = isDark ? grain.dark : grain.light;
                    ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, isDark ? 0.18 + rnd() * 0.22 : 0.05 + rnd() * 0.08);
                    ctx.lineWidth = 0.6 + rnd() * 1.8;
                    ctx.stroke();
                }
                for (let k = 0; k < 3; k++) {
                    let kx = w * (0.15 + rnd() * 0.7), ky = h * (0.1 + rnd() * 0.8);
                    for (let r = 0; r < 5; r++) {
                        ctx.beginPath();
                        ctx.ellipse(kx - (8 + r * 6), ky - (3 + r * 2.2), (8 + r * 6) * 2, (3 + r * 2.2) * 2);
                        ctx.strokeStyle = Qt.rgba(grain.dark.r, grain.dark.g, grain.dark.b, 0.26 - r * 0.04);
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
        halo: table.look === "neon" || table.look === "mono"
        single: table.rpm === 45
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

    // 45-toerenadapter linksboven; ligt op de as zolang er een single speelt.
    Rectangle {
        visible: table.look !== "paper"
        x: table.width * 0.035 + width * 0.08
        y: table.height * 0.06 + width * 0.12
        width: table.height * 0.1
        height: width
        radius: width / 2
        color: Qt.rgba(0, 0, 0, 0.4)
        opacity: vinyl.shownSingle ? 0 : 1
    }
    Rectangle {
        x: table.width * 0.035
        y: table.height * 0.06
        width: table.height * 0.1
        height: width
        radius: width / 2
        opacity: vinyl.shownSingle ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("normal") } }
        color: table.look === "wood" ? table.skin.metal : table.look === "neon" ? table.mocha.crust : table.mocha.overlay1
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
    // Verder van de draaischijf, vrij van de rand en de gloed.
    Item {
        id: lamp
        readonly property color ring: table.look === "wood" ? table.skin.metal : table.look === "paper" ? table.mocha.text : table.mocha.overlay1
        x: table.width * 0.02
        y: table.height * 0.70
        width: table.height * 0.072
        height: width
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.5
            height: width
            radius: width / 2
            color: table.skin.lit
            opacity: table.playing ? 0.35 : 0
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(500) } }
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: 1.0 }
        }
        // Schaduw en metalen ring, daarin een verzonken lampje.
        Rectangle {
            visible: table.look !== "paper"
            x: parent.width * 0.08
            y: parent.width * 0.14
            width: parent.width
            height: width
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.4)
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: table.look === "paper" ? table.mocha.base : Qt.lighter(lamp.ring, 1.2) }
                GradientStop { position: 1.0; color: table.look === "paper" ? table.mocha.base : Qt.darker(lamp.ring, 1.8) }
            }
            border.width: table.look === "paper" ? 1.5 : 0
            border.color: table.mocha.text
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.72
                height: width
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: table.look === "paper" ? table.mocha.base : Qt.darker(table.mocha.crust, 1.4) }
                    GradientStop { position: 1.0; color: table.look === "paper" ? table.mocha.base : table.mocha.surface0 }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.4
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
        y: table.height * 0.835
        label: "START"
        lit: table.playing
        keyWidth: table.height * 0.15
        keyHeight: table.height * 0.11
        onActivated: table.togglePlay()
    }
    Row {
        visible: !table.compact
        // Langs de onderrand, onder de draaischijf door.
        x: table.width * 0.03 + table.height * 0.17
        y: table.height * 0.925
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
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: table.look === "paper" ? table.mocha.base : Qt.rgba(0, 0, 0, 0.7) }
            GradientStop { position: 1.0; color: table.look === "paper" ? table.mocha.base : Qt.rgba(0, 0, 0, 0.3) }
        }
        border.width: 1
        border.color: table.skin.border
        Item {
            id: leverKnob
            anchors.horizontalCenter: parent.horizontalCenter
            y: vinyl.armLift > 0.5 ? parent.height * 0.02 : parent.height * 0.5
            Behavior on y { NumberAnimation { duration: ThemeConfig.duration(200); easing.type: Easing.OutCubic } }
            width: parent.width * 1.5
            height: width * 0.6 * 1.35
            Rectangle {
                visible: table.look !== "paper"
                x: parent.height * 0.2
                y: parent.height * 0.35
                width: parent.width
                height: parent.width * 0.6
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.4)
            }
            Rectangle {
                y: parent.width * 0.6 * 0.3
                width: parent.width
                height: parent.width * 0.6
                radius: height / 2
                color: Qt.darker(table.skin.needle, 1.9)
            }
            Rectangle {
                width: parent.width
                height: parent.width * 0.6
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(table.skin.needle, 1.25) }
                    GradientStop { position: 1.0; color: Qt.darker(table.skin.needle, 1.3) }
                }
            }
        }
    }

    // Schuif rechtsonder, op de plek van de pitch: het volume. Omhoog is
    // harder; tijdens slepen volgt de kap de muis, daarna het systeem.
    Item {
        id: pitchFader
        visible: table.volume >= 0
        property bool dragging: false
        property real dragValue: 0
        readonly property real shown: dragging ? dragValue : Math.max(0, Math.min(1, table.volume))
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
            // Verzonken gleuf: bovenrand donker, onderrand vangt licht.
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: table.look === "paper" ? table.mocha.base : Qt.rgba(0, 0, 0, 0.85) }
                GradientStop { position: 1.0; color: table.look === "paper" ? table.mocha.base : Qt.rgba(0, 0, 0, 0.45) }
            }
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
        // Schuifkap als blokje: schaduw, zijkant, belichte bovenkant met ribbels.
        Rectangle {
            visible: table.look !== "paper"
            x: faderCap.x + faderCap.height * 0.25
            y: faderCap.y + faderCap.height * 0.55
            width: faderCap.width
            height: faderCap.height
            radius: faderCap.radius
            color: Qt.rgba(0, 0, 0, 0.4)
        }
        Rectangle {
            x: faderCap.x
            y: faderCap.y + faderCap.height * 0.3
            width: faderCap.width
            height: faderCap.height
            radius: faderCap.radius
            color: table.look === "paper" ? table.mocha.text : table.skin.capSide
        }
        Rectangle {
            id: faderCap
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 1.1
            height: parent.width * 0.55
            radius: table.look === "neon" ? 2 : 4
            y: (1 - pitchFader.shown) * (pitchFader.height - height * 1.3)
            gradient: Gradient {
                GradientStop { position: 0.0; color: table.look === "paper" ? table.skin.capA : Qt.lighter(table.skin.capA, 1.12) }
                GradientStop { position: 1.0; color: table.skin.capB }
            }
            border.width: 1
            border.color: table.skin.capBorder
            Column {
                anchors.centerIn: parent
                spacing: Math.max(1, faderCap.height * 0.14)
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: faderCap.width * 0.7
                        height: Math.max(1, faderCap.height * 0.08)
                        color: index === 1 ? table.skin.lit : Qt.rgba(0, 0, 0, 0.3)
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.SizeVerCursor
            preventStealing: true
            function setAt(my) {
                let f = Math.max(0, Math.min(1, (my - 8 - faderCap.height / 2) / (pitchFader.height - faderCap.height)));
                pitchFader.dragValue = Math.round((1 - f) * 100) / 100;
                table.volumeRequested(pitchFader.dragValue);
            }
            onPressed: mouse => { pitchFader.dragging = true; setAt(mouse.y); }
            onPositionChanged: mouse => { if (pressed) setAt(mouse.y); }
            onReleased: pitchFader.dragging = false
            onCanceled: pitchFader.dragging = false
            onWheel: wheel => table.volumeRequested(Math.max(0, Math.min(1, table.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
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
        visible: !table.compact && pitchFader.visible
        anchors.horizontalCenter: pitchFader.horizontalCenter
        y: pitchFader.y - height - table.height * 0.02
        text: "VOL " + Math.round(pitchFader.shown * 100)
        font.family: ThemeConfig.monoFont
        font.pixelSize: Math.max(8, table.width * 0.014)
        color: table.skin.brandColor
    }
}
