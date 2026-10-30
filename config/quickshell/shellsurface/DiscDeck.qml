import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import ".."

// Bovenkant van een draagbare cd-speler (discman), gedeeld door de
// mediakaart op het bureaublad (klein, plat) en DiscmanStageContent (groot,
// in perspectief): een ronde kast zoals de klassieke Sony, een rond deksel
// met een rookglazen venster waaronder de cd draait (met de hoes als
// opdruk), en daaronder op het deksel een lcd met titel, artiest, tijd en
// een balk om te spoelen. Het licht op glas
// en cd staat stil; alleen de opdruk draait. De afwerking volgt het thema.
Item {
    id: deck

    required property var mocha
    property color accent: mocha.primary
    property string title: ""
    property string artist: ""
    property string artUrl: ""
    // Album of hoes-URL; verandert dit, dan wisselt de cd: hij draait uit,
    // het deksel springt op, de oude cd schuift eruit en de nieuwe erin.
    property string trackKey: ""
    property bool playing: false
    property bool tracking: false
    // Waar de cd staat (0..1), en de lengte in seconden voor de tijd.
    property real position: 0
    property real length: 0
    property int trackNumber: 1
    property bool compact: false
    property real detail: compact ? 0 : 1
    property bool marquee: true
    // Zoeken (spoelknop vastgehouden): de cd draait sneller.
    property bool searching: false
    // De balk op de lcd is een spoelbalk.
    property bool seekable: false
    property real viewLean: 0
    signal togglePlay()
    signal scrubPressed(real fraction)
    signal scrubMoved(real fraction)
    signal scrubReleased(real fraction)

    readonly property real u: width / 100

    // Tekst langs een cirkel (midden van het item); onderaan leesbaar van
    // links naar rechts, net als bovenaan.
    component ArcText: Item {
        id: arc
        property string text: ""
        property real radius: 50
        property real center: -90
        property string fontFamily: ""
        property real pixelSize: 10
        property int weight: Font.Normal
        property bool italic: false
        property real charWidth: 6
        property color color: "white"
        readonly property bool below: center > 0
        readonly property real step: charWidth / Math.max(1, radius) * 180 / Math.PI
        Repeater {
            model: arc.text.length
            Text {
                required property int index
                readonly property real ang: arc.center + (arc.below ? -1 : 1) * (index - (arc.text.length - 1) / 2) * arc.step
                x: arc.width / 2 + Math.cos(ang * Math.PI / 180) * arc.radius - width / 2
                y: arc.height / 2 + Math.sin(ang * Math.PI / 180) * arc.radius - height / 2
                rotation: arc.below ? ang - 90 : ang + 90
                text: arc.text.charAt(index)
                font.family: arc.fontFamily
                font.pixelSize: arc.pixelSize
                font.weight: arc.weight
                font.italic: arc.italic
                color: arc.color
            }
        }
    }
    readonly property alias bodyRadius: body.radius
    // Zijwand van de kap: altijd duidelijk donkerder dan de belichte kap.
    function luma(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }
    readonly property color lidWall: luma(skin.lidSide) > luma(skin.lidB) * 0.8 ? Qt.darker(skin.lidB, 1.4) : skin.lidSide

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
    readonly property var skin: {
        let m = mocha, a = accent;
        let sec = secondary, ter = tertiary, secC = secondaryContainer, terC = tertiaryContainer, priC = primaryContainer;
        let ink = m.text;
        if (look === "wood") {
            // Organic: mat kunststof (geen hout: een walkman of discman is
            // van plastic) in dezelfde themakleur als de walkman (primary
            // container, een vleugje tertiary), en geborsteld metaal.
            let wood = Qt.tint(Qt.tint(Qt.lighter(m.surface2, 1.25), Qt.rgba(priC.r, priC.g, priC.b, 0.68)), Qt.rgba(terC.r, terC.g, terC.b, 0.1));
            let cream = Qt.tint(m.text, Qt.rgba(terC.r, terC.g, terC.b, 0.18));
            let metal = Qt.tint(m.subtext1, Qt.rgba(sec.r, sec.g, sec.b, 0.24));
            let lcd = Qt.tint(Qt.darker(cream, 1.18), Qt.rgba(ter.r, ter.g, ter.b, 0.22));
            return {
                bodyA: Qt.lighter(wood, 1.12), bodyB: Qt.darker(wood, 1.18),
                border: Qt.darker(wood, 1.7), borderW: 1.5, radius: 14,
                lidA: Qt.lighter(wood, 1.2), lidB: Qt.darker(wood, 1.08), lidSide: Qt.darker(wood, 1.6), lidBorder: Qt.darker(wood, 1.5),
                ring: metal, glass: Qt.rgba(m.crust.r, m.crust.g, m.crust.b, 0.42),
                mirrorA: Qt.tint(metal, Qt.rgba(ter.r, ter.g, ter.b, 0.2)), mirrorB: Qt.tint(Qt.darker(metal, 1.5), Qt.rgba(sec.r, sec.g, sec.b, 0.3)),
                print: terC, print2: secC, printText: cream,
                lcdBg: lcd, lcdText: Qt.darker(m.crust, 1.1), lcdText2: Qt.darker(Qt.tint(m.crust, Qt.rgba(sec.r, sec.g, sec.b, 0.55)), 1.2),
                lcdText3: Qt.darker(Qt.tint(m.crust, Qt.rgba(ter.r, ter.g, ter.b, 0.45)), 1.3), lcdOff: Qt.rgba(0, 0, 0, 0.1),
                brandColor: Qt.rgba(cream.r, cream.g, cream.b, 0.62), led: ter, ledAlt: sec,
                frontA: Qt.darker(Qt.tint(wood, Qt.rgba(priC.r, priC.g, priC.b, 0.06)), 1.5), frontB: Qt.darker(wood, 2.3), frontEdge: Qt.darker(wood, 2.6),
                capA: cream, capB: Qt.darker(cream, 1.12), capHover: Qt.lighter(cream, 1.08),
                capSide: Qt.darker(cream, 1.8), capText: m.crust, capBorder: Qt.darker(cream, 1.4), lit: a, capShine: 0.5,
                metal: metal, screw: metal, hint: m.subtext0
            };
        }
        if (look === "neon") return {
            bodyA: Qt.tint(m.mantle, Qt.rgba(a.r, a.g, a.b, 0.08)), bodyB: m.crust,
            border: a, borderW: 1.5, radius: 6,
            lidA: Qt.tint(m.mantle, Qt.rgba(a.r, a.g, a.b, 0.10)), lidB: m.crust, lidSide: Qt.darker(m.crust, 1.5), lidBorder: Qt.rgba(a.r, a.g, a.b, 0.6),
            ring: a, glass: Qt.rgba(0, 0, 0, 0.42),
            mirrorA: Qt.tint(m.surface1, Qt.rgba(a.r, a.g, a.b, 0.3)), mirrorB: Qt.tint(m.crust, Qt.rgba(sec.r, sec.g, sec.b, 0.4)),
            print: Qt.tint(m.crust, Qt.rgba(a.r, a.g, a.b, 0.25)), print2: Qt.tint(m.crust, Qt.rgba(sec.r, sec.g, sec.b, 0.25)), printText: a,
            lcdBg: Qt.darker(m.crust, 1.5), lcdText: a, lcdText2: sec, lcdText3: ter, lcdOff: Qt.rgba(a.r, a.g, a.b, 0.12),
            brandColor: Qt.rgba(a.r, a.g, a.b, 0.75), led: m.pink, ledAlt: sec,
            frontA: Qt.tint(m.crust, Qt.rgba(a.r, a.g, a.b, 0.05)), frontB: m.crust, frontEdge: a,
            capA: Qt.tint(m.mantle, Qt.rgba(a.r, a.g, a.b, 0.10)), capB: m.crust,
            capHover: Qt.tint(m.surface0, Qt.rgba(a.r, a.g, a.b, 0.18)), capSide: Qt.darker(m.crust, 1.5),
            capText: a, capBorder: Qt.rgba(a.r, a.g, a.b, 0.55), lit: m.pink, litText: true,
            metal: a, screw: a, hint: a
        };
        if (look === "paper") return {
            bodyA: m.base, bodyB: m.base, border: ink, borderW: 2, radius: 8,
            lidA: m.base, lidB: m.base, lidSide: ink, lidBorder: ink,
            ring: ink, glass: "transparent", mirrorA: m.base, mirrorB: m.base,
            print: m.base, print2: Qt.darker(m.base, 1.08), printText: ink,
            lcdBg: ink, lcdText: m.base, lcdText2: m.base, lcdText3: m.base, lcdOff: Qt.rgba(m.base.r, m.base.g, m.base.b, 0.2),
            brandColor: Qt.rgba(ink.r, ink.g, ink.b, 0.7), led: a, ledAlt: ink,
            frontA: Qt.darker(m.base, 1.04), frontB: Qt.darker(m.base, 1.08), frontEdge: ink,
            capA: m.base, capB: m.base, capHover: Qt.tint(m.base, Qt.rgba(a.r, a.g, a.b, 0.15)), capSide: ink,
            capText: ink, capBorder: ink, lit: a, capShine: 0,
            metal: ink, screw: ink, hint: ink
        };
        return {
            bodyA: Qt.tint(Qt.lighter(m.surface0, 1.18), Qt.rgba(secC.r, secC.g, secC.b, 0.06)), bodyB: m.surface0,
            border: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.16), borderW: 1, radius: Math.max(14, ThemeConfig.styleWidgetRadius + 6),
            lidA: Qt.lighter(m.surface1, 1.12), lidB: m.surface0, lidSide: Qt.darker(m.surface0, 1.6), lidBorder: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.16),
            ring: m.overlay1, glass: Qt.rgba(0, 0, 0, 0.32),
            mirrorA: Qt.tint(m.subtext0, Qt.rgba(ter.r, ter.g, ter.b, 0.15)), mirrorB: Qt.tint(m.surface2, Qt.rgba(sec.r, sec.g, sec.b, 0.25)),
            print: Qt.tint(m.surface1, Qt.rgba(terC.r, terC.g, terC.b, 0.4)), print2: Qt.tint(m.surface1, Qt.rgba(secC.r, secC.g, secC.b, 0.4)), printText: m.text,
            lcdBg: Qt.tint(m.subtext1, Qt.rgba(sec.r, sec.g, sec.b, 0.12)), lcdText: m.crust, lcdText2: Qt.darker(Qt.tint(m.crust, Qt.rgba(sec.r, sec.g, sec.b, 0.5)), 1.2),
            lcdText3: Qt.darker(Qt.tint(m.crust, Qt.rgba(ter.r, ter.g, ter.b, 0.45)), 1.3), lcdOff: Qt.rgba(0, 0, 0, 0.1),
            brandColor: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.45), led: ter, ledAlt: sec,
            frontA: Qt.darker(m.surface0, 1.25), frontB: Qt.darker(m.surface0, 1.7), frontEdge: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.18),
            capA: Qt.lighter(m.surface1, 1.1), capB: m.surface1, capHover: Qt.lighter(m.surface1, 1.25),
            capSide: Qt.darker(m.surface1, 1.6), capText: m.text, capBorder: Qt.rgba(m.text.r, m.text.g, m.text.b, 0.14), lit: a,
            metal: m.overlay2, screw: m.overlay1, hint: m.subtext0
        };
    }

    // --- Draaien -----------------------------------------------------------------
    // Per frame, met een korte aanloop en uitloop zoals een echte motor.
    property real discAngle: 0
    property real angularVelocity: 0
    property real spinSpeed: 160
    function spinState() { return { a: discAngle }; }
    function applySpinState(s) { if (s && s.a !== undefined) discAngle = s.a; }
    FrameAnimation {
        running: deck.visible && ((deck.playing && !deck.swapHold) || deck.searching || deck.angularVelocity > 0.05)
        onTriggered: {
            let dt = Math.min(0.1, Math.max(0, frameTime));
            let target = deck.swapHold ? 0 : deck.searching ? deck.spinSpeed * 2.6 : deck.playing ? deck.spinSpeed : 0;
            deck.angularVelocity += (target - deck.angularVelocity) * (1 - Math.exp(-dt / 0.4));
            if (target === 0 && deck.angularVelocity < 0.05) deck.angularVelocity = 0;
            deck.discAngle = (deck.discAngle + deck.angularVelocity * dt) % 360;
        }
    }

    // --- Cd wisselen bij een nieuw album ------------------------------------------
    // Zoals bij een echte discman: OPEN schuiven, de motor remt, het deksel
    // klapt op (scharnier achter), de cd gaat van de as omhoog en weg, de
    // nieuwe gaat erop en het deksel klikt dicht.
    property string shownKey: ""
    property string shownArt: ""
    // De motor staat stil tijdens de wissel.
    property bool swapHold: false
    // 0..1: schuifje OPEN, deksel (dicht..open), cd (op de as..weg).
    property real openSlide: 0
    property real lidOpen: 0
    property real discOut: 0
    readonly property bool swapping: swapAnim.running
    Component.onCompleted: { shownKey = trackKey; shownArt = artUrl; }
    onTrackKeyChanged: maybeSwap()
    // Net als bij de draaitafel: de nieuwe hoes komt vaak vóór het nieuwe
    // album binnen; even wachten, zodat hij niet eerst op de oude cd staat.
    onArtUrlChanged: {
        if (shownArt === "") shownArt = artUrl;
        else artSettle.restart();
    }
    Timer {
        id: artSettle
        interval: 600
        onTriggered: if (!deck.swapping && deck.trackKey === deck.shownKey) deck.shownArt = deck.artUrl
    }
    function maybeSwap() {
        if (trackKey === shownKey || swapping) return;
        if (shownKey === "" || trackKey === "" || !visible) {
            shownKey = trackKey;
            shownArt = artUrl;
            return;
        }
        swapAnim.restart();
    }
    SequentialAnimation {
        id: swapAnim
        ScriptAction { script: deck.swapHold = true }
        ParallelAnimation {
            NumberAnimation { target: deck; property: "openSlide"; to: 1; duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic }
            PauseAnimation { duration: ThemeConfig.duration(560) }
        }
        ParallelAnimation {
            NumberAnimation { target: deck; property: "lidOpen"; to: 1; duration: ThemeConfig.duration(720); easing.type: Easing.OutCubic }
            NumberAnimation { target: deck; property: "openSlide"; to: 0; duration: ThemeConfig.duration(260); easing.type: Easing.InOutQuad }
        }
        PauseAnimation { duration: ThemeConfig.duration(120) }
        NumberAnimation { target: deck; property: "discOut"; to: 1; duration: ThemeConfig.duration(900); easing.type: Easing.InOutCubic }
        ScriptAction {
            script: {
                deck.shownKey = deck.trackKey;
                deck.shownArt = deck.artUrl;
                deck.discAngle = Math.random() * 360;
            }
        }
        PauseAnimation { duration: ThemeConfig.duration(200) }
        NumberAnimation { target: deck; property: "discOut"; to: 0; duration: ThemeConfig.duration(900); easing.type: Easing.InOutCubic }
        PauseAnimation { duration: ThemeConfig.duration(150) }
        NumberAnimation { target: deck; property: "lidOpen"; to: 0; duration: ThemeConfig.duration(460); easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                deck.swapHold = false;
                if (deck.trackKey === deck.shownKey) deck.shownArt = deck.artUrl;
                deck.maybeSwap();
            }
        }
    }

    // --- 3D: deksel en cd -----------------------------------------------------------
    // Punten op de bovenkant (x, y) met h omhoog. Op de mediakaart kijk je
    // recht van boven; de schermvullende speler geeft zijn camera mee (view).
    property var view: null
    function viewPt(x, y, h) {
        if (view) return view(x, y, h);
        let f = width * 12, s = f / Math.max(1, f - h);
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
    function planePoint(o, ex, ey, x, y) {
        return viewPt(o[0] + x * ex[0] + y * ey[0], o[1] + x * ex[1] + y * ey[1], o[2] + x * ex[2] + y * ey[2]);
    }
    // Een vlak door o met assen ex en ey (3D), voor een item zo groot als de speler.
    function planeMatrix(o, ex, ey) {
        let W = width, H = height;
        return quadMatrix(W, H, [planePoint(o, ex, ey, 0, 0), planePoint(o, ex, ey, W, 0), planePoint(o, ex, ey, W, H), planePoint(o, ex, ey, 0, H)]);
    }
    function ease01(t) { t = Math.max(0, Math.min(1, t)); return t * t * (3 - 2 * t); }
    readonly property matrix4x4 identity: Qt.matrix4x4()

    // Deksel: rond, 88 u, scharnier achter (bovenrand in beeld); open staat
    // het net voorbij rechtop. Op de mediakaart (recht van boven) iets minder,
    // zodat je de kap nog ziet in plaats van de onderkant.
    readonly property real lidX: u * 6
    readonly property real lidY: u * 6
    readonly property real lidD: u * 88
    readonly property real lidDepth: Math.max(1.5, u * 1.2)
    readonly property real lidLean: Math.max(-1, Math.min(1, viewLean))
    readonly property bool flatLook: look === "paper"
    readonly property real lidDx: flatLook ? 0 : lidLean * lidDepth * 0.6
    readonly property real lidDy: flatLook ? 0 : -lidDepth
    readonly property real lidAngle: lidOpen * (view ? 98 : 80) * Math.PI / 180
    readonly property var lidO: [0, lidY * (1 - Math.cos(lidAngle)), -lidY * Math.sin(lidAngle)]
    readonly property var lidEy: [0, Math.cos(lidAngle), Math.sin(lidAngle)]
    readonly property matrix4x4 lidMatrix: lidOpen === 0 ? identity : planeMatrix(lidO, [1, 0, 0], lidEy)
    // Zie je de onderkant van het deksel? (De hoeken lopen dan andersom.)
    readonly property bool lidFlipped: {
        if (lidOpen === 0) return false;
        let a = planePoint(lidO, [1, 0, 0], lidEy, lidX, lidY);
        let b = planePoint(lidO, [1, 0, 0], lidEy, lidX + lidD, lidY);
        let c = planePoint(lidO, [1, 0, 0], lidEy, lidX + lidD, lidY + lidD);
        return (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]) < 0;
    }
    // Venster in het deksel: midden 7 u boven het midden van het deksel.
    readonly property real winCX: lidX + lidD / 2
    readonly property real winCY: lidY + lidD / 2 - u * 7
    readonly property real ringD: u * 54
    readonly property real ringW: Math.max(1.5, u * 1.1)
    readonly property real wellD: ringD - 2 * ringW

    // Cd: 12 cm in een speler van ruim 13, dus bijna zo groot als het
    // deksel; door het venster zie je het midden. Bij een wissel gaat hij
    // van de as omhoog, naar rechtsvoor weg, en komt de nieuwe zo terug.
    readonly property real cdD: u * 72
    readonly property real cdX: winCX - cdD / 2
    readonly property real cdY: winCY - cdD / 2
    readonly property real awayT: ease01((discOut - 0.3) / 0.7)
    readonly property real cdLift: u * (10 * ease01(discOut / 0.3) + 10 * awayT)
    readonly property matrix4x4 cdMatrix: discOut === 0 ? identity
        : planeMatrix([u * 80 * awayT, u * 22 * awayT, cdLift], [1, 0, 0], [0, 1, 0])

    // Rondjes als pad (met de klok mee, of ertegenin voor een gat).
    function circle(cx, cy, r, ccw) {
        let s = ccw ? 0 : 1;
        return "M " + (cx + r) + " " + cy + " A " + r + " " + r + " 0 1 " + s + " " + (cx - r) + " " + cy
            + " A " + r + " " + r + " 0 1 " + s + " " + (cx + r) + " " + cy + " Z ";
    }

    // --- Kast ------------------------------------------------------------------
    Rectangle {
        id: body
        anchors.fill: parent
        radius: width / 2
        border.width: deck.skin.borderW
        border.color: deck.skin.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: deck.skin.bodyA }
            GradientStop { position: 1.0; color: deck.skin.bodyB }
        }
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
        Rectangle {
            visible: deck.look !== "paper"
            anchors.fill: parent
            anchors.margins: body.border.width
            radius: Math.max(0, body.radius - body.border.width)
            color: "transparent"
            border.width: Math.max(1, deck.u * 0.5)
            border.color: Qt.rgba(1, 1, 1, deck.look === "neon" ? 0.04 : 0.08)
        }
    }

    // --- Lade onder het deksel --------------------------------------------------------
    // Alleen te zien als het deksel openstaat: een verzonken lade, de as met
    // de klemkogeltjes en de sleuf met de laserlens.
    readonly property real trayD: cdD + u * 2.4
    Rectangle {
        x: deck.winCX - width / 2
        y: deck.winCY - height / 2
        width: deck.trayD
        height: width
        radius: width / 2
        color: deck.look === "paper" ? deck.mocha.base : Qt.darker(deck.skin.bodyB, 2.2)
        border.width: deck.look === "paper" ? 1.5 : 1
        border.color: deck.look === "paper" ? deck.mocha.text : Qt.rgba(0, 0, 0, 0.5)
        Rectangle {
            visible: deck.look !== "paper"
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.5) }
                GradientStop { position: 0.3; color: "transparent" }
            }
        }
        // Sleuf met de lens, schuin naar linksonder.
        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 + deck.u * 6
            width: deck.u * 7
            height: deck.u * 26
            radius: deck.u * 1.5
            color: deck.look === "paper" ? deck.mocha.base : Qt.rgba(0, 0, 0, 0.45)
            border.width: deck.look === "paper" ? 1.5 : 1
            border.color: deck.look === "paper" ? deck.mocha.text : Qt.rgba(1, 1, 1, 0.06)
            transform: Rotation { origin.x: deck.u * 3.5; origin.y: -deck.u * 6; angle: 35 }
            Rectangle {
                x: parent.width / 2 - width / 2
                y: deck.u * 4
                width: deck.u * 4.4
                height: width
                radius: width / 2
                color: deck.look === "paper" ? deck.mocha.base : Qt.darker(deck.skin.metal, 1.4)
                border.width: deck.look === "paper" ? 1.5 : 1
                border.color: deck.look === "paper" ? deck.mocha.text : Qt.rgba(0, 0, 0, 0.5)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.5
                    height: width
                    radius: width / 2
                    color: deck.look === "paper" ? deck.mocha.text : Qt.tint("#20304a", Qt.rgba(deck.accent.r, deck.accent.g, deck.accent.b, 0.25))
                }
            }
        }
    }
    // As met klem: steekt door het gat van de cd en draait niet zichtbaar.
    Rectangle {
        x: deck.winCX - width / 2
        y: deck.winCY - height / 2
        width: deck.cdD * 0.23
        height: width
        radius: width / 2
        color: deck.look === "paper" ? deck.mocha.base : Qt.darker(deck.skin.ring, 1.25)
        border.width: deck.look === "paper" ? 1.5 : 1
        border.color: deck.look === "paper" ? deck.mocha.text : Qt.rgba(0, 0, 0, 0.4)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.5
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: deck.look === "paper" ? deck.mocha.base : Qt.lighter(deck.skin.ring, 1.25) }
                GradientStop { position: 1.0; color: deck.look === "paper" ? deck.mocha.base : Qt.darker(deck.skin.ring, 1.4) }
            }
            border.width: deck.look === "paper" ? 1 : 0
            border.color: deck.mocha.text
        }
        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property real a: index * 2.094 - 1.57
                width: Math.max(1.5, parent.width * 0.12)
                height: width
                radius: width / 2
                x: parent.width / 2 + Math.cos(a) * parent.width * 0.36 - width / 2
                y: parent.height / 2 + Math.sin(a) * parent.width * 0.36 - height / 2
                color: deck.look === "paper" ? deck.mocha.text : Qt.lighter(deck.skin.metal, 1.2)
            }
        }
    }

    // --- Cd ---------------------------------------------------------------------------
    // Vaste spiegel (het licht staat stil), daarover de draaiende opdruk; in
    // het midden een gat waar de as doorheen steekt.
    Item {
        id: cdLayer
        width: deck.width
        height: deck.height
        // Onder het deksel; als het deksel open is boven de rest van de kast.
        z: deck.lidOpen > 0.5 ? 2.5 : 0.5
        transform: Matrix4x4 { matrix: deck.cdMatrix }
        opacity: 1 - deck.ease01((deck.discOut - 0.6) / 0.4)
        visible: opacity > 0.01
        Item {
            id: cd
            x: deck.cdX
            y: deck.cdY
            width: deck.cdD
            height: width

            Canvas {
                id: mirror
                anchors.fill: parent
                readonly property color a: deck.skin.mirrorA
                readonly property color b: deck.skin.mirrorB
                readonly property color hue1: deck.secondary
                readonly property color hue2: deck.tertiary
                readonly property bool flat: deck.look === "paper"
                onAChanged: requestPaint()
                onBChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.reset();
                    let c = width / 2;
                    ctx.beginPath();
                    ctx.arc(c, c, c - 0.5, 0, Math.PI * 2);
                    if (flat) {
                        ctx.fillStyle = a;
                    } else {
                        let g = ctx.createConicalGradient(c, c, Math.PI / 4);
                        g.addColorStop(0.0, a);
                        g.addColorStop(0.12, Qt.rgba(hue1.r, hue1.g, hue1.b, 0.85));
                        g.addColorStop(0.25, b);
                        g.addColorStop(0.5, a);
                        g.addColorStop(0.62, Qt.rgba(hue2.r, hue2.g, hue2.b, 0.85));
                        g.addColorStop(0.75, b);
                        g.addColorStop(1.0, a);
                        ctx.fillStyle = g;
                    }
                    ctx.fill();
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.35);
                    ctx.stroke();
                    // Doorzichtige ring rond het gat, en het gat zelf (een
                    // volle cirkel tegen de klok in tekent Canvas niet, dus
                    // uitgeknipt).
                    ctx.beginPath();
                    ctx.arc(c, c, c * 0.3, 0, Math.PI * 2);
                    ctx.fillStyle = flat ? Qt.rgba(0, 0, 0, 0) : Qt.rgba(1, 1, 1, 0.12);
                    ctx.fill();
                    if (flat) {
                        ctx.lineWidth = 1;
                        ctx.strokeStyle = deck.mocha.text;
                        ctx.stroke();
                    }
                    ctx.globalCompositeOperation = "destination-out";
                    ctx.beginPath();
                    ctx.arc(c, c, c * 0.125, 0, Math.PI * 2);
                    ctx.fillStyle = "black";
                    ctx.fill();
                    ctx.globalCompositeOperation = "source-over";
                }
            }
            // Draaiende opdruk: de hoes, of anders een eigen ontwerp.
            Item {
                id: printLayer
                anchors.fill: parent
                rotation: deck.discAngle
                Canvas {
                    id: printCanvas
                    anchors.fill: parent
                    visible: !deck.hasArt
                    readonly property color p1: deck.skin.print
                    readonly property color p2: deck.skin.print2
                    readonly property color tx: deck.skin.printText
                    onP1Changed: requestPaint()
                    onP2Changed: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.reset();
                        let c = width / 2;
                        ctx.beginPath();
                        ctx.arc(c, c, c * 0.97, 0, Math.PI * 2);
                        let g = ctx.createRadialGradient(c, c, c * 0.36, c, c, c * 0.97);
                        g.addColorStop(0, Qt.lighter(p1, 1.25));
                        g.addColorStop(1, p1);
                        ctx.fillStyle = g;
                        ctx.fill();
                        // Een zachte baan in de tweede kleur, zodat je het draaien ziet.
                        ctx.beginPath();
                        ctx.arc(c, c, c * 0.97, -0.5, 1.0);
                        ctx.arc(c, c, c * 0.36, 1.0, -0.5, true);
                        ctx.closePath();
                        ctx.fillStyle = Qt.rgba(p2.r, p2.g, p2.b, 0.75);
                        ctx.fill();
                        // Dunne ringen in de themakleuren.
                        let rings = [[0.9, deck.accent], [0.86, deck.secondary], [0.82, deck.tertiary]];
                        for (let r of rings) {
                            ctx.beginPath();
                            ctx.arc(c, c, c * r[0], 0, Math.PI * 2);
                            ctx.lineWidth = Math.max(1, c * 0.012);
                            ctx.strokeStyle = Qt.rgba(r[1].r, r[1].g, r[1].b, 0.75);
                            ctx.stroke();
                        }
                        // Binnenkant vrij: daar zit de spiegelring.
                        ctx.globalCompositeOperation = "destination-out";
                        ctx.beginPath();
                        ctx.arc(c, c, c * 0.36, 0, Math.PI * 2);
                        ctx.fillStyle = "black";
                        ctx.fill();
                        ctx.globalCompositeOperation = "source-over";
                        ctx.fillStyle = tx;
                        ctx.font = "bold " + Math.round(c * 0.11) + "px sans-serif";
                        ctx.textAlign = "center";
                        ctx.fillText("KINGSTRA", c, c * 0.5);
                        ctx.font = Math.round(c * 0.07) + "px sans-serif";
                        ctx.fillText("DIGITAL AUDIO", c, c * 1.56);
                    }
                }
                MultiEffect {
                    anchors.fill: parent
                    visible: deck.hasArt
                    source: art
                    maskEnabled: true
                    maskSource: ringMask
                }
            }
        }
    }

    // --- Deksel met venster -------------------------------------------------------------
    // Eén vlak (alles erop draait mee om het scharnier). De kap steekt iets
    // uit (lidDx, lidDy, dezelfde 3D als de knoppen); het venster is een gat
    // met rookglas, zodat je de cd eronder ziet.
    Item {
        id: lidGroup
        width: deck.width
        height: deck.height
        // Schermvullend staat het open deksel achter de cd; recht van boven
        // (mediakaart) hangt het erboven.
        z: deck.view === null && deck.lidOpen > 0 ? 3 : 1
        transform: Matrix4x4 { matrix: deck.lidMatrix }

        // Schaduw en zijkant van de kap (met hetzelfde gat).
        Shape {
            anchors.fill: parent
            visible: !deck.flatLook && !deck.lidFlipped
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillColor: Qt.rgba(0, 0, 0, 0.13)
                PathSvg { path: deck.circle(deck.lidX + deck.lidD / 2 + deck.lidDepth * 0.2, deck.lidY + deck.lidD / 2 + deck.lidDepth * 0.35, deck.lidD / 2 + 1, false) + deck.circle(deck.winCX, deck.winCY, deck.ringD / 2, true) }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: Qt.darker(deck.lidWall, 1.2)
                PathSvg { path: deck.circle(deck.lidX + deck.lidD / 2, deck.lidY + deck.lidD / 2, deck.lidD / 2, false) + deck.circle(deck.winCX, deck.winCY, deck.ringD / 2, true) }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: deck.lidWall
                PathSvg { path: deck.circle(deck.lidX + deck.lidD / 2 + deck.lidDx * 0.5, deck.lidY + deck.lidD / 2 + deck.lidDy * 0.5, deck.lidD / 2, false) + deck.circle(deck.winCX + deck.lidDx * 0.5, deck.winCY + deck.lidDy * 0.5, deck.ringD / 2, true) }
            }
        }
        // Kap.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: deck.lidFlipped ? Qt.rgba(0, 0, 0, 0.4) : deck.skin.lidBorder
                strokeWidth: deck.look === "paper" ? 2 : 1
                fillGradient: LinearGradient {
                    x1: 0; y1: deck.lidY + deck.lidDy; x2: 0; y2: deck.lidY + deck.lidDy + deck.lidD
                    GradientStop { position: 0.0; color: deck.lidFlipped ? Qt.darker(deck.skin.lidB, 1.35) : deck.skin.lidA }
                    GradientStop { position: 1.0; color: deck.lidFlipped ? Qt.darker(deck.skin.lidB, 1.6) : deck.skin.lidB }
                }
                PathSvg { path: deck.circle(deck.lidX + deck.lidD / 2 + deck.lidDx, deck.lidY + deck.lidD / 2 + deck.lidDy, deck.lidD / 2, false) + deck.circle(deck.winCX + deck.lidDx, deck.winCY + deck.lidDy, deck.ringD / 2, true) }
            }
        }
        // Glans langs de bovenrand van de kap.
        Rectangle {
            visible: !deck.flatLook && !deck.lidFlipped
            x: deck.lidX + deck.lidDx + deck.lidD * 0.25
            y: deck.lidY + deck.lidDy + deck.lidD * 0.067 + 1
            width: deck.lidD * 0.5
            height: 1
            color: Qt.rgba(1, 1, 1, 0.35)
        }

        Item {
            id: lidTop
            x: deck.lidX + deck.lidDx
            y: deck.lidY + deck.lidDy
            width: deck.lidD
            height: deck.lidD

            // Opdruk langs de ronding van het deksel: merk boven, tekst onder.
            ArcText {
                anchors.fill: parent
                visible: deck.detail > 0.01 && !deck.lidFlipped
                opacity: deck.detail
                radius: deck.u * 39.5
                center: -90
                text: deck.look === "paper" ? "kingstra" : "KINGSTRA"
                fontFamily: ThemeConfig.displayFont
                pixelSize: Math.max(8, deck.u * 3.2)
                weight: Font.Black
                italic: deck.look !== "neon"
                charWidth: pixelSize * 0.82
                color: deck.skin.brandColor
            }
            ArcText {
                anchors.fill: parent
                visible: deck.detail > 0.01 && !deck.lidFlipped
                opacity: deck.detail
                radius: deck.u * 39.5
                center: 90
                text: deck.look === "neon" ? "DIGITAL // ANTI-SKIP" : "COMPACT DISC · ANTI-SKIP"
                fontFamily: ThemeConfig.monoFont
                pixelSize: Math.max(7, deck.u * 1.8)
                charWidth: pixelSize * 0.62 + deck.u * 0.2
                color: deck.skin.brandColor
            }

            // Metalen ring om het venster.
            Rectangle {
                id: ring
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -deck.u * 7
                width: deck.ringD
                height: width
                radius: width / 2
                color: "transparent"
                border.width: deck.ringW
                border.color: deck.lidFlipped ? Qt.darker(deck.skin.ring, 1.5) : deck.skin.ring
            }
            // Venster: rookglas met vaste glans; daaronder de cd.
            Item {
                id: well
                anchors.centerIn: ring
                width: deck.wellD
                height: width

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: deck.skin.glass
                    opacity: 0.6
                    border.width: Math.max(1, deck.u * 0.4)
                    border.color: Qt.rgba(0, 0, 0, deck.look === "paper" ? 0 : 0.45)
                }
                Item {
                    visible: deck.look !== "paper" && !deck.lidFlipped
                    anchors.fill: parent
                    layer.enabled: visible
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: wellMask
                    }
                    Rectangle {
                        width: parent.width * 0.22
                        height: parent.height * 1.4
                        x: parent.width * 0.16
                        y: -parent.height * 0.2
                        rotation: 34
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, deck.look === "neon" ? 0.06 : 0.12) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                    Rectangle {
                        width: parent.width * 0.06
                        height: parent.height * 1.4
                        x: parent.width * 0.44
                        y: -parent.height * 0.2
                        rotation: 34
                        color: Qt.rgba(1, 1, 1, deck.look === "neon" ? 0.03 : 0.06)
                    }
                    // Schaduw van de deksel-rand op het glas: verzonken.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                            GradientStop { position: 0.12; color: "transparent" }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                }
                Rectangle {
                    id: wellMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: deck.togglePlay()
                }
            }
        }

        // --- Lcd (op het deksel, onder het venster) ---

        Rectangle {
            id: lcdBezel
            visible: !deck.lidFlipped
            // Op het deksel, onder het venster (volgt de kap van het deksel).
            x: deck.lidX + deck.lidDx + deck.u * 22
            y: deck.lidY + deck.lidDy + deck.u * 65.5
            width: deck.u * 44
            height: deck.u * 12
            radius: deck.u * (deck.look === "neon" ? 1 : 2)
            color: deck.look === "paper" ? deck.mocha.text : Qt.darker(deck.skin.bodyB, 1.6)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.5)
            Rectangle {
                id: lcd
                anchors.fill: parent
                anchors.margins: Math.max(1.5, deck.u * 0.9)
                radius: Math.max(1, parent.radius - 1)
                color: deck.skin.lcdBg
                clip: true
                // Verzonken: schaduw langs de bovenrand.
                Rectangle {
                    visible: deck.look !== "paper"
                    width: parent.width
                    height: Math.max(2, parent.height * 0.18)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                readonly property real px: height / 10
                // Regel 1: nummer, afspeelteken en lopende titel.
                Row {
                    id: lcdTop
                    x: lcd.px * 1.2
                    y: lcd.px * 0.9
                    spacing: lcd.px * 0.9
                    visible: deck.detail > 0.01
                    opacity: deck.detail
                    Text {
                        text: (deck.trackNumber < 10 ? "0" : "") + deck.trackNumber
                        font.family: ThemeConfig.monoFont
                        font.pixelSize: lcd.px * 3
                        font.weight: Font.Bold
                        color: deck.skin.lcdText3
                    }
                    Text {
                        text: deck.playing ? "▶" : "Ⅱ"
                        font.pixelSize: lcd.px * 2.8
                        color: deck.skin.lcdText
                    }
                }
                MarqueeText {
                    x: lcdTop.x + lcdTop.width + lcd.px * 1.2
                    y: lcd.px * 0.9
                    width: lcd.width - x - lcd.px * 1.2
                    visible: deck.detail > 0.01
                    opacity: deck.detail
                    text: deck.swapHold ? "OPEN" : deck.title !== "" ? deck.title : "Geen nummer"
                    color: deck.skin.lcdText
                    pixelSize: lcd.px * 3
                    fontWeight: Font.Bold
                    running: deck.marquee && !deck.compact
                }
                // Regel 2: artiest en tijd.
                Text {
                    visible: deck.detail > 0.01
                    opacity: deck.detail
                    x: lcd.px * 1.2
                    y: lcd.px * 4.2
                    width: lcd.width * 0.62
                    text: deck.swapHold ? "" : deck.artist
                    elide: Text.ElideRight
                    font.family: ThemeConfig.monoFont
                    font.pixelSize: lcd.px * 2.5
                    color: deck.skin.lcdText2
                }
                // Tijd: groot zolang er geen details zijn (klein op het bureaublad),
                // daarna klein naast de artiest; ze lopen in elkaar over.
                Text {
                    visible: opacity > 0.01
                    opacity: 1 - deck.detail
                    anchors.right: parent.right
                    anchors.rightMargin: lcd.px * 1.2
                    y: (lcd.height - height) / 2 - lcd.px * 1.2
                    text: deck.tracking ? deck.clock(deck.position * deck.length) : "-:--"
                    font.family: ThemeConfig.monoFont
                    font.pixelSize: lcd.px * 4
                    font.weight: Font.Bold
                    color: deck.skin.lcdText3
                }
                Text {
                    visible: deck.detail > 0.01
                    opacity: deck.detail
                    anchors.right: parent.right
                    anchors.rightMargin: lcd.px * 1.2
                    y: lcd.px * 4.1
                    text: deck.tracking ? deck.clock(deck.position * deck.length) : "-:--"
                    font.family: ThemeConfig.monoFont
                    font.pixelSize: lcd.px * 2.6
                    font.weight: Font.Bold
                    color: deck.skin.lcdText3
                }
                // Spoelbalk in segmenten.
                Row {
                    id: segs
                    x: lcd.px * 1.2
                    y: lcd.height - lcd.px * 2.4
                    width: lcd.width - lcd.px * 2.4
                    height: lcd.px * 1.3
                    spacing: lcd.px * 0.35
                    readonly property int count: 28
                    readonly property real segW: (width - spacing * (count - 1)) / count
                    Repeater {
                        model: segs.count
                        Rectangle {
                            required property int index
                            width: segs.segW
                            height: segs.height
                            color: (index + 0.5) / segs.count <= deck.position && deck.tracking ? deck.skin.lcdText : deck.skin.lcdOff
                        }
                    }
                }
                MouseArea {
                    enabled: deck.seekable
                    x: 0
                    y: lcd.height * 0.45
                    width: lcd.width
                    height: lcd.height * 0.55 + 8
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    preventStealing: true
                    function at(mx) { return Math.max(0, Math.min(1, (mx - segs.x) / segs.width)); }
                    onPressed: mouse => deck.scrubPressed(at(mouse.x))
                    onPositionChanged: mouse => { if (pressed) deck.scrubMoved(at(mouse.x)); }
                    onReleased: mouse => deck.scrubReleased(at(mouse.x))
                }
            }
        }
    }

    // Hoes als opdruk: ring van de buitenrand tot de spiegelring.
    readonly property bool hasArt: art.status === Image.Ready
    Image {
        id: art
        source: deck.shownArt
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 384
        sourceSize.height: 384
        visible: false
    }
    Canvas {
        id: ringMask
        width: cd.width
        height: cd.height
        visible: false
        layer.enabled: true
        onWidthChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let c = width / 2;
            ctx.beginPath();
            ctx.arc(c, c, c * 0.97, 0, Math.PI * 2);
            ctx.fillStyle = "white";
            ctx.fill();
            ctx.globalCompositeOperation = "destination-out";
            ctx.beginPath();
            ctx.arc(c, c, c * 0.36, 0, Math.PI * 2);
            ctx.fill();
            ctx.globalCompositeOperation = "source-over";
        }
    }

    // --- Schuifjes OPEN en HOLD ------------------------------------------------
    // Op de rand rond het deksel, langs de omtrek gedraaid.
    Repeater {
        model: [{ a: -148, side: -0.8 }, { a: -32, side: 0.8 }]
        Item {
            id: switchSlot
            required property var modelData
            required property int index
            z: 2
            readonly property real rad: modelData.a * Math.PI / 180
            width: deck.u * 9
            height: deck.u * 2.8
            x: deck.width / 2 + Math.cos(rad) * deck.u * 47 - width / 2
            y: deck.height / 2 + Math.sin(rad) * deck.u * 47 - height / 2
            rotation: modelData.a + 90
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: deck.look === "paper" ? deck.mocha.base : Qt.rgba(0, 0, 0, 0.45)
                border.width: deck.look === "paper" ? 1.5 : 0
                border.color: deck.mocha.text
                Extruded {
                    // OPEN schuift naar voren als het deksel opengaat.
                    x: parent.height * 0.15 + (switchSlot.index === 0 ? deck.openSlide * (parent.width - width - parent.height * 0.3) : 0)
                    y: (parent.height - height) / 2
                    width: parent.width * 0.45
                    height: parent.height * 0.75
                    radius: height / 2
                    depth: Math.max(1.5, height * 0.4)
                    lean: Math.max(-1, Math.min(1, switchSlot.modelData.side + deck.viewLean))
                    flat: deck.look === "paper"
                    faceTop: Qt.lighter(deck.skin.capA, 1.08)
                    faceBottom: deck.skin.capB
                    side: deck.skin.capSide
                    borderWidth: 1
                    borderColor: deck.skin.capBorder
                }
            }
        }
    }


    // --- Lcd -----------------------------------------------------------------------
    function clock(sec) {
        let s = Math.max(0, Math.floor(Number(sec) || 0));
        let m = Math.floor(s / 60);
        let r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
    // Lampje: brandt tijdens afspelen.
    Rectangle {
        z: 2
        x: deck.width / 2 + Math.cos(-0.5 * Math.PI + 0.62) * deck.u * 47 - width / 2
        y: deck.height / 2 + Math.sin(-0.5 * Math.PI + 0.62) * deck.u * 47 - height / 2
        width: Math.max(3, deck.u * 1.8)
        height: width
        radius: width / 2
        color: deck.playing ? deck.skin.led : Qt.rgba(0.5, 0.5, 0.5, 0.35)
        border.width: deck.look === "paper" ? 1 : 0
        border.color: deck.mocha.text
        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(400) } }
    }
}
