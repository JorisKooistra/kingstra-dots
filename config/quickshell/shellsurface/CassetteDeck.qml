import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import ".."

// Bovenkant van een draagbare cassettespeler (walkman), gedeeld door de
// mediakaart op het bureaublad (klein, plat) en CassetteStageContent (groot,
// in perspectief): een kast met een venster, daarachter een heldere
// cassette met het label (titel en artiest) en twee spoelen. Het tapepakket
// links krimpt en rechts groeit met de voortgang; bij spoelen winden de
// spoelen zichtbaar snel door. De afwerking volgt het thema (skin).
Item {
    id: deck

    required property var mocha
    property color accent: mocha.primary
    property string title: ""
    property string artist: ""
    property bool playing: false
    // Waar de tape staat (0..1). De eigenaar geeft tijdens spoelen het doel
    // door; de spoelen winden er zichtbaar naartoe.
    property real position: 0
    property bool compact: false
    // 0..1: hoeveel van de kleine tekst zichtbaar is (zie VinylStage).
    property real detail: compact ? 0 : 1
    // Lopende titel alleen als het stil staat (niet tijdens de overgang).
    property bool marquee: true
    property real viewLean: 0
    signal togglePlay()

    readonly property real u: width / 100
    readonly property alias bodyRadius: body.radius

    property string look: {
        let f = ThemeConfig.styleFamily;
        return f === "organic" ? "wood" : f === "neon" ? "neon" : f === "paper" ? "paper" : "mono";
    }
    // Zelfde rollen als de draaitafel: primary voor wat aan staat, accent 2
    // (of secondary) en tertiary voor label, spoelen en lampjes, de
    // containers voor kast en cassette.
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
    readonly property var skin: {
        let m = mocha, a = accent;
        let sec = secondary, ter = tertiary, secC = secondaryContainer, terC = tertiaryContainer, priC = primaryContainer;
        let ink = m.text;
        if (look === "wood") {
            // Walnoot met crème en geborsteld metaal, geen gloed.
            let woodC = m.secondaryContainer !== undefined ? m.secondaryContainer : secC;
            let wood = Qt.tint(Qt.tint(m.surface1, Qt.rgba(woodC.r, woodC.g, woodC.b, 0.16)), Qt.rgba(a.r, a.g, a.b, 0.05));
            let cream = Qt.tint(m.text, Qt.rgba(terC.r, terC.g, terC.b, 0.18));
            let metal = Qt.tint(m.subtext1, Qt.rgba(sec.r, sec.g, sec.b, 0.24));
            return {
                bodyA: Qt.lighter(wood, 1.08), bodyB: Qt.darker(wood, 1.35),
                border: Qt.darker(wood, 2.2), borderW: 2.5, radius: 14,
                bezel: Qt.darker(wood, 1.9), bezelEdge: metal, glass: Qt.rgba(m.crust.r, m.crust.g, m.crust.b, 0.42),
                shellA: Qt.rgba(ter.r * 0.35, ter.g * 0.3, ter.b * 0.25, 0.55), shellB: Qt.rgba(0.05, 0.04, 0.03, 0.62),
                shellEdge: Qt.rgba(cream.r, cream.g, cream.b, 0.28),
                label: cream, labelText: m.crust, labelText2: Qt.darker(Qt.tint(m.crust, Qt.rgba(sec.r, sec.g, sec.b, 0.5)), 1.1),
                stripe: sec, stripe2: ter,
                tape: Qt.darker(Qt.tint(m.crust, Qt.rgba(ter.r, ter.g, ter.b, 0.32)), 1.05),
                hub: cream, hubShade: Qt.darker(cream, 1.5),
                brandColor: Qt.rgba(cream.r, cream.g, cream.b, 0.62), led: ter, ledAlt: sec,
                frontA: Qt.darker(Qt.tint(wood, Qt.rgba(priC.r, priC.g, priC.b, 0.06)), 1.5), frontB: Qt.darker(wood, 2.3), frontEdge: Qt.darker(wood, 2.6),
                capA: cream, capB: Qt.darker(cream, 1.12), capHover: Qt.lighter(cream, 1.08),
                capSide: Qt.darker(cream, 1.8), capText: m.crust, capBorder: Qt.darker(cream, 1.4), lit: a, capShine: 0.5,
                counterBg: m.crust, counterText: cream, counterFrame: metal,
                track: Qt.rgba(0, 0, 0, 0.4), fill: a, needle: metal, metal: metal, screw: metal, hint: m.subtext0
            };
        }
        if (look === "neon") return {
            bodyA: Qt.tint(m.mantle, Qt.rgba(a.r, a.g, a.b, 0.08)), bodyB: m.crust,
            border: a, borderW: 1.5, radius: 6,
            bezel: Qt.darker(m.crust, 1.3), bezelEdge: a, glass: Qt.rgba(0, 0, 0, 0.45),
            shellA: Qt.rgba(a.r, a.g, a.b, 0.07), shellB: Qt.rgba(sec.r, sec.g, sec.b, 0.05),
            shellEdge: Qt.rgba(a.r, a.g, a.b, 0.6),
            label: Qt.tint(m.mantle, Qt.rgba(a.r, a.g, a.b, 0.06)), labelText: a, labelText2: sec,
            stripe: a, stripe2: sec,
            tape: Qt.tint(m.crust, Qt.rgba(sec.r, sec.g, sec.b, 0.22)),
            hub: Qt.tint(m.crust, Qt.rgba(a.r, a.g, a.b, 0.55)), hubShade: a,
            brandColor: Qt.rgba(a.r, a.g, a.b, 0.75), led: m.pink, ledAlt: sec,
            frontA: Qt.tint(m.crust, Qt.rgba(a.r, a.g, a.b, 0.05)), frontB: m.crust, frontEdge: a,
            capA: Qt.tint(m.mantle, Qt.rgba(a.r, a.g, a.b, 0.10)), capB: m.crust,
            capHover: Qt.tint(m.surface0, Qt.rgba(a.r, a.g, a.b, 0.18)), capSide: Qt.darker(m.crust, 1.5),
            capText: a, capBorder: Qt.rgba(a.r, a.g, a.b, 0.55), lit: m.pink, litText: true,
            counterBg: Qt.darker(m.crust, 1.4), counterText: a, counterFrame: Qt.rgba(a.r, a.g, a.b, 0.6),
            track: Qt.rgba(a.r, a.g, a.b, 0.14), fill: a, needle: a, metal: a, screw: a, hint: a
        };
        if (look === "paper") return {
            bodyA: m.base, bodyB: m.base, border: ink, borderW: 2, radius: 8,
            bezel: m.base, bezelEdge: ink, glass: "transparent",
            shellA: m.base, shellB: m.base, shellEdge: ink,
            label: m.base, labelText: ink, labelText2: ink, stripe: Qt.rgba(ink.r, ink.g, ink.b, 0.2), stripe2: Qt.rgba(ink.r, ink.g, ink.b, 0.1),
            tape: Qt.rgba(ink.r, ink.g, ink.b, 0.8), hub: m.base, hubShade: ink,
            brandColor: Qt.rgba(ink.r, ink.g, ink.b, 0.7), led: a, ledAlt: ink,
            frontA: Qt.darker(m.base, 1.04), frontB: Qt.darker(m.base, 1.08), frontEdge: ink,
            capA: m.base, capB: m.base, capHover: Qt.tint(m.base, Qt.rgba(a.r, a.g, a.b, 0.15)), capSide: ink,
            capText: ink, capBorder: ink, lit: a, capShine: 0,
            counterBg: ink, counterText: m.base, counterFrame: ink,
            track: Qt.rgba(ink.r, ink.g, ink.b, 0.15), fill: ink, needle: ink, metal: ink, screw: ink, hint: ink
        };
        return {
            bodyA: Qt.tint(Qt.lighter(m.surface0, 1.18), Qt.rgba(secC.r, secC.g, secC.b, 0.06)), bodyB: m.surface0,
            border: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.16), borderW: 1, radius: Math.max(14, ThemeConfig.styleWidgetRadius + 6),
            bezel: Qt.darker(m.surface0, 1.5), bezelEdge: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.18), glass: Qt.rgba(0, 0, 0, 0.32),
            shellA: Qt.rgba(m.surface2.r, m.surface2.g, m.surface2.b, 0.45), shellB: Qt.rgba(m.crust.r, m.crust.g, m.crust.b, 0.55),
            shellEdge: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.22),
            label: Qt.tint(m.subtext1, Qt.rgba(terC.r, terC.g, terC.b, 0.15)), labelText: m.crust, labelText2: Qt.darker(Qt.tint(m.crust, Qt.rgba(sec.r, sec.g, sec.b, 0.5)), 1.1),
            stripe: a, stripe2: sec,
            tape: Qt.tint(m.crust, Qt.rgba(ter.r, ter.g, ter.b, 0.2)), hub: m.subtext1, hubShade: m.overlay0,
            brandColor: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.45), led: ter, ledAlt: sec,
            frontA: Qt.darker(m.surface0, 1.25), frontB: Qt.darker(m.surface0, 1.7), frontEdge: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.18),
            capA: Qt.lighter(m.surface1, 1.1), capB: m.surface1, capHover: Qt.lighter(m.surface1, 1.25),
            capSide: Qt.darker(m.surface1, 1.6), capText: m.text, capBorder: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.14), lit: a,
            counterBg: Qt.rgba(0, 0, 0, 0.6), counterText: m.text, counterFrame: m.overlay1,
            track: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.12), fill: a, needle: m.overlay2, metal: m.overlay2, screw: m.overlay1, hint: m.subtext0
        };
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
    function spinState() { return { a: reelAngleL, b: reelAngleR }; }
    function applySpinState(s) { if (s && s.a !== undefined) { reelAngleL = s.a; reelAngleR = s.b; } }

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
            // Tapesnelheid (cassette-eenheden per seconde): motor plus winden.
            let v = 15 * deck.motor + (dt > 0 ? step / dt : 0) * 420;
            let toDeg = 180 / Math.PI;
            let wl = Math.max(-900, Math.min(900, v / deck.packL * toDeg));
            let wr = Math.max(-900, Math.min(900, v / deck.packR * toDeg));
            deck.reelAngleL = (deck.reelAngleL + wl * dt) % 360;
            deck.reelAngleR = (deck.reelAngleR + wr * dt) % 360;
        }
    }

    // --- Kast ------------------------------------------------------------------
    Rectangle {
        id: body
        anchors.fill: parent
        radius: Math.min(deck.width * 0.07, deck.skin.radius * deck.u * 0.5)
        border.width: deck.skin.borderW
        border.color: deck.skin.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: deck.skin.bodyA }
            GradientStop { position: 1.0; color: deck.skin.bodyB }
        }
        // Neon: zachte gloed van de rand.
        Rectangle {
            visible: deck.look === "neon"
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 3
            border.color: Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, deck.playing ? 0.5 : 0.28)
            layer.enabled: visible
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: 1.0 }
        }
        WoodGrain {
            visible: deck.look === "wood"
            x: body.border.width
            y: body.border.width
            width: parent.width - 2 * x
            height: parent.height - 2 * y
            radius: Math.max(0, body.radius - body.border.width)
            dark: deck.mocha.crust
            light: deck.mocha.text
            seed: 11
        }
        // Lichte binnenrand: de kast heeft dikte.
        Rectangle {
            visible: deck.look !== "paper"
            anchors.fill: parent
            anchors.margins: body.border.width
            radius: Math.max(0, body.radius - body.border.width)
            color: "transparent"
            border.width: Math.max(1, deck.u * 0.5)
            border.color: Qt.rgba(1, 1, 1, deck.look === "neon" ? 0.04 : 0.08)
        }
        // Mono: fijne lijnen, Neon: raster.
        Repeater {
            model: deck.look === "mono" ? 10 : deck.look === "neon" ? Math.floor(deck.height / Math.max(6, deck.u * 4)) : 0
            Rectangle {
                required property int index
                x: body.radius * 0.6
                width: body.width - body.radius * 1.2
                y: (index + 0.5) * (deck.look === "neon" ? Math.max(6, deck.u * 4) : body.height / 10)
                height: 1
                color: deck.look === "neon" ? Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, 0.05)
                    : Qt.rgba(deck.mocha.text.r, deck.mocha.text.g, deck.mocha.text.b, 0.025)
            }
        }
    }

    // Opschrift boven het venster.
    Text {
        visible: deck.detail > 0.01
        opacity: deck.detail
        x: deck.u * 9
        y: deck.u * 2.6
        text: deck.look === "paper" ? "kingstra" : "KINGSTRA"
        font.family: ThemeConfig.displayFont
        font.pixelSize: Math.max(8, deck.u * 3.6)
        font.weight: Font.Black
        font.italic: deck.look !== "neon"
        font.letterSpacing: deck.u * 0.3
        color: deck.skin.brandColor
    }
    Text {
        visible: deck.detail > 0.01
        opacity: deck.detail
        anchors.right: parent.right
        anchors.rightMargin: deck.u * 9
        y: deck.u * 3.6
        text: deck.look === "neon" ? "STEREO // AUTO REVERSE" : "STEREO CASSETTE PLAYER · AUTO REVERSE"
        font.family: ThemeConfig.monoFont
        font.pixelSize: Math.max(7, deck.u * 1.9)
        font.letterSpacing: deck.u * 0.2
        color: deck.skin.brandColor
    }

    // --- Venster met de cassette --------------------------------------------
    // Verzonken: donkere schaduw langs de bovenrand van de opening.
    Rectangle {
        id: bezel
        x: deck.u * 8
        y: deck.u * 9
        width: deck.u * 84
        height: deck.u * 56.5
        radius: deck.u * 4
        color: deck.skin.bezel
        border.width: deck.look === "paper" ? 2 : 1
        border.color: deck.look === "paper" ? deck.mocha.text : Qt.rgba(0, 0, 0, 0.45)
        Rectangle {
            visible: deck.look !== "paper"
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius
            color: "transparent"
            border.width: Math.max(1, deck.u * 0.35)
            border.color: Qt.rgba(deck.skin.bezelEdge.r, deck.skin.bezelEdge.g, deck.skin.bezelEdge.b, deck.look === "neon" ? 0.7 : 0.35)
        }
    }
    Item {
        id: windowArea
        x: bezel.x + deck.u * 2.4
        y: bezel.y + deck.u * 2.4
        width: bezel.width - deck.u * 4.8
        height: bezel.height - deck.u * 4.8
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: deck.u * 2.4
            color: deck.look === "paper" ? deck.mocha.base : Qt.darker(deck.skin.bezel, 1.4)
            border.width: deck.look === "paper" ? 1.5 : 0
            border.color: deck.mocha.text
        }

        // De cassette: helder plastic, label bovenaan, spoelen eronder.
        Item {
            id: cassette
            readonly property real c: width / 100
            anchors.centerIn: parent
            width: deck.u * 74
            height: width * 0.638

            Rectangle {
                anchors.fill: parent
                radius: cassette.c * 3
                gradient: Gradient {
                    GradientStop { position: 0.0; color: deck.skin.shellA }
                    GradientStop { position: 1.0; color: deck.skin.shellB }
                }
                border.width: deck.look === "paper" ? 1.5 : 1
                border.color: deck.skin.shellEdge
            }
            // Spoelen (achter het label langs, door het heldere plastic).
            TapeReel {
                x: cassette.c * (50 - 21.25) - hubRadius
                y: cassette.c * 34 - hubRadius
                hubRadius: cassette.c * deck.hubR
                packRadius: cassette.c * deck.packL
                angle: deck.reelAngleL
                tape: deck.skin.tape
                hub: deck.skin.hub
                hubShade: deck.skin.hubShade
                flat: deck.look === "paper"
                ink: deck.mocha.text
            }
            TapeReel {
                x: cassette.c * (50 + 21.25) - hubRadius
                y: cassette.c * 34 - hubRadius
                hubRadius: cassette.c * deck.hubR
                packRadius: cassette.c * deck.packR
                angle: deck.reelAngleR
                tape: deck.skin.tape
                hub: deck.skin.hub
                hubShade: deck.skin.hubShade
                flat: deck.look === "paper"
                ink: deck.mocha.text
            }
            // Kijkvenstertje in het midden van de cassette.
            Rectangle {
                x: cassette.c * 34
                y: cassette.c * 26
                width: cassette.c * 32
                height: cassette.c * 16
                radius: cassette.c * 1.6
                color: "transparent"
                border.width: Math.max(1, cassette.c * 0.5)
                border.color: deck.skin.shellEdge
            }
            // Onderkant met de kopopening en de tape die erlangs loopt.
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                readonly property real c: cassette.c
                ShapePath {
                    strokeWidth: deck.look === "paper" ? 1.5 : 1
                    strokeColor: deck.skin.shellEdge
                    fillColor: deck.look === "paper" ? deck.mocha.base : Qt.rgba(0, 0, 0, 0.22)
                    startX: 14 * cassette.c; startY: cassette.height
                    PathLine { x: 19 * cassette.c; y: 52 * cassette.c }
                    PathLine { x: 81 * cassette.c; y: 52 * cassette.c }
                    PathLine { x: 86 * cassette.c; y: cassette.height }
                }
                ShapePath {
                    strokeWidth: Math.max(1, cassette.c * 0.9)
                    strokeColor: deck.skin.tape
                    fillColor: "transparent"
                    startX: 10 * cassette.c; startY: 57 * cassette.c
                    PathLine { x: 90 * cassette.c; y: 57 * cassette.c }
                }
            }
            Repeater {
                model: [[10, 57], [90, 57], [27, 59], [73, 59]]
                Rectangle {
                    required property var modelData
                    width: cassette.c * 3.4
                    height: width
                    radius: width / 2
                    x: modelData[0] * cassette.c - width / 2
                    y: modelData[1] * cassette.c - width / 2
                    color: deck.look === "paper" ? deck.mocha.base : deck.skin.hub
                    border.width: 1
                    border.color: deck.skin.hubShade
                }
            }
            // Schroefjes.
            Repeater {
                model: [[4, 4], [96, 4], [4, 94], [96, 94], [50, 92]]
                Rectangle {
                    required property var modelData
                    width: Math.max(2, cassette.c * 2.4)
                    height: width
                    radius: width / 2
                    x: modelData[0] * cassette.c - width / 2
                    y: modelData[1] / 100 * cassette.height - width / 2
                    color: deck.skin.screw
                    opacity: 0.8
                }
            }
            // Label bovenaan met titel en artiest, en twee kleurbanen.
            Rectangle {
                id: label
                x: cassette.c * 5
                y: cassette.c * 3.5
                width: cassette.c * 90
                height: cassette.c * 17
                radius: cassette.c * 1.4
                color: deck.skin.label
                border.width: deck.look === "paper" ? 1.5 : 0
                border.color: deck.mocha.text
                Rectangle {
                    y: parent.height * 0.74
                    width: parent.width
                    height: parent.height * 0.12
                    color: deck.skin.stripe
                }
                Rectangle {
                    y: parent.height * 0.86
                    width: parent.width
                    height: parent.height * 0.08
                    color: deck.skin.stripe2
                }
                Text {
                    x: cassette.c * 2
                    y: parent.height * 0.08
                    text: "A"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: Math.max(5, parent.height * 0.42)
                    font.weight: Font.Black
                    color: deck.skin.stripe
                }
                MarqueeText {
                    x: cassette.c * 9
                    y: parent.height * 0.06
                    width: parent.width - cassette.c * 12
                    text: deck.title !== "" ? deck.title : "Geen nummer"
                    color: deck.skin.labelText
                    fontFamily: ThemeConfig.uiFont
                    pixelSize: Math.max(4, parent.height * 0.3)
                    fontWeight: Font.Bold
                    running: deck.marquee && !deck.compact
                }
                Text {
                    x: cassette.c * 9
                    y: parent.height * 0.4
                    width: parent.width - cassette.c * 12
                    text: deck.artist
                    elide: Text.ElideRight
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: Math.max(4, parent.height * 0.22)
                    color: deck.skin.labelText2
                }
            }
        }

        // Glans op het glas: staat stil, de spoelen draaien eronder door.
        Rectangle {
            visible: deck.look !== "paper"
            width: parent.width * 0.16
            height: parent.height * 1.6
            x: parent.width * 0.12
            y: -parent.height * 0.3
            rotation: 32
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, deck.look === "neon" ? 0.05 : 0.09) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        Rectangle {
            visible: deck.look !== "paper"
            width: parent.width * 0.05
            height: parent.height * 1.6
            x: parent.width * 0.33
            y: -parent.height * 0.3
            rotation: 32
            color: Qt.rgba(1, 1, 1, deck.look === "neon" ? 0.03 : 0.05)
        }
        // Rookglas over het geheel, schaduw langs de bovenrand (verzonken).
        Rectangle {
            anchors.fill: parent
            color: deck.skin.glass
            opacity: 0.35
        }
        Rectangle {
            visible: deck.look !== "paper"
            width: parent.width
            height: Math.max(3, parent.height * 0.08)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: deck.togglePlay()
        }
    }

    // --- Onderrand: richtingspijlen en lampje --------------------------------
    Row {
        x: deck.u * 9
        y: deck.u * 66.8
        spacing: deck.u * 1.6
        // Lampje: brandt tijdens afspelen.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(3, deck.u * 1.8)
            height: width
            radius: width / 2
            color: deck.playing ? deck.skin.led : Qt.rgba(0.5, 0.5, 0.5, 0.35)
            border.width: deck.look === "paper" ? 1 : 0
            border.color: deck.mocha.text
            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(400) } }
        }
        Text {
            visible: deck.detail > 0.01
            opacity: deck.detail
            anchors.verticalCenter: parent.verticalCenter
            text: "◀"
            font.pixelSize: Math.max(6, deck.u * 2)
            color: deck.skin.brandColor
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "▶"
            font.pixelSize: Math.max(6, deck.u * 2)
            color: deck.playing ? deck.role("ledAlt", deck.accent) : deck.skin.brandColor
            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(400) } }
        }
    }
    Text {
        visible: deck.detail > 0.01
        opacity: deck.detail
        anchors.right: parent.right
        anchors.rightMargin: deck.u * 9
        y: deck.u * 66.4
        text: deck.look === "neon" ? "NR // TYPE II" : "NR · TYPE II · CrO₂"
        font.family: ThemeConfig.monoFont
        font.pixelSize: Math.max(7, deck.u * 1.8)
        font.letterSpacing: deck.u * 0.2
        color: deck.skin.brandColor
    }
}
