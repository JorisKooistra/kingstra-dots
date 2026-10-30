import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import ".."

// Houten koptelefoon als versiering naast de walkman of discman (Organic).
// Hij ligt plat op tafel met de kussens naar beneden, met dezelfde camera
// als het apparaat: DeviceStage geeft project(X, Z, H) (tafelplek en hoogte
// in eenheden van 1/100 koptelefoon, naar beeldpunten en schaal) en k, hoe
// plat een cirkel op tafel in beeld staat. Echt 3D: de schelpen zijn cilinders met een
// leren kussen en een houten kap, de beugel is een leren band op zijn kant
// met metalen schuifstukken en vorken. Alles wordt één keer getekend.
Item {
    id: phones

    required property var mocha
    property color wood: "#8a5a3a"
    property color metal: "#bbbbbb"
    property color leather: "#3a2a20"
    property real k: 0.42
    // Beeldpunten per eenheid op schaal 1, en de camera.
    property real u: 4
    property var project: (X, Z, H) => [X * u, -(Z * k + H) * u, 1]
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
    function sy(X, Z, H) { return project(X, Z, H)[1]; }

    // Homografie: legt een plat getekend vlak (w x h) op vier punten in
    // beeld. Zo staat alles op tafel in precies hetzelfde perspectief als de
    // speler.
    function quad(w, h, q) {
        let x0 = q[0][0], y0 = q[0][1], x1 = q[1][0], y1 = q[1][1], x2 = q[2][0], y2 = q[2][1], x3 = q[3][0], y3 = q[3][1];
        let dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3;
        let dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3;
        let den = dx1 * dy2 - dx2 * dy1;
        let g = Math.abs(den) < 1e-9 ? 0 : (dx3 * dy2 - dx2 * dy3) / den;
        let hh = Math.abs(den) < 1e-9 ? 0 : (dx1 * dy3 - dx3 * dy1) / den;
        let a = x1 - x0 + g * x1, b = x3 - x0 + hh * x3, c = x0;
        let d = y1 - y0 + g * y1, e = y3 - y0 + hh * y3, f = y0;
        return Qt.matrix4x4(a / w, b / h, 0, c, d / w, e / h, 0, f, 0, 0, 1, 0, g / w, hh / h, 0, 1);
    }
    // Liggende schijf op tafelplek (cx, cz), hoogte h, straal r: plat
    // getekend en met de homografie op tafel gelegd. Kinderen liggen erop.
    component Disc: Item {
        id: disc
        property real cx: 0
        property real cz: 0
        property real h: 0
        property real r: 10
        property color colorA: "gray"
        property color colorB: colorA
        property color edge: "transparent"
        property real edgeWidth: 0
        width: 2 * r * phones.u
        height: width
        transform: Matrix4x4 {
            matrix: phones.quad(disc.width, disc.height, [
                phones.project(disc.cx - disc.r, disc.cz + disc.r, disc.h),
                phones.project(disc.cx + disc.r, disc.cz + disc.r, disc.h),
                phones.project(disc.cx + disc.r, disc.cz - disc.r, disc.h),
                phones.project(disc.cx - disc.r, disc.cz - disc.r, disc.h)
            ])
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            border.width: disc.edgeWidth
            border.color: disc.edge
            gradient: Gradient {
                GradientStop { position: 0.0; color: disc.colorA }
                GradientStop { position: 1.0; color: disc.colorB }
            }
        }
    }
    // Staande cilinder van hoogte h0 tot h1 op tafelplek (at, 0): de
    // omtrek van onder- en bovenrand door de camera, rond belicht.
    function hull(pts) {
        pts = pts.slice().sort((a, b) => a[0] - b[0] || a[1] - b[1]);
        function cross(o, a, b) { return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]); }
        let lower = [], upper = [];
        for (let p of pts) {
            while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) lower.pop();
            lower.push(p);
        }
        for (let i = pts.length - 1; i >= 0; i--) {
            let p = pts[i];
            while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) upper.pop();
            upper.push(p);
        }
        upper.pop();
        lower.pop();
        return lower.concat(upper);
    }
    component Cylinder: Shape {
        id: cyl
        property real at: 0
        property real r: 10
        property real h0: 0
        property real h1: 5
        property color side: "gray"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property var outline: {
            let pts = [];
            for (let i = 0; i < 32; i++) {
                let a = i / 32 * Math.PI * 2;
                pts.push(phones.project(at + r * Math.cos(a), r * Math.sin(a), h0));
                pts.push(phones.project(at + r * Math.cos(a), r * Math.sin(a), h1));
            }
            return phones.hull(pts);
        }
        readonly property real x0: Math.min(...outline.map(p => p[0]))
        readonly property real x1: Math.max(...outline.map(p => p[0]))
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: cyl.x0; y1: 0
                x2: cyl.x1; y2: 0
                GradientStop { position: 0.0; color: Qt.darker(cyl.side, 1.6) }
                GradientStop { position: 0.3; color: Qt.lighter(cyl.side, 1.25) }
                GradientStop { position: 0.55; color: cyl.side }
                GradientStop { position: 1.0; color: Qt.darker(cyl.side, 1.9) }
            }
            PathSvg { path: phones.line(cyl.outline) + " Z" }
        }
    }

    // Beugel: punten langs de boog, op een hoogte en een afstand naar buiten.
    function bandPath(t0, t1, h, grow, n) {
        let pts = [];
        for (let i = 0; i <= n; i++) {
            let t = t0 + (t1 - t0) * i / n;
            pts.push(project((bandA + grow) * Math.cos(t), bandZ + (bandB + grow) * Math.sin(t), h));
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
        let a = project((bandA + 1.8) * Math.cos(t), bandZ + (bandB + 1.8) * Math.sin(t), band1 - 1.5);
        let b = project(sign * cupX, cupR + 1.6, shellH * 0.62);
        let c = project(sign * (cupX + 3), (bandZ + cupR) / 2 + 2, (band1 + shellH * 0.62) / 2);
        return "M " + a[0].toFixed(1) + " " + a[1].toFixed(1) + " Q " + c[0].toFixed(1) + " " + c[1].toFixed(1) + " " + b[0].toFixed(1) + " " + b[1].toFixed(1);
    }
    // Vork: metalen boog om de achterkant van een schelp.
    function yoke(sign) {
        let pts = [], r = cupR + 1.6;
        for (let i = 0; i <= 20; i++) {
            let t = Math.PI * i / 20;
            pts.push(project(sign * cupX + r * Math.cos(t), r * Math.sin(t), shellH * 0.62));
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
            Disc {
                required property int modelData
                cx: modelData * phones.cupX + 2.5
                cz: -1.5
                r: phones.cupR + 2.4
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
                x1: 0; y1: phones.sy(0, phones.bandZ + phones.bandB, phones.band1)
                x2: 0; y2: phones.sy(0, phones.bandZ, phones.band0)
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
            Disc {
                cx: cup.at
                h: phones.cushionH
                r: phones.cupR
                colorA: Qt.lighter(phones.leather, 1.1)
                colorB: Qt.darker(phones.leather, 1.2)
            }
            // Metalen sierring tussen kussen en schaal.
            Disc {
                cx: cup.at
                h: phones.cushionH + 0.2
                r: phones.cupR * 0.92
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
            Disc {
                cx: cup.at
                h: phones.shellH
                r: phones.cupR * 0.9
                colorA: phones.wood
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
                    readonly property var at: phones.project(cup.at + modelData * (phones.cupR + 1.6), 0, phones.shellH * 0.62)
                    readonly property real rr: Math.max(2, phones.u * 1.3 * at[2])
                    x: at[0] - rr
                    y: at[1] - rr
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
        project(-cupX - cupR * 0.6, -cupR * 0.55, 1.2),
        project(-cupX - 12, -cupR - 18, 0.6),
        project(8, -cupR - 26, 0.6),
        project(30, -cupR - 10, 0.6)
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
