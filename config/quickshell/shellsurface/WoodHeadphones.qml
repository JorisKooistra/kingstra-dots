import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import ".."

// Houten koptelefoon als versiering naast de walkman of discman (Organic).
// Hij ligt plat op tafel met de kussens naar beneden, in hetzelfde
// perspectief als het apparaat: k is hoe plat het tafelblad in beeld staat,
// v hoe hoog dingen erop worden. Echt 3D: de schelpen zijn cilinders met een
// leren kussen en een houten kap, de beugel is een leren band op zijn kant
// met metalen schuifstukken en vorken. Alles wordt één keer getekend.
Item {
    id: phones

    required property var mocha
    property color wood: "#8a5a3a"
    property color metal: "#bbbbbb"
    property color leather: "#3a2a20"
    property real k: 0.42
    property real v: 0.92

    readonly property real u: width / 100
    // Tafelcoördinaten in u: X naar rechts, Z naar achteren, H omhoog.
    readonly property real cupR: 21
    readonly property real cupX: 27
    readonly property real cushionH: 5.5
    readonly property real shellH: 13
    readonly property real bandA: 27
    readonly property real bandB: 26
    readonly property real bandZ: cupR * 0.55
    readonly property real band0: 4
    readonly property real band1: 12
    readonly property real cx: width / 2
    readonly property real cy: u * ((bandZ + bandB + 4) * k + band1 * v + 3)
    height: cy + u * (34 * k + 4)
    // Voorkant van de schelpen op tafel: daarmee zet DeviceStage hem neer.
    readonly property real tableFront: sy(-cupR, 0)
    function sx(X) { return cx + X * u; }
    function sy(Z, H) { return cy - (Z * k + H * v) * u; }

    // Ellips: een cirkel, plat gedrukt door het tafelperspectief.
    component Ellipse: Item {
        id: ell
        property real rx: 10
        property color colorA: "gray"
        property color colorB: colorA
        property color edge: "transparent"
        property real edgeWidth: 0
        width: 2 * rx
        height: 2 * rx * phones.k
        Rectangle {
            width: ell.width
            height: ell.width
            radius: width / 2
            border.width: ell.edgeWidth / phones.k
            border.color: ell.edge
            gradient: Gradient {
                GradientStop { position: 0.0; color: ell.colorA }
                GradientStop { position: 1.0; color: ell.colorB }
            }
            transform: Scale { yScale: phones.k }
        }
    }
    // Staande cilinder van hoogte h0 tot h1 op tafelplek (at, 0).
    component Cylinder: Item {
        id: cyl
        property real at: 0
        property real r: 10
        property real h0: 0
        property real h1: 5
        property color side: "gray"
        readonly property real rx: r * phones.u
        readonly property real yBottom: phones.sy(0, h0)
        readonly property real yTop: phones.sy(0, h1)
        x: phones.sx(at) - rx
        y: yTop - rx * phones.k
        width: 2 * rx
        height: yBottom - yTop + 2 * rx * phones.k
        Ellipse {
            y: cyl.yBottom - cyl.y - height / 2
            rx: cyl.rx
            colorA: Qt.darker(cyl.side, 1.5)
        }
        Rectangle {
            y: cyl.rx * phones.k
            width: parent.width
            height: cyl.yBottom - cyl.yTop
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.darker(cyl.side, 1.6) }
                GradientStop { position: 0.3; color: Qt.lighter(cyl.side, 1.25) }
                GradientStop { position: 0.55; color: cyl.side }
                GradientStop { position: 1.0; color: Qt.darker(cyl.side, 1.9) }
            }
        }
    }

    // Beugel: punten langs de boog, op een hoogte en een afstand naar buiten.
    function bandPath(t0, t1, h, grow, n) {
        let pts = [];
        for (let i = 0; i <= n; i++) {
            let t = t0 + (t1 - t0) * i / n;
            pts.push([sx((bandA + grow) * Math.cos(t)), sy(bandZ + (bandB + grow) * Math.sin(t), h)]);
        }
        return pts;
    }
    function svg(a, b) {
        let p = a.concat(b.slice().reverse()), d = "M " + p[0][0].toFixed(1) + " " + p[0][1].toFixed(1);
        for (let i = 1; i < p.length; i++) d += " L " + p[i][0].toFixed(1) + " " + p[i][1].toFixed(1);
        return d + " Z";
    }
    function line(a) {
        let d = "M " + a[0][0].toFixed(1) + " " + a[0][1].toFixed(1);
        for (let i = 1; i < a.length; i++) d += " L " + a[i][0].toFixed(1) + " " + a[i][1].toFixed(1);
        return d;
    }
    readonly property real tEnd: 0.16 * Math.PI
    readonly property string ribbon: svg(bandPath(tEnd, Math.PI - tEnd, band1, 0, 28), bandPath(tEnd, Math.PI - tEnd, band0, 0, 28))
    readonly property string ribbonTop: svg(bandPath(tEnd, Math.PI - tEnd, band1, 3.2, 28), bandPath(tEnd, Math.PI - tEnd, band1, 0, 28))
    readonly property string stitch: line(bandPath(tEnd + 0.04, Math.PI - tEnd - 0.04, band1, 1.6, 26))
    readonly property string rail: line(bandPath(tEnd - 0.03, Math.PI - tEnd + 0.03, band1 + 0.6, 3.6, 28))
    // Schuifstuk van het eind van de band naar de vork achter de schelp.
    function slider(sign) {
        let t = sign > 0 ? tEnd : Math.PI - tEnd;
        let x0 = sx((bandA + 1.8) * Math.cos(t)), y0 = sy(bandZ + (bandB + 1.8) * Math.sin(t), band1 - 1.5);
        let x1 = sx(sign * cupX), y1 = sy(cupR + 1.6, shellH * 0.62);
        return "M " + x0.toFixed(1) + " " + y0.toFixed(1) + " Q " + sx(sign * (cupX + 3)).toFixed(1) + " " + ((y0 + y1) / 2).toFixed(1) + " " + x1.toFixed(1) + " " + y1.toFixed(1);
    }
    // Vork: metalen boog om de achterkant van een schelp.
    function yoke(sign) {
        let pts = [], r = cupR + 1.6;
        for (let i = 0; i <= 20; i++) {
            let t = Math.PI * i / 20;
            pts.push([sx(sign * cupX + r * Math.cos(t)), sy(r * Math.sin(t), shellH * 0.62)]);
        }
        return line(pts);
    }

    // --- Schaduw op tafel (licht van linksboven) --------------------------------
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 0.8 }
        Repeater {
            model: [-1, 1]
            Ellipse {
                required property int modelData
                rx: (phones.cupR + 2.4) * phones.u
                x: phones.sx(modelData * phones.cupX) - rx + phones.u * 2.5
                y: phones.sy(0, 0) - height / 2 + phones.u * 1.2
                colorA: Qt.rgba(0, 0, 0, 0.5)
            }
        }
        Shape {
            preferredRendererType: Shape.CurveRenderer
            x: phones.u * 2.5
            y: phones.u * 1
            ShapePath {
                strokeWidth: phones.u * 3.4
                strokeColor: Qt.rgba(0, 0, 0, 0.32)
                fillColor: "transparent"
                PathSvg { path: phones.line(phones.bandPath(0.12 * Math.PI, 0.88 * Math.PI, 0, 1, 24)) }
            }
        }
    }

    // --- Beugel en vorken (achter de schelpen) ----------------------------------
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Binnenkant van de band, op zijn kant.
        ShapePath {
            strokeWidth: 1
            strokeColor: Qt.darker(phones.leather, 2)
            fillGradient: LinearGradient {
                x1: 0; y1: phones.sy(phones.bandZ + phones.bandB, phones.band1)
                x2: 0; y2: phones.sy(phones.bandZ, phones.band0)
                GradientStop { position: 0.0; color: Qt.lighter(phones.leather, 1.15) }
                GradientStop { position: 1.0; color: Qt.darker(phones.leather, 1.6) }
            }
            PathSvg { path: phones.ribbon }
        }
        // Bovenkant van de band: lichter, met stiksel en een metalen rand.
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Qt.lighter(phones.leather, 1.45)
            PathSvg { path: phones.ribbonTop }
        }
        ShapePath {
            strokeWidth: Math.max(1, phones.u * 0.35)
            strokeColor: Qt.lighter(phones.leather, 2.1)
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 2]
            fillColor: "transparent"
            PathSvg { path: phones.stitch }
        }
        ShapePath {
            strokeWidth: Math.max(1.2, phones.u * 0.9)
            strokeColor: phones.metal
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: phones.rail }
        }
        // Vorken en schuifstukken.
        ShapePath {
            strokeWidth: Math.max(1.5, phones.u * 1.5)
            strokeColor: Qt.darker(phones.metal, 1.25)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: phones.yoke(-1) + " " + phones.yoke(1) + " " + phones.slider(-1) + " " + phones.slider(1) }
        }
        ShapePath {
            strokeWidth: Math.max(0.8, phones.u * 0.45)
            strokeColor: Qt.lighter(phones.metal, 1.3)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: phones.slider(-1) + " " + phones.slider(1) }
        }
    }

    // --- Schelpen ---------------------------------------------------------------
    Repeater {
        model: [-1, 1]
        Item {
            id: cup
            required property int modelData
            anchors.fill: parent
            readonly property real at: modelData * phones.cupX
            // Leren kussen, iets bol: lichtrand halverwege.
            Cylinder {
                at: cup.at
                r: phones.cupR
                h0: 0
                h1: phones.cushionH
                side: Qt.darker(phones.leather, 1.15)
            }
            Ellipse {
                rx: phones.cupR * phones.u
                x: phones.sx(cup.at) - rx
                y: phones.sy(0, phones.cushionH) - height / 2
                colorA: Qt.lighter(phones.leather, 1.1)
                colorB: Qt.darker(phones.leather, 1.2)
            }
            // Metalen sierring tussen kussen en schaal.
            Ellipse {
                rx: phones.cupR * 0.92 * phones.u
                x: phones.sx(cup.at) - rx
                y: phones.sy(0, phones.cushionH + 0.2) - height / 2
                colorA: "transparent"
                edge: Qt.darker(phones.metal, 1.15)
                edgeWidth: Math.max(1, phones.u * 0.35)
            }
            // Houten schaal.
            Cylinder {
                at: cup.at
                r: phones.cupR * 0.9
                h0: phones.cushionH
                h1: phones.shellH
                side: phones.wood
            }
            // Kap met nerf, afgeschuinde rand en een metalen logo.
            Item {
                readonly property real rx: phones.cupR * 0.9 * phones.u
                x: phones.sx(cup.at) - rx
                y: phones.sy(0, phones.shellH) - rx * phones.k
                width: 2 * rx
                height: 2 * rx
                transform: Scale { yScale: phones.k }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: phones.wood
                }
                WoodGrain {
                    anchors.fill: parent
                    anchors.margins: parent.width * 0.04
                    radius: width / 2
                    dark: phones.mocha.crust
                    light: phones.mocha.text
                    seed: 5 + cup.modelData * 3
                    strength: 0.9
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: parent.width * 0.05
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                }
                // Licht van linksboven op de bolle kap.
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
                        GradientStop { position: 0.5; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.32
                    height: width
                    radius: width / 2
                    color: Qt.darker(phones.wood, 1.25)
                    border.width: Math.max(1.5, parent.width * 0.035)
                    border.color: phones.metal
                }
            }
            // Scharnier van de vork aan de zijkant.
            Repeater {
                model: [-1, 1]
                Rectangle {
                    required property int modelData
                    readonly property real rr: Math.max(2, phones.u * 1.3)
                    x: phones.sx(cup.at + modelData * (phones.cupR + 1.6)) - rr
                    y: phones.sy(0, phones.shellH * 0.62) - rr
                    width: 2 * rr
                    height: 2 * rr
                    radius: rr
                    color: phones.metal
                    border.width: 1
                    border.color: Qt.darker(phones.metal, 1.6)
                }
            }
        }
    }

    // --- Snoer -------------------------------------------------------------------
    // Van de linkerschelp in een losse lus over tafel naar rechtsvoor, met
    // een metalen stekker.
    readonly property var cablePts: [
        [sx(-cupX - cupR * 0.6), sy(-cupR * 0.55, 1.2)],
        [sx(-cupX - 12), sy(-cupR - 18, 0.6)],
        [sx(8), sy(-cupR - 26, 0.6)],
        [sx(30), sy(-cupR - 10, 0.6)]
    ]
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: Math.max(2, phones.u * 1.6)
            strokeColor: Qt.rgba(0, 0, 0, 0.25)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: phones.cablePts[0][0] + phones.u; startY: phones.cablePts[0][1] + phones.u * 1.2
            PathCubic {
                x: phones.cablePts[3][0] + phones.u; y: phones.cablePts[3][1] + phones.u * 1.2
                control1X: phones.cablePts[1][0] + phones.u; control1Y: phones.cablePts[1][1] + phones.u * 1.2
                control2X: phones.cablePts[2][0] + phones.u; control2Y: phones.cablePts[2][1] + phones.u * 1.2
            }
        }
        ShapePath {
            strokeWidth: Math.max(1.5, phones.u * 1.1)
            strokeColor: Qt.darker(phones.leather, 1.9)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: phones.cablePts[0][0]; startY: phones.cablePts[0][1]
            PathCubic {
                x: phones.cablePts[3][0]; y: phones.cablePts[3][1]
                control1X: phones.cablePts[1][0]; control1Y: phones.cablePts[1][1]
                control2X: phones.cablePts[2][0]; control2Y: phones.cablePts[2][1]
            }
        }
    }
    Rectangle {
        x: phones.cablePts[3][0] - phones.u * 0.5
        y: phones.cablePts[3][1] - height / 2
        width: phones.u * 7
        height: Math.max(3, phones.u * 2.2)
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(phones.metal, 1.25) }
            GradientStop { position: 1.0; color: Qt.darker(phones.metal, 1.4) }
        }
        Rectangle {
            anchors.left: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: phones.u * 3.5
            height: parent.height * 0.45
            radius: height / 2
            color: phones.metal
        }
    }
}
