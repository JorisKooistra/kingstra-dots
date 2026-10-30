import QtQuick
import QtQuick.Effects
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
Item {
    id: deck

    required property var mocha
    property color accent: mocha.primary
    property string title: ""
    property string artist: ""
    property bool playing: false
    property bool tracking: false
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

    property string look: {
        let f = ThemeConfig.styleFamily;
        return f === "organic" ? "wood" : f === "neon" ? "neon" : f === "paper" ? "paper" : "mono";
    }
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
            // Organic: front in een warme aardetint, mat; geborsteld metaal.
            let panel = Qt.tint(Qt.lighter(m.surface2, 1.35), Qt.rgba(terC.r, terC.g, terC.b, 0.5));
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
    Component.onCompleted: tapePos = Math.max(0, Math.min(1, position))
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
            deck.motor += ((deck.playing ? 1 : 0) - deck.motor) * (1 - Math.exp(-dt / 0.25));
            if (!deck.playing && deck.motor < 0.01) deck.motor = 0;
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

    // --- Venster -----------------------------------------------------------------
    // Verzonken opening in pilvorm; alles erin blijft binnen de vorm.
    readonly property real winX: u * 17
    readonly property real winY: u * 29
    readonly property real winW: u * 66
    readonly property real winH: u * 32
    Rectangle {
        x: deck.winX - deck.u * 1.1
        y: deck.winY - deck.u * 1.1
        width: deck.winW + deck.u * 2.2
        height: deck.winH + deck.u * 2.2
        radius: height / 2
        color: deck.look === "paper" ? deck.mocha.base : Qt.darker(deck.skin.panelB, 1.5)
        border.width: deck.look === "paper" ? 2 : 0
        border.color: deck.mocha.text
        // Rand vangt onderaan licht.
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
        id: win
        x: deck.winX
        y: deck.winY
        width: deck.winW
        height: deck.winH
        radius: height / 2
        color: deck.skin.cassette
        border.width: deck.look === "paper" ? 1.5 : 0
        border.color: deck.mocha.text
    }
    // Cassette-eenheid: de cassette is 76 u breed, de naven staan 42,5 % uit
    // elkaar, op de hoogte van het midden van het venster.
    readonly property real c: u * 0.76
    readonly property real hubY: winY + winH * 0.55
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
        x: deck.u * 27
        y: deck.winY + deck.winH - deck.u * 3.2
        width: deck.u * 46
        height: Math.max(1, deck.u * 0.6)
        color: deck.skin.tape
        opacity: 0.9
    }
    // Label bovenin het venster, met titel en artiest.
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
            text: deck.title !== "" ? deck.title : "Geen nummer"
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
            text: deck.artist
            elide: Text.ElideRight
            font.family: ThemeConfig.uiFont
            font.pixelSize: Math.max(4, parent.height * 0.26)
            color: deck.skin.labelText2
        }
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

    // Opdruk onderaan.
    Text {
        visible: deck.detail > 0.01
        opacity: deck.detail
        x: deck.u * 10
        y: deck.u * 65.5
        text: deck.look === "neon" ? "STEREO // AUTO REVERSE" : "STEREO CASSETTE PLAYER"
        font.family: ThemeConfig.monoFont
        font.pixelSize: Math.max(6, deck.u * 1.9)
        font.letterSpacing: deck.u * 0.25
        color: deck.skin.print
    }
    Text {
        visible: deck.detail > 0.01
        opacity: deck.detail
        anchors.right: parent.right
        anchors.rightMargin: deck.u * 10
        y: deck.u * 65.5
        text: "TYPE I · II"
        font.family: ThemeConfig.monoFont
        font.pixelSize: Math.max(6, deck.u * 1.9)
        font.letterSpacing: deck.u * 0.25
        color: deck.skin.print
    }
}
