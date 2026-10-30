import QtQuick
import QtQuick.Effects
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
        running: deck.visible && (deck.playing || deck.searching || deck.angularVelocity > 0.05)
        onTriggered: {
            let dt = Math.min(0.1, Math.max(0, frameTime));
            let target = deck.searching ? deck.spinSpeed * 2.6 : deck.playing ? deck.spinSpeed : 0;
            deck.angularVelocity += (target - deck.angularVelocity) * (1 - Math.exp(-dt / 0.4));
            if (target === 0 && deck.angularVelocity < 0.05) deck.angularVelocity = 0;
            deck.discAngle = (deck.discAngle + deck.angularVelocity * dt) % 360;
        }
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

    // --- Deksel met venster -------------------------------------------------------
    // Het deksel steekt iets uit (zelfde 3D als de knoppen); alles erop
    // ligt op de kap (lid.dx, lid.dy).
    Extruded {
        id: lid
        x: deck.u * 6
        y: deck.u * 6
        width: deck.u * 88
        height: width
        radius: width / 2
        depth: Math.max(1.5, deck.u * 1.2)
        lean: Math.max(-1, Math.min(1, deck.viewLean))
        flat: deck.look === "paper"
        faceTop: deck.skin.lidA
        faceBottom: deck.skin.lidB
        side: deck.skin.lidSide
        borderWidth: deck.look === "paper" ? 2 : 1
        borderColor: deck.skin.lidBorder
        shadowStrength: 0.8
    }
    Item {
        id: lidTop
        x: lid.x + lid.dx
        y: lid.y + lid.dy
        width: lid.width
        height: lid.height

        // Opdruk langs de ronding van het deksel: merk boven, tekst onder.
        ArcText {
            anchors.fill: parent
            visible: deck.detail > 0.01
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
            visible: deck.detail > 0.01
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
            width: deck.u * 54
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1.5, deck.u * 1.1)
            border.color: deck.skin.ring
        }
        // Verzonken venster: daaronder de cd.
        Item {
            id: well
            anchors.centerIn: ring
            width: ring.width - ring.border.width * 2
            height: width

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: deck.look === "paper" ? deck.mocha.base : Qt.darker(deck.skin.lidB, 1.8)
            }
            // De cd: vaste spiegelring (het licht staat stil), daarover
            // de draaiende opdruk.
            Item {
                id: cd
                anchors.centerIn: parent
                width: parent.width * 0.94
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
                            ctx.arc(c, c, c * 0.36, 0, Math.PI * 2, true);
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
                            ctx.fillStyle = tx;
                            ctx.font = "bold " + Math.round(c * 0.11) + "px sans-serif";
                            ctx.textAlign = "center";
                            ctx.fillText("KINGSTRA", c, c * 0.32);
                            ctx.font = Math.round(c * 0.07) + "px sans-serif";
                            ctx.fillText("DIGITAL AUDIO", c, c * 1.78);
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
                // Middenstuk: as met de klem, draait niet zichtbaar.
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.2
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
                }
            }
            // Rookglas met vaste glans.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: deck.skin.glass
                opacity: 0.6
                border.width: Math.max(1, deck.u * 0.4)
                border.color: Qt.rgba(0, 0, 0, deck.look === "paper" ? 0 : 0.45)
            }
            Item {
                visible: deck.look !== "paper"
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

    // Hoes als opdruk: ring van de buitenrand tot de spiegelring.
    readonly property bool hasArt: art.status === Image.Ready
    Image {
        id: art
        source: deck.artUrl
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
            ctx.arc(c, c, c * 0.36, 0, Math.PI * 2, true);
            ctx.fillStyle = "white";
            ctx.fill();
        }
    }

    // --- Schuifjes OPEN en HOLD ------------------------------------------------
    // Op de rand rond het deksel, langs de omtrek gedraaid.
    Repeater {
        model: [{ a: -148, side: -0.8 }, { a: -32, side: 0.8 }]
        Item {
            id: switchSlot
            required property var modelData
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
                    x: parent.height * 0.15
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
    Rectangle {
        id: lcdBezel
        // Op het deksel, onder het venster (volgt de kap van het deksel).
        x: lid.x + lid.dx + deck.u * 22
        y: lid.y + lid.dy + deck.u * 65.5
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
                text: deck.title !== "" ? deck.title : "Geen nummer"
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
                text: deck.artist
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
    // Lampje: brandt tijdens afspelen.
    Rectangle {
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
