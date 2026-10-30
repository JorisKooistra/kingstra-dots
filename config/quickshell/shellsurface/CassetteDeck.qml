import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import ".."

// Voorkant van een draagbare cassettespeler, zoals een moderne walkman
// (FiiO CP13): een gekleurd front in een metalen behuizing, met een
// pilvormig venster waardoor je de cassette ziet. Gedeeld door de
// mediakaart op het bureaublad (klein, recht van voren) en
// CassetteStageContent (groot, staand, met bovenkant en zijkant).
//
// Door het venster: het label met titel (lopend) en artiest, en twee
// spoelen. Het tapepakket links krimpt en rechts groeit met de voortgang;
// bij spoelen winden de spoelen zichtbaar snel door. Kleuren per thema.
// Bij een nieuw album (trackKey) gaat de oude cassette omhoog het venster
// uit en zakt de nieuwe erin, met het label van het nieuwe album.
Item {
    id: deck

    required property var mocha
    property color accent: mocha.primary
    property string title: ""
    property string artist: ""
    property bool playing: false
    property bool tracking: false
    // Album of hoes-URL; verandert dit, dan wisselt de cassette.
    property string trackKey: ""
    // Waar de tape staat (0..1); tijdens spoelen het doel.
    property real position: 0
    // In seconden, voor de teller.
    property real length: 0
    property bool compact: false
    property real detail: compact ? 0 : 1
    property bool marquee: true
    // Slepen over het venster spoelt (alleen groot).
    property bool seekable: false
    signal togglePlay()
    signal scrubPressed(real fraction)
    signal scrubMoved(real fraction)
    signal scrubReleased(real fraction)

    readonly property real u: width / 100
    readonly property real bodyRadius: u * (look === "neon" ? 2.5 : 4)

    property string look: ThemeConfig.deviceLook
    readonly property color secondary: mocha.accent2 !== undefined ? mocha.accent2
        : mocha.secondary !== undefined ? mocha.secondary : mocha.pink
    readonly property color tertiary: mocha.tertiary !== undefined ? mocha.tertiary : mocha.peach
    readonly property color secondaryContainer: mocha.accent2Container !== undefined ? mocha.accent2Container
        : mocha.secondaryContainer !== undefined ? mocha.secondaryContainer : secondary
    readonly property color tertiaryContainer: mocha.tertiaryContainer !== undefined ? mocha.tertiaryContainer : tertiary
    readonly property color primaryContainer: mocha.primaryContainer !== undefined ? mocha.primaryContainer : accent
    function role(name, fallback) {
        let v = skin[name];
        return v !== undefined ? v : fallback;
    }
    // panel: het gekleurde front; shellTop/shellSide: de metalen behuizing
    // (bovenkant en zijkant, getekend door DeviceStage); keys: de knoppen
    // bovenop, play in het accent.
    // Het wieltje en andere gedeelde onderdelen lezen cap*-kleuren.
    readonly property var skin: Object.assign({}, baseSkin, { capA: baseSkin.keyA, capB: baseSkin.keyB, capBorder: baseSkin.border })
    readonly property var baseSkin: {
        let m = mocha, a = accent;
        let sec = secondary, ter = tertiary, secC = secondaryContainer, terC = tertiaryContainer;
        let ink = m.text;
        let metal = Qt.tint(m.subtext1, Qt.rgba(sec.r, sec.g, sec.b, 0.14));
        let common = {
            label: Qt.tint(m.text, Qt.rgba(terC.r, terC.g, terC.b, 0.18)),
            labelText: m.crust, labelText2: Qt.darker(Qt.tint(m.crust, Qt.rgba(sec.r, sec.g, sec.b, 0.55)), 1.1),
            stripe: sec, stripe2: ter, led: ter, ledAlt: sec, lit: a,
            tape: Qt.darker(Qt.tint(m.crust, Qt.rgba(ter.r, ter.g, ter.b, 0.3)), 1.05),
            hint: m.subtext0, metal: metal
        };
        if (look === "wood") {
            // Organic: mat kunststof front in de themakleur (primary
            // container, een vleugje tertiary), geborsteld metaal.
            let priC = primaryContainer;
            let panel = Qt.tint(Qt.tint(Qt.lighter(m.surface2, 1.3), Qt.rgba(priC.r, priC.g, priC.b, 0.68)), Qt.rgba(terC.r, terC.g, terC.b, 0.1));
            return Object.assign(common, {
                panelA: Qt.lighter(panel, 1.1), panelB: Qt.darker(panel, 1.08), panelEdge: Qt.darker(panel, 1.5),
                logo: Qt.darker(panel, 1.9), print: Qt.rgba(m.crust.r, m.crust.g, m.crust.b, 0.55),
                shellTop: Qt.lighter(metal, 1.05), shellSide: Qt.darker(metal, 1.45), shellEdge: Qt.darker(metal, 1.8),
                cassette: Qt.rgba(0.08, 0.07, 0.06, 0.92), hub: Qt.tint(m.text, Qt.rgba(terC.r, terC.g, terC.b, 0.15)), hubShade: Qt.darker(m.text, 1.6),
                keyA: Qt.lighter(metal, 1.12), keyB: Qt.darker(metal, 1.12), keySide: Qt.darker(metal, 1.15), keyIcon: Qt.darker(m.crust, 1.1),
                playA: Qt.lighter(sec, 1.05), playB: Qt.darker(sec, 1.2), playSide: Qt.darker(sec, 1.25), playIcon: m.crust,
                counterBg: m.crust, counterText: m.text, border: Qt.rgba(0, 0, 0, 0.35), flat: false
            });
        }
        if (look === "neon") return Object.assign(common, {
            panelA: Qt.tint(m.mantle, Qt.rgba(a.r, a.g, a.b, 0.07)), panelB: Qt.darker(m.crust, 1.2), panelEdge: a,
            logo: a, print: Qt.rgba(a.r, a.g, a.b, 0.6),
            shellTop: Qt.tint(m.surface0, Qt.rgba(a.r, a.g, a.b, 0.08)), shellSide: Qt.darker(m.crust, 1.3), shellEdge: a,
            cassette: Qt.rgba(0.02, 0.02, 0.03, 0.85), hub: Qt.tint(m.crust, Qt.rgba(a.r, a.g, a.b, 0.6)), hubShade: a,
            label: Qt.tint(m.mantle, Qt.rgba(a.r, a.g, a.b, 0.08)), labelText: a, labelText2: sec, lit: m.pink,
            keyA: Qt.tint(m.surface0, Qt.rgba(a.r, a.g, a.b, 0.12)), keyB: m.crust, keySide: Qt.darker(m.surface0, 1.2), keyIcon: a,
            playA: Qt.tint(m.surface0, Qt.rgba(a.r, a.g, a.b, 0.35)), playB: Qt.tint(m.crust, Qt.rgba(a.r, a.g, a.b, 0.2)), playSide: Qt.darker(m.surface0, 1.1), playIcon: a,
            counterBg: Qt.darker(m.crust, 1.4), counterText: a, border: Qt.rgba(a.r, a.g, a.b, 0.55), flat: false, hint: a,
            tape: Qt.tint(m.crust, Qt.rgba(sec.r, sec.g, sec.b, 0.22))
        });
        if (look === "paper") return Object.assign(common, {
            panelA: m.base, panelB: m.base, panelEdge: ink, logo: ink, print: Qt.rgba(ink.r, ink.g, ink.b, 0.7),
            shellTop: m.base, shellSide: Qt.darker(m.base, 1.06), shellEdge: ink,
            cassette: m.base, hub: m.base, hubShade: ink, label: m.base, labelText: ink, labelText2: ink,
            stripe: Qt.rgba(ink.r, ink.g, ink.b, 0.25), stripe2: Qt.rgba(ink.r, ink.g, ink.b, 0.12), tape: Qt.rgba(ink.r, ink.g, ink.b, 0.8),
            keyA: m.base, keyB: m.base, keySide: m.base, keyIcon: ink, playA: m.base, playB: m.base, playSide: m.base, playIcon: ink,
            counterBg: ink, counterText: m.base, border: ink, flat: true, hint: ink, metal: ink
        });
        // Mono: geborsteld aluminium.
        let alu = Qt.tint(Qt.lighter(m.surface2, 1.5), Qt.rgba(secC.r, secC.g, secC.b, 0.08));
        return Object.assign(common, {
            panelA: Qt.lighter(alu, 1.12), panelB: Qt.darker(alu, 1.05), panelEdge: Qt.darker(alu, 1.5),
            logo: Qt.darker(alu, 2.2), print: Qt.rgba(m.crust.r, m.crust.g, m.crust.b, 0.5),
            shellTop: Qt.darker(m.surface2, 1.05), shellSide: Qt.darker(m.surface1, 1.3), shellEdge: Qt.darker(m.surface0, 1.4),
            cassette: Qt.rgba(0.06, 0.06, 0.07, 0.9), hub: m.subtext1, hubShade: m.overlay0,
            keyA: Qt.lighter(m.surface2, 1.25), keyB: m.surface1, keySide: Qt.darker(m.surface2, 1.1), keyIcon: m.text,
            playA: Qt.lighter(a, 1.05), playB: Qt.darker(a, 1.2), playSide: Qt.darker(a, 1.3), playIcon: m.crust,
            counterBg: Qt.rgba(0, 0, 0, 0.7), counterText: m.text, border: Qt.rgba(0, 0, 0, 0.35), flat: false
        });
    }

    // --- Spoelen ---------------------------------------------------------------
    // tapePos volgt position: bij afspelen vloeiend, bij spoelen zo snel als
    // de spoelen kunnen winden. Tape loopt met vaste snelheid langs de kop,
    // dus de kleinste spoel draait het snelst.
    property real tapePos: 0
    property real reelAngleL: 0
    property real reelAngleR: 0
    property real motor: 0
    Component.onCompleted: {
        tapePos = Math.max(0, Math.min(1, position));
        shownKey = trackKey;
        shownTitle = title;
        shownArtist = artist;
    }
    function spinState() { return { a: reelAngleL, b: reelAngleR, t: tapePos }; }
    function applySpinState(s) {
        if (s && s.a !== undefined) { reelAngleL = s.a; reelAngleR = s.b; tapePos = s.t; }
    }
    // In cassette-eenheden (c = 1/100 van de cassettebreedte).
    readonly property real hubR: 6.2
    readonly property real packMax: 16.8
    function packFor(fill) { return hubR + (packMax - hubR) * Math.sqrt(Math.max(0, Math.min(1, fill))); }
    readonly property real packL: packFor(1 - tapePos)
    readonly property real packR: packFor(tapePos)
    FrameAnimation {
        running: deck.visible && (deck.playing || deck.motor > 0.01 || Math.abs(deck.position - deck.tapePos) > 0.0004)
        onTriggered: {
            let dt = Math.min(0.1, Math.max(0, frameTime));
            deck.motor += ((deck.playing && !deck.swapping ? 1 : 0) - deck.motor) * (1 - Math.exp(-dt / 0.25));
            if ((!deck.playing || deck.swapping) && deck.motor < 0.01) deck.motor = 0;
            let target = Math.max(0, Math.min(1, deck.position));
            let diff = target - deck.tapePos;
            let step = diff * (1 - Math.exp(-dt / 0.35));
            let cap = 0.9 * dt;
            step = Math.max(-cap, Math.min(cap, step));
            if (Math.abs(diff) < 0.0004) step = diff;
            deck.tapePos += step;
            let v = 15 * deck.motor + (dt > 0 ? step / dt : 0) * 420;
            let toDeg = 180 / Math.PI;
            let wl = Math.max(-900, Math.min(900, v / deck.packL * toDeg));
            let wr = Math.max(-900, Math.min(900, v / deck.packR * toDeg));
            deck.reelAngleL = (deck.reelAngleL + wl * dt) % 360;
            deck.reelAngleR = (deck.reelAngleR + wr * dt) % 360;
        }
    }
    // --- Cassette wisselen bij een nieuw album ------------------------------------
    // Het label houdt titel en artiest van de cassette die erin zit; spelers
    // sturen de nieuwe titel vaak net vóór het nieuwe album, dus even
    // wachten voordat het label meeloopt.
    property string shownKey: ""
    property string shownTitle: ""
    property string shownArtist: ""
    readonly property bool swapping: swapAnim.running
    // Eject ingedrukt (de knop bovenop de grote speler gaat mee omlaag).
    property bool ejectDown: false
    onTrackKeyChanged: maybeSwap()
    onTitleChanged: labelSettle.restart()
    onArtistChanged: labelSettle.restart()
    Timer {
        id: labelSettle
        interval: 450
        onTriggered: {
            if (deck.swapping) return;
            if (deck.trackKey !== deck.shownKey) { deck.maybeSwap(); return; }
            deck.shownTitle = deck.title;
            deck.shownArtist = deck.artist;
        }
    }
    function maybeSwap() {
        if (trackKey === shownKey || swapping) return;
        if (shownKey === "" || trackKey === "" || !visible) {
            shownKey = trackKey;
            shownTitle = title;
            shownArtist = artist;
            return;
        }
        labelSettle.stop();
        swapAnim.restart();
    }
    // Zoals bij een echte walkman: eject, het klepje kantelt open (scharnier
    // onderaan), de cassette gaat omhoog uit het klepje en weg, de nieuwe
    // schuift erin en het klepje klikt dicht.
    SequentialAnimation {
        id: swapAnim
        ScriptAction { script: deck.ejectDown = true }
        PauseAnimation { duration: ThemeConfig.duration(180) }
        NumberAnimation { target: deck; property: "doorOpen"; to: 1; duration: ThemeConfig.duration(460); easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        ScriptAction { script: deck.ejectDown = false }
        PauseAnimation { duration: ThemeConfig.duration(140) }
        NumberAnimation { target: deck; property: "cassetteOut"; to: 1; duration: ThemeConfig.duration(760); easing.type: Easing.InOutCubic }
        ScriptAction {
            script: {
                deck.shownKey = deck.trackKey;
                deck.shownTitle = deck.title;
                deck.shownArtist = deck.artist;
                // Nieuwe cassette staat aan het begin van zijn eigen tape.
                deck.tapePos = Math.max(0, Math.min(1, deck.position));
                deck.reelAngleL = Math.random() * 360;
                deck.reelAngleR = Math.random() * 360;
            }
        }
        PauseAnimation { duration: ThemeConfig.duration(200) }
        NumberAnimation { target: deck; property: "cassetteOut"; to: 0; duration: ThemeConfig.duration(760); easing.type: Easing.InOutCubic }
        PauseAnimation { duration: ThemeConfig.duration(160) }
        NumberAnimation { target: deck; property: "doorOpen"; to: 0; duration: ThemeConfig.duration(320); easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                if (deck.trackKey === deck.shownKey) { deck.shownTitle = deck.title; deck.shownArtist = deck.artist; }
                deck.maybeSwap();
            }
        }
    }

    // --- 3D: klepje en cassette ---------------------------------------------------
    // Punten in front-coördinaten (x, y) met h naar je toe. Op de mediakaart
    // kijk je recht van voren; de schermvullende speler geeft zijn camera mee
    // (view), zodat klepje en cassette in hetzelfde perspectief staan.
    property var view: null
    function viewPt(x, y, h) {
        if (view) return view(x, y, h);
        let f = width * 3.5, s = f / Math.max(1, f - h);
        return [width / 2 + (x - width / 2) * s, height / 2 + (y - height / 2) * s];
    }
    // Homografie: legt een rechthoek (w x h) op vier punten.
    function quadMatrix(w, h, q) {
        let x0 = q[0][0], y0 = q[0][1], x1 = q[1][0], y1 = q[1][1], x2 = q[2][0], y2 = q[2][1], x3 = q[3][0], y3 = q[3][1];
        let dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3;
        let dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3;
        let den = dx1 * dy2 - dx2 * dy1;
        let g = Math.abs(den) < 1e-9 ? 0 : (dx3 * dy2 - dx2 * dy3) / den;
        let hh = Math.abs(den) < 1e-9 ? 0 : (dx1 * dy3 - dx3 * dy1) / den;
        let a = x1 - x0 + g * x1, b = x3 - x0 + hh * x3, c = x0;
        let d = y1 - y0 + g * y1, e = y3 - y0 + hh * y3, f = y0;
        return Qt.matrix4x4(a / w, b / h, 0, c,
                            d / w, e / h, 0, f,
                            0, 0, 1, 0,
                            g / w, hh / h, 0, 1);
    }
    // Een vlak door o met assen ex en ey (3D), voor een item zo groot als de speler.
    function planeMatrix(o, ex, ey) {
        let W = width, H = height;
        function at(x, y) { return viewPt(o[0] + x * ex[0] + y * ey[0], o[1] + x * ex[1] + y * ey[1], o[2] + x * ex[2] + y * ey[2]); }
        return quadMatrix(W, H, [at(0, 0), at(W, 0), at(W, H), at(0, H)]);
    }
    function ease01(t) { t = Math.max(0, Math.min(1, t)); return t * t * (3 - 2 * t); }
    readonly property matrix4x4 identity: Qt.matrix4x4()

    // Klepje: bijna het hele front onder logo en teller, scharnier langs de
    // onderrand; open staat het 28 graden naar je toe.
    property real doorOpen: 0
    readonly property real doorAngle: doorOpen * 28 * Math.PI / 180
    readonly property real doorX: u * 8
    readonly property real doorY: u * 19
    readonly property real doorW: u * 84
    readonly property real doorH: u * 50
    readonly property real doorR: u * 3
    readonly property real hingeY: doorY + doorH
    readonly property var doorO: [0, hingeY * (1 - Math.cos(doorAngle)), hingeY * Math.sin(doorAngle)]
    readonly property var doorEy: [0, Math.cos(doorAngle), -Math.sin(doorAngle)]
    readonly property var doorN: [0, Math.sin(doorAngle), Math.cos(doorAngle)]
    function onDoor(x, y, lift) {
        return [x, doorO[1] + y * doorEy[1] + lift * doorN[1], doorO[2] + y * doorEy[2] + lift * doorN[2]];
    }
    readonly property matrix4x4 doorMatrix: doorOpen === 0 ? identity : planeMatrix(doorO, [1, 0, 0], doorEy)

    // Cassette in het klepje: 0 = zit erin, 1 = eruit. Hij schuift langs het
    // klepje omhoog, komt los, gaat naar je toe en verdwijnt.
    property real cassetteOut: 0
    readonly property real slideOut: cassetteOut * (cassH + u * 8)
    readonly property real liftOut: u * 16 * ease01((cassetteOut - 0.45) / 0.55)
    readonly property var cassO: [0, doorO[1] - slideOut * doorEy[1] + liftOut * doorN[1], doorO[2] - slideOut * doorEy[2] + liftOut * doorN[2]]
    readonly property matrix4x4 cassetteMatrix: doorOpen === 0 && cassetteOut === 0 ? identity
        : planeMatrix(cassO, [1, 0, 0], doorEy)
    // Zijkanten van de cassette (12 mm dik, naar achteren vanaf het front).
    // Elke kant in volgorde zodat hij van buiten met de klok mee loopt; een
    // kant die in beeld andersom loopt, kijkt van je af en valt weg.
    function cassPt(x, y, d) {
        return viewPt(x, cassO[1] + y * doorEy[1] + d * doorN[1], cassO[2] + y * doorEy[2] + d * doorN[2]);
    }
    readonly property string cassetteSides: {
        if (doorOpen === 0 && cassetteOut === 0) return "M 0 0";
        let r = c * 3, T = c * 12;
        let x0 = cassX, x1 = cassX + cassW, y0 = cassY, y1 = cassY + cassH;
        let faces = [
            [[x0 + r, y0, -T], [x1 - r, y0, -T], [x1 - r, y0, 0], [x0 + r, y0, 0]],
            [[x0 + r, y1, 0], [x1 - r, y1, 0], [x1 - r, y1, -T], [x0 + r, y1, -T]],
            [[x1, y0 + r, -T], [x1, y1 - r, -T], [x1, y1 - r, 0], [x1, y0 + r, 0]],
            [[x0, y0 + r, 0], [x0, y1 - r, 0], [x0, y1 - r, -T], [x0, y0 + r, -T]]
        ];
        let out = "";
        for (let f of faces) {
            let p = f.map(q => cassPt(q[0], q[1], q[2]));
            let cr = (p[1][0] - p[0][0]) * (p[2][1] - p[1][1]) - (p[1][1] - p[0][1]) * (p[2][0] - p[1][0]);
            if (cr <= 0) continue;
            out += "M " + p[0][0] + " " + p[0][1] + " L " + p[1][0] + " " + p[1][1] + " L " + p[2][0] + " " + p[2][1] + " L " + p[3][0] + " " + p[3][1] + " Z ";
        }
        return out === "" ? "M 0 0" : out;
    }

    function clock(sec) {
        let s = Math.max(0, Math.floor(Number(sec) || 0));
        let m = Math.floor(s / 60);
        let r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    // --- Front -----------------------------------------------------------------
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: deck.bodyRadius
        border.width: deck.look === "paper" ? 2 : 1
        border.color: deck.skin.panelEdge
        gradient: Gradient {
            GradientStop { position: 0.0; color: deck.skin.panelA }
            GradientStop { position: 1.0; color: deck.skin.panelB }
        }
        // Lichte rand bovenaan: het front is een plaat met een afgeronde kant.
        Rectangle {
            visible: deck.look !== "paper"
            x: panel.radius
            y: 1
            width: parent.width - 2 * panel.radius
            height: Math.max(1, deck.u * 0.4)
            color: Qt.rgba(1, 1, 1, deck.look === "neon" ? 0.08 : 0.22)
        }
        // Mono: geborsteld; Neon: scanlijnen.
        Repeater {
            model: deck.look === "mono" || deck.look === "neon" ? Math.floor(deck.height / Math.max(3, deck.u * 1.2)) : 0
            Rectangle {
                required property int index
                x: panel.radius * 0.5
                width: panel.width - panel.radius
                y: (index + 0.5) * Math.max(3, deck.u * 1.2)
                height: 1
                color: deck.look === "neon" ? Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, 0.035)
                    : (index % 3 === 0 ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.035))
            }
        }
    }
    Rectangle {
        visible: deck.look === "neon"
        anchors.fill: parent
        anchors.margins: -3
        radius: deck.bodyRadius + 3
        color: "transparent"
        border.width: 3
        border.color: Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, deck.playing ? 0.45 : 0.25)
        layer.enabled: visible
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: 1.0 }
    }

    // Logo linksboven, teller rechtsboven.
    Text {
        x: deck.u * 10
        y: deck.u * 8.5
        text: deck.look === "paper" ? "kingstra" : "KINGSTRA"
        font.family: ThemeConfig.displayFont
        font.pixelSize: Math.max(6, deck.u * 6)
        font.weight: Font.Black
        font.letterSpacing: deck.u * 0.4
        color: deck.skin.logo
    }
    Rectangle {
        id: counter
        visible: deck.detail > 0.01
        opacity: deck.detail
        anchors.right: parent.right
        anchors.rightMargin: deck.u * 10
        y: deck.u * 9.5
        width: counterText.implicitWidth + deck.u * 2.4
        height: deck.u * 5.6
        radius: deck.u * 0.8
        color: deck.skin.counterBg
        border.width: 1
        border.color: deck.skin.border
        Text {
            id: counterText
            anchors.centerIn: parent
            text: deck.tracking ? deck.clock(deck.tapePos * deck.length) : "-:--"
            font.family: ThemeConfig.monoFont
            font.pixelSize: deck.u * 3.6
            font.weight: Font.Bold
            color: deck.skin.counterText
        }
    }
    // --- Vak achter het klepje -------------------------------------------------------
    // Alleen te zien als het klepje openstaat: de spoelassen, de koppen en de
    // aandrukrollen.
    readonly property color cavityColor: look === "paper" ? mocha.base : Qt.darker(skin.panelB, 2.4)
    Rectangle {
        x: deck.doorX
        y: deck.doorY
        width: deck.doorW
        height: deck.doorH
        radius: deck.doorR
        color: deck.cavityColor
        border.width: deck.look === "paper" ? 1.5 : 1
        border.color: deck.look === "paper" ? deck.mocha.text : Qt.rgba(0, 0, 0, 0.5)
        Rectangle {
            visible: deck.look !== "paper"
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.5) }
                GradientStop { position: 0.25; color: "transparent" }
            }
        }
    }
    Repeater {
        model: [-1, 1]
        Item {
            required property int modelData
            readonly property real r: deck.c * deck.hubR * 0.62
            x: deck.width / 2 + modelData * deck.c * 21.25 - r
            y: deck.hubY - r
            width: 2 * r
            height: 2 * r
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: deck.look === "paper" ? deck.mocha.base : Qt.darker(deck.skin.metal, 1.6)
                border.width: deck.look === "paper" ? 1.5 : 1
                border.color: deck.look === "paper" ? deck.mocha.text : Qt.rgba(0, 0, 0, 0.5)
            }
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    x: parent.width / 2 - width / 2
                    y: parent.height / 2 - height
                    width: Math.max(1, parent.width * 0.16)
                    height: parent.height * 0.48
                    radius: width / 2
                    color: deck.look === "paper" ? deck.mocha.text : deck.skin.metal
                    transform: Rotation { origin.x: width / 2; origin.y: height; angle: index * 60 }
                }
            }
        }
    }
    // Koppen onderin: wiskop, weergavekop en de aandrukrollen.
    Rectangle {
        x: deck.width / 2 - width / 2
        y: deck.hingeY - deck.u * 9.5
        width: deck.u * 12
        height: deck.u * 5
        radius: deck.u * 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: deck.look === "paper" ? deck.mocha.base : Qt.lighter(deck.skin.metal, 1.15) }
            GradientStop { position: 1.0; color: deck.look === "paper" ? deck.mocha.base : Qt.darker(deck.skin.metal, 1.3) }
        }
        border.width: deck.look === "paper" ? 1.5 : 1
        border.color: deck.look === "paper" ? deck.mocha.text : Qt.rgba(0, 0, 0, 0.45)
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -height * 0.4
            width: parent.width * 0.3
            height: parent.height * 0.5
            radius: deck.u * 0.4
            color: deck.look === "paper" ? deck.mocha.text : Qt.darker(deck.skin.metal, 1.7)
        }
    }
    Repeater {
        model: [-1, 1]
        Item {
            required property int modelData
            readonly property real r: deck.u * 2.3
            x: deck.width / 2 + modelData * deck.u * 13 - r
            y: deck.hingeY - deck.u * 8.5 - r
            width: 2 * r
            height: 2 * r
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: deck.look === "paper" ? deck.mocha.base : "#1c1a19"
                border.width: deck.look === "paper" ? 1.5 : 1
                border.color: deck.look === "paper" ? deck.mocha.text : Qt.rgba(1, 1, 1, 0.08)
            }
            Rectangle {
                x: parent.width / 2 - modelData * deck.u * 3.4 - width / 2
                y: parent.height / 2 - height / 2
                width: Math.max(1.5, deck.u * 1.1)
                height: width
                radius: width / 2
                color: deck.look === "paper" ? deck.mocha.text : deck.skin.metal
            }
        }
    }

    // --- Cassette -------------------------------------------------------------------
    // Echte maat (100 x 63,8 mm) in cassette-eenheden; de naven staan 42,5 mm
    // uit elkaar, op de hoogte van het midden van het venster. Bij gesloten
    // klepje zie je alleen wat achter het venster zit.
    readonly property real winX: u * 17
    readonly property real winY: u * 29
    readonly property real winW: u * 66
    readonly property real winH: u * 32
    readonly property real c: u * 0.7
    readonly property real hubY: winY + winH * 0.5
    readonly property real cassW: c * 100
    readonly property real cassH: c * 63.8
    readonly property real cassX: width / 2 - cassW / 2
    readonly property real cassY: hubY - cassH * 0.48
    Shape {
        anchors.fill: parent
        visible: deck.cassetteSides !== "M 0 0" && cassetteBody.visible
        opacity: cassetteBody.opacity
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: deck.look === "paper" ? deck.mocha.base : Qt.darker(Qt.rgba(deck.skin.cassette.r, deck.skin.cassette.g, deck.skin.cassette.b, 1), 1.15)
            strokeColor: deck.look === "paper" ? deck.mocha.text : Qt.rgba(1, 1, 1, 0.12)
            strokeWidth: deck.look === "paper" ? 1.5 : 1
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: deck.cassetteSides }
        }
    }
    Item {
        id: cassetteBody
        width: deck.width
        height: deck.height
        transform: Matrix4x4 { matrix: deck.cassetteMatrix }
        opacity: 1 - deck.ease01((deck.cassetteOut - 0.6) / 0.4)
        visible: opacity > 0.01

        Rectangle {
            x: deck.cassX
            y: deck.cassY
            width: deck.cassW
            height: deck.cassH
            radius: deck.c * 3
            color: deck.skin.cassette
            border.width: deck.look === "paper" ? 1.5 : 1
            border.color: deck.look === "paper" ? deck.mocha.text : Qt.rgba(1, 1, 1, 0.1)
        }
        // Onderrand met de opening voor de koppen.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: deck.look === "paper" ? deck.mocha.base : Qt.lighter(deck.skin.cassette, 1.6)
                strokeColor: deck.look === "paper" ? deck.mocha.text : Qt.rgba(1, 1, 1, 0.1)
                strokeWidth: deck.look === "paper" ? 1.5 : 1
                readonly property real b: deck.cassY + deck.cassH
                startX: deck.cassX + deck.c * 17; startY: b
                PathLine { x: deck.cassX + deck.c * 21; y: deck.cassY + deck.cassH - deck.c * 9 }
                PathLine { x: deck.cassX + deck.c * 79; y: deck.cassY + deck.cassH - deck.c * 9 }
                PathLine { x: deck.cassX + deck.c * 83; y: deck.cassY + deck.cassH }
                PathLine { x: deck.cassX + deck.c * 17; y: deck.cassY + deck.cassH }
            }
        }
        Repeater {
            model: [[5, 5], [95, 5], [5, 58.8], [95, 58.8], [50, 58.8]]
            Rectangle {
                required property var modelData
                width: Math.max(2, deck.c * 2.6)
                height: width
                radius: width / 2
                x: deck.cassX + deck.c * modelData[0] - width / 2
                y: deck.cassY + deck.c * modelData[1] - height / 2
                color: deck.look === "paper" ? deck.mocha.base : Qt.rgba(deck.skin.hub.r, deck.skin.hub.g, deck.skin.hub.b, 0.35)
                border.width: deck.look === "paper" ? 1 : 0
                border.color: deck.mocha.text
            }
        }
        TapeReel {
            x: deck.width / 2 - deck.c * 21.25 - hubRadius
            y: deck.hubY - hubRadius
            hubRadius: deck.c * deck.hubR
            packRadius: deck.c * deck.packL
            angle: deck.reelAngleL
            tape: deck.skin.tape
            hub: deck.skin.hub
            hubShade: deck.skin.hubShade
            flat: deck.look === "paper"
            ink: deck.mocha.text
        }
        TapeReel {
            x: deck.width / 2 + deck.c * 21.25 - hubRadius
            y: deck.hubY - hubRadius
            hubRadius: deck.c * deck.hubR
            packRadius: deck.c * deck.packR
            angle: deck.reelAngleR
            tape: deck.skin.tape
            hub: deck.skin.hub
            hubShade: deck.skin.hubShade
            flat: deck.look === "paper"
            ink: deck.mocha.text
        }
        // Kijkvenstertje van de cassette tussen de spoelen, en de tape onderin.
        Rectangle {
            x: deck.width / 2 - deck.c * 12
            y: deck.hubY - deck.c * 7
            width: deck.c * 24
            height: deck.c * 14
            radius: deck.c * 1.5
            color: "transparent"
            border.width: Math.max(1, deck.c * 0.4)
            border.color: Qt.rgba(deck.skin.hub.r, deck.skin.hub.g, deck.skin.hub.b, 0.35)
        }
        Rectangle {
            x: deck.cassX + deck.c * 21
            y: deck.cassY + deck.cassH - deck.c * 9.6
            width: deck.c * 58
            height: Math.max(1, deck.u * 0.6)
            color: deck.skin.tape
            opacity: 0.9
        }
        // Label bovenop de cassette, met titel en artiest.
        Rectangle {
            id: label
            x: deck.u * 26
            y: deck.winY + deck.u * 1.4
            width: deck.u * 48
            height: deck.u * 8.2
            radius: deck.u * 0.8
            color: deck.skin.label
            border.width: deck.look === "paper" ? 1.5 : 0
            border.color: deck.mocha.text
            Rectangle {
                y: parent.height - height * 2.2
                width: parent.width
                height: parent.height * 0.1
                color: deck.skin.stripe
            }
            Rectangle {
                y: parent.height - height * 1.1
                width: parent.width
                height: parent.height * 0.08
                color: deck.skin.stripe2
            }
            Text {
                x: deck.u * 1
                y: parent.height * 0.06
                text: "A"
                font.family: ThemeConfig.displayFont
                font.pixelSize: Math.max(4, parent.height * 0.42)
                font.weight: Font.Black
                color: deck.skin.stripe
            }
            MarqueeText {
                x: deck.u * 4.4
                y: parent.height * 0.05
                width: parent.width - deck.u * 5.6
                text: deck.shownTitle !== "" ? deck.shownTitle : "Geen nummer"
                color: deck.skin.labelText
                fontFamily: ThemeConfig.uiFont
                pixelSize: Math.max(4, parent.height * 0.36)
                fontWeight: Font.Bold
                running: deck.marquee && !deck.compact
            }
            Text {
                x: deck.u * 4.4
                y: parent.height * 0.46
                width: parent.width - deck.u * 5.6
                text: deck.shownArtist
                elide: Text.ElideRight
                font.family: ThemeConfig.uiFont
                font.pixelSize: Math.max(4, parent.height * 0.26)
                color: deck.skin.labelText2
            }
        }
    }

    // --- Klepje ------------------------------------------------------------------------
    // Dikte van het klepje (boven- en rechterrand), alleen te zien als het
    // openstaat.
    Shape {
        id: doorEdge
        anchors.fill: parent
        visible: deck.doorOpen > 0.005
        preferredRendererType: Shape.CurveRenderer
        readonly property real t: deck.u * 1.6
        readonly property var p0: deck.viewPt.apply(null, deck.onDoor(deck.doorX + deck.doorR, deck.doorY, 0))
        readonly property var p1: deck.viewPt.apply(null, deck.onDoor(deck.doorX + deck.doorW - deck.doorR, deck.doorY, 0))
        readonly property var p2: deck.viewPt.apply(null, deck.onDoor(deck.doorX + deck.doorW - deck.doorR, deck.doorY, -t))
        readonly property var p3: deck.viewPt.apply(null, deck.onDoor(deck.doorX + deck.doorR, deck.doorY, -t))
        // Rechterzijkant (zie je schuin van rechts in de grote speler).
        readonly property var q0: deck.viewPt.apply(null, deck.onDoor(deck.doorX + deck.doorW, deck.doorY + deck.doorR, 0))
        readonly property var q1: deck.viewPt.apply(null, deck.onDoor(deck.doorX + deck.doorW, deck.hingeY - deck.doorR, 0))
        readonly property var q2: deck.viewPt.apply(null, deck.onDoor(deck.doorX + deck.doorW, deck.hingeY - deck.doorR, -t))
        readonly property var q3: deck.viewPt.apply(null, deck.onDoor(deck.doorX + deck.doorW, deck.doorY + deck.doorR, -t))
        function poly(a, b, c, d) {
            return "M " + a[0] + " " + a[1] + " L " + b[0] + " " + b[1] + " L " + c[0] + " " + c[1] + " L " + d[0] + " " + d[1] + " Z ";
        }
        ShapePath {
            fillColor: deck.look === "paper" ? deck.mocha.base : Qt.darker(deck.skin.panelA, 1.3)
            strokeColor: deck.look === "paper" ? deck.mocha.text : Qt.rgba(0, 0, 0, 0.35)
            strokeWidth: deck.look === "paper" ? 1.5 : 1
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: deck.doorOpen > 0.005 ? doorEdge.poly(doorEdge.p0, doorEdge.p1, doorEdge.p2, doorEdge.p3) + doorEdge.poly(doorEdge.q0, doorEdge.q1, doorEdge.q2, doorEdge.q3) : "M 0 0"
            }
        }
    }
    function rrect(x, y, w, h, r) {
        return "M " + (x + r) + " " + y + " L " + (x + w - r) + " " + y
            + " A " + r + " " + r + " 0 0 1 " + (x + w) + " " + (y + r)
            + " L " + (x + w) + " " + (y + h - r)
            + " A " + r + " " + r + " 0 0 1 " + (x + w - r) + " " + (y + h)
            + " L " + (x + r) + " " + (y + h)
            + " A " + r + " " + r + " 0 0 1 " + x + " " + (y + h - r)
            + " L " + x + " " + (y + r)
            + " A " + r + " " + r + " 0 0 1 " + (x + r) + " " + y + " Z ";
    }
    // Lijnen van het front (Mono geborsteld, Neon scanlijnen) in een strook;
    // ze lopen door op dezelfde hoogte als op het front.
    component LineStrip: Item {
        id: strip
        property string look: ""
        property color accent: "white"
        property real step: 3
        clip: true
        Repeater {
            model: strip.look === "mono" || strip.look === "neon" ? Math.max(0, Math.ceil(strip.height / strip.step) + 1) : 0
            Rectangle {
                required property int index
                readonly property int k: Math.floor(strip.y / strip.step) + index
                width: strip.width
                y: (k + 0.5) * strip.step - strip.y
                height: 1
                color: strip.look === "neon" ? Qt.rgba(strip.accent.r, strip.accent.g, strip.accent.b, 0.035)
                    : (k % 3 === 0 ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.035))
            }
        }
    }
    // Dezelfde vorm tegen de klok in (voor een gat).
    function rrectCcw(x, y, w, h, r) {
        return "M " + (x + r) + " " + y
            + " A " + r + " " + r + " 0 0 0 " + x + " " + (y + r)
            + " L " + x + " " + (y + h - r)
            + " A " + r + " " + r + " 0 0 0 " + (x + r) + " " + (y + h)
            + " L " + (x + w - r) + " " + (y + h)
            + " A " + r + " " + r + " 0 0 0 " + (x + w) + " " + (y + h - r)
            + " L " + (x + w) + " " + (y + r)
            + " A " + r + " " + r + " 0 0 0 " + (x + w - r) + " " + y + " Z ";
    }
    readonly property real rimW: u * 1.1
    Item {
        id: door
        width: deck.width
        height: deck.height
        transform: Matrix4x4 { matrix: deck.doorMatrix }

        // Plaat met een gat voor het venster, in dezelfde kleur als het front.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // Het gat loopt tegen de klok in; een expliciete fillRule laat
            // het gat onder een perspectieftransform dichtlopen.
            ShapePath {
                strokeColor: deck.look === "paper" ? deck.mocha.text : Qt.rgba(0, 0, 0, 0.3)
                strokeWidth: deck.look === "paper" ? 1.5 : 1
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: deck.height
                    GradientStop { position: 0.0; color: deck.skin.panelA }
                    GradientStop { position: 1.0; color: deck.skin.panelB }
                }
                PathSvg {
                    path: deck.rrect(deck.doorX, deck.doorY, deck.doorW, deck.doorH, deck.doorR)
                        + deck.rrectCcw(deck.winX - deck.rimW, deck.winY - deck.rimW, deck.winW + 2 * deck.rimW, deck.winH + 2 * deck.rimW, deck.winH / 2 + deck.rimW)
                }
            }
        }
        // Mono: geborsteld; Neon: scanlijnen, naast het venster.
        LineStrip { look: deck.look; accent: deck.accent; step: Math.max(3, deck.u * 1.2); x: deck.doorX + deck.doorR; y: deck.doorY + 1; width: deck.doorW - 2 * deck.doorR; height: deck.winY - deck.rimW - deck.doorY - 1 }
        LineStrip { look: deck.look; accent: deck.accent; step: Math.max(3, deck.u * 1.2); x: deck.doorX + deck.doorR; y: deck.winY + deck.winH + deck.rimW; width: deck.doorW - 2 * deck.doorR; height: deck.hingeY - deck.winY - deck.winH - deck.rimW - 1 }
        LineStrip { look: deck.look; accent: deck.accent; step: Math.max(3, deck.u * 1.2); x: deck.doorX + 1; y: deck.winY - deck.rimW; width: deck.winX - deck.rimW - deck.doorX - 1; height: deck.winH + 2 * deck.rimW }
        LineStrip { look: deck.look; accent: deck.accent; step: Math.max(3, deck.u * 1.2); x: deck.winX + deck.winW + deck.rimW; y: deck.winY - deck.rimW; width: deck.doorX + deck.doorW - deck.winX - deck.winW - deck.rimW - 1; height: deck.winH + 2 * deck.rimW }
        // Lichte rand bovenaan het klepje.
        Rectangle {
            visible: deck.look !== "paper"
            x: deck.doorX + deck.doorR
            y: deck.doorY + 1
            width: deck.doorW - 2 * deck.doorR
            height: Math.max(1, deck.u * 0.3)
            color: Qt.rgba(1, 1, 1, deck.look === "neon" ? 0.06 : 0.16)
        }

        // Verzonken rand om het venster; de rand vangt onderaan licht.
        Rectangle {
            x: deck.winX - deck.rimW
            y: deck.winY - deck.rimW
            width: deck.winW + 2 * deck.rimW
            height: deck.winH + 2 * deck.rimW
            radius: height / 2
            color: "transparent"
            border.width: deck.look === "paper" ? 2 : deck.rimW
            border.color: deck.look === "paper" ? deck.mocha.text : Qt.darker(deck.skin.panelB, 1.5)
            Rectangle {
                visible: deck.look !== "paper"
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: Math.max(1, deck.u * 0.35)
                border.color: Qt.rgba(1, 1, 1, 0.12)
            }
        }
        Rectangle {
            visible: deck.look === "paper"
            x: deck.winX
            y: deck.winY
            width: deck.winW
            height: deck.winH
            radius: height / 2
            color: "transparent"
            border.width: 1.5
            border.color: deck.mocha.text
        }
        // Glas: vaste reflectie bovenin (het licht staat stil), schaduw van de
        // rand langs de bovenkant.
        Rectangle {
            visible: deck.look !== "paper"
            x: deck.winX
            y: deck.winY
            width: deck.winW
            height: deck.winH
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                GradientStop { position: 0.12; color: Qt.rgba(1, 1, 1, deck.look === "neon" ? 0.05 : 0.10) }
                GradientStop { position: 0.3; color: "transparent" }
                GradientStop { position: 0.85; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.06) }
            }
        }
        MouseArea {
            x: deck.winX
            y: deck.winY
            width: deck.winW
            height: deck.winH
            cursorShape: deck.seekable ? Qt.SizeHorCursor : Qt.PointingHandCursor
            preventStealing: true
            property real startX: 0
            property real startPos: 0
            property bool moved: false
            function at(mx) { return Math.max(0, Math.min(1, startPos + (mx - startX) / width)); }
            onPressed: mouse => { startX = mouse.x; startPos = deck.position; moved = false; }
            onPositionChanged: mouse => {
                if (!pressed || !deck.seekable) return;
                if (!moved && Math.abs(mouse.x - startX) > 4) { moved = true; deck.scrubPressed(at(mouse.x)); }
                if (moved) deck.scrubMoved(at(mouse.x));
            }
            onReleased: mouse => { if (moved) deck.scrubReleased(at(mouse.x)); else deck.togglePlay(); }
        }

        // Looprichting met lampje.
        Row {
            x: deck.u * 22
            y: deck.u * 23
            spacing: deck.u * 1.6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(2.5, deck.u * 1.6)
                height: width
                radius: width / 2
                color: deck.playing ? deck.skin.led : Qt.rgba(0.5, 0.5, 0.5, 0.35)
                border.width: deck.look === "paper" ? 1 : 0
                border.color: deck.mocha.text
                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(400) } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "⟶"
                font.pixelSize: Math.max(6, deck.u * 4.2)
                color: deck.playing ? deck.role("ledAlt", deck.accent) : deck.skin.print
                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(400) } }
            }
        }
        // Opdruk onderaan.
        Text {
            visible: deck.detail > 0.01
            opacity: deck.detail
            x: deck.u * 12
            y: deck.u * 64.5
            text: deck.look === "neon" ? "STEREO // AUTO REVERSE" : "STEREO CASSETTE PLAYER"
            font.family: ThemeConfig.monoFont
            font.pixelSize: Math.max(6, deck.u * 1.9)
            font.letterSpacing: deck.u * 0.25
            color: deck.skin.print
        }
        Text {
            visible: deck.detail > 0.01
            opacity: deck.detail
            x: deck.doorX + deck.doorW - deck.u * 4 - width
            y: deck.u * 64.5
            text: "TYPE I · II"
            font.family: ThemeConfig.monoFont
            font.pixelSize: Math.max(6, deck.u * 1.9)
            font.letterSpacing: deck.u * 0.25
            color: deck.skin.print
        }
    }
}
