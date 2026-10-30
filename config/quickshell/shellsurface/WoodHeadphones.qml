import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import ".."

// Koptelefoon als versiering naast de walkman of discman, in de stijl van
// het thema (look): "wood" houten kappen en leer, "neon" donker met een
// gloeiende lijn, "paper" vlak papier met inktlijnen, "mono" mat kunststof.
// Hij ligt op tafel alsof iemand hem net heeft neergelegd: de ovale schelpen
// plat met de kussens naar beneden, elk een beetje anders gedraaid, en het
// snoer krult in een losse lus door het beeld. Zelfde camera als het
// apparaat: DeviceStage geeft project(X, Z, H) (tafelplek en hoogte in
// eenheden van 1/100 koptelefoon, naar beeldpunten en schaal) en k, hoe plat
// een cirkel op tafel in beeld staat. Echte maten: 100 eenheden is zo'n
// 18 cm, een schelp is 8 x 10 cm.
// part kiest wat er getekend wordt: "body" (beugel en schelpen, achter het
// apparaat), "cable" (snoer, ervoor) of "all".
Item {
    id: phones

    required property var mocha
    property color wood: "#8a5a3a"
    property color metal: "#bbbbbb"
    property color leather: "#3a2a20"
    property string look: "wood"
    // Paper: inktkleur; neon: gloeikleur.
    property color ink: "black"
    property color glow: "white"
    readonly property bool flat: look === "paper"
    readonly property bool lined: look === "paper" || look === "neon"
    readonly property color lineColor: look === "paper" ? ink : Qt.rgba(glow.r, glow.g, glow.b, 0.85)
    readonly property real lineW: look === "paper" ? 2 : 1.5
    property real k: 0.42
    property string part: "all"
    // Hoe ver het snoer naar voren mag krullen (1 = volle lengte); bij een
    // steile camera korter, anders loopt hij onder de titel door.
    property real cableDepth: 1
    readonly property bool showBody: part !== "cable"
    readonly property bool showCable: part !== "body"
    // Beeldpunten per eenheid op schaal 1, en de camera.
    property real u: 4
    property var project: (X, Z, H) => [X * u, -(Z * k + H) * u, 1]
    // Tafelcoördinaten in u: X naar rechts, Z naar achteren, H omhoog.
    // Schelpen: ovaal (rx dwars, rz in de lengte), kussen en houten schaal
    // die naar boven iets smaller wordt.
    readonly property real cupRx: 17
    readonly property real cupRz: 21.5
    readonly property real cushionH: 5
    readonly property real shellH: 11.5
    readonly property real band0: 2.5
    readonly property real band1: 11
    readonly property real yokeH: shellH * 0.6
    // Net neergelegd: de linkerschelp ligt bijna recht, de rechter is
    // weggedraaid en iets naar voren geschoven.
    readonly property var cups: [
        { cx: -24, cz: 3, yaw: 6, seed: 2 },
        { cx: 24, cz: -3, yaw: -8, seed: 8 }
    ]
    // Plek op de schelp (lokaal lx dwars, lz in de lengte) naar tafel.
    function onCup(c, lx, lz) {
        let a = c.yaw * Math.PI / 180, ca = Math.cos(a), sa = Math.sin(a);
        return [c.cx + lx * ca - lz * sa, c.cz + lx * sa + lz * ca];
    }
    function cupPt(c, lx, lz, h) { let p = onCup(c, lx, lz); return project(p[0], p[1], h); }
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
    // Liggend ovaal op tafelplek (cx, cz), gedraaid over yaw, hoogte h,
    // stralen rx en rz: rond getekend en met de homografie op tafel gelegd,
    // dan wordt de cirkel vanzelf het ovaal. Kinderen liggen erop.
    component Disc: Item {
        id: disc
        property real cx: 0
        property real cz: 0
        property real yaw: 0
        property real h: 0
        property real rx: 10
        property real rz: rx
        property color colorA: "gray"
        property color colorB: colorA
        property color edge: "transparent"
        property real edgeWidth: 0
        readonly property var spot: ({ cx: cx, cz: cz, yaw: yaw })
        width: 2 * Math.max(rx, rz) * phones.u
        height: width
        transform: Matrix4x4 {
            matrix: phones.quad(disc.width, disc.height, [
                phones.cupPt(disc.spot, -disc.rx, disc.rz, disc.h),
                phones.cupPt(disc.spot, disc.rx, disc.rz, disc.h),
                phones.cupPt(disc.spot, disc.rx, -disc.rz, disc.h),
                phones.cupPt(disc.spot, -disc.rx, -disc.rz, disc.h)
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
    // Staande ovale wand van hoogte h0 (stralen x s0) tot h1 (x s1) op een
    // schelp: de omtrek van onder- en bovenrand door de camera, rond belicht.
    component Wall: Shape {
        id: wall
        property var cup: phones.cups[0]
        property real s0: 1
        property real s1: 1
        property real h0: 0
        property real h1: 5
        property color side: "gray"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property var outline: {
            let pts = [];
            for (let i = 0; i < 36; i++) {
                let a = i / 36 * Math.PI * 2, c = Math.cos(a) * phones.cupRx, s = Math.sin(a) * phones.cupRz;
                pts.push(phones.cupPt(cup, c * s0, s * s0, h0));
                pts.push(phones.cupPt(cup, c * s1, s * s1, h1));
            }
            return phones.hull(pts);
        }
        readonly property real x0: Math.min(...outline.map(p => p[0]))
        readonly property real x1: Math.max(...outline.map(p => p[0]))
        ShapePath {
            strokeWidth: phones.lined ? phones.lineW : 0
            strokeColor: phones.lined ? phones.lineColor : "transparent"
            fillGradient: LinearGradient {
                x1: wall.x0; y1: 0
                x2: wall.x1; y2: 0
                GradientStop { position: 0.0; color: phones.flat ? wall.side : Qt.darker(wall.side, 1.6) }
                GradientStop { position: 0.3; color: phones.flat ? wall.side : Qt.lighter(wall.side, 1.25) }
                GradientStop { position: 0.55; color: wall.side }
                GradientStop { position: 1.0; color: phones.flat ? wall.side : Qt.darker(wall.side, 1.9) }
            }
            PathSvg { path: phones.line(wall.outline) + " Z" }
        }
    }

    function line(a) {
        let d = "M " + a[0][0].toFixed(1) + " " + a[0][1].toFixed(1);
        for (let i = 1; i < a.length; i++) d += " L " + a[i][0].toFixed(1) + " " + a[i][1].toFixed(1);
        return d;
    }
    function svg(a, b) { return line(a.concat(b.slice().reverse())) + " Z"; }

    // --- Beugel ------------------------------------------------------------------
    // De vork ligt om het achtereind van elke schelp; het schuifstuk loopt
    // er recht van weg en de leren band buigt in een boog van het ene
    // schuifstuk naar het andere. De band ligt op zijn kant.
    readonly property real slide: 9
    function yokeBack(c) { return onCup(c, 0, cupRz + 1.6); }
    function bandEnd(c) { return onCup(c, 0, cupRz + 1.6 + slide); }
    function cupDir(c) { let a = c.yaw * Math.PI / 180; return [-Math.sin(a), Math.cos(a)]; }
    readonly property var bandCtl: {
        let a = bandEnd(cups[0]), b = bandEnd(cups[1]), da = cupDir(cups[0]), db = cupDir(cups[1]);
        let len = Math.hypot(b[0] - a[0], b[1] - a[1]) * 0.72;
        return [a, [a[0] + da[0] * len, a[1] + da[1] * len], [b[0] + db[0] * len, b[1] + db[1] * len], b];
    }
    // Punt op de boog (s van 0 tot 1), grow naar buiten.
    function bandAt(s, grow) {
        let p = bandCtl, m = 1 - s;
        let x = m * m * m * p[0][0] + 3 * m * m * s * p[1][0] + 3 * m * s * s * p[2][0] + s * s * s * p[3][0];
        let z = m * m * m * p[0][1] + 3 * m * m * s * p[1][1] + 3 * m * s * s * p[2][1] + s * s * s * p[3][1];
        let tx = 3 * m * m * (p[1][0] - p[0][0]) + 6 * m * s * (p[2][0] - p[1][0]) + 3 * s * s * (p[3][0] - p[2][0]);
        let tz = 3 * m * m * (p[1][1] - p[0][1]) + 6 * m * s * (p[2][1] - p[1][1]) + 3 * s * s * (p[3][1] - p[2][1]);
        let l = Math.max(0.001, Math.hypot(tx, tz));
        return [x - tz / l * grow, z + tx / l * grow];
    }
    function bandPath(s0, s1, h, grow, n) {
        let pts = [];
        for (let i = 0; i <= n; i++) {
            let b = bandAt(s0 + (s1 - s0) * i / n, grow);
            pts.push(project(b[0], b[1], h));
        }
        return pts;
    }
    readonly property string ribbon: svg(bandPath(0, 1, band1, 0, 32), bandPath(0, 1, band0, 0, 32))
    readonly property string ribbonTop: svg(bandPath(0, 1, band1, 2.6, 32), bandPath(0, 1, band1, 0, 32))
    readonly property string stitch: line(bandPath(0.03, 0.97, band1, 1.3, 30))
    readonly property string rail: line(bandPath(-0.02, 1.02, band1 + 0.6, 3, 32))
    function slider(c, s) {
        let a = bandAt(s, 1.8), b = yokeBack(c);
        let p = project(a[0], a[1], band1 - 1.5), q = project(b[0], b[1], yokeH);
        return "M " + p[0].toFixed(1) + " " + p[1].toFixed(1) + " L " + q[0].toFixed(1) + " " + q[1].toFixed(1);
    }
    // Vork: metalen boog om het achtereind van een schelp.
    function yoke(c) {
        let pts = [];
        for (let i = 0; i <= 24; i++) {
            let t = Math.PI * i / 24;
            pts.push(cupPt(c, (cupRx + 1.6) * Math.cos(t), (cupRz + 1.6) * Math.sin(t), yokeH));
        }
        return line(pts);
    }

    // --- Snoer -------------------------------------------------------------------
    // Uit de onderkant van de linkerschelp, een losse krul op tafel en dan in
    // een zwaai voor de speler langs, omhoog naar de aansluiting (jack:
    // [punt, richting naar buiten] in koptelefoon-coördinaten, van
    // DeviceStage). Zonder aansluiting eindigt hij in een losse stekker op
    // tafel. Punten (X, Z, H), vloeiend verbonden (Catmull-Rom).
    property var jack: null
    // Lengte van stekker zonder pin: knikbeschermer en huls.
    readonly property real plugBody: 15.5
    readonly property var cableKeys: {
        let s = onCup(cups[0], -cupRx * 0.35, -cupRz * 0.9);
        let o = onCup(cups[0], -cupRx * 0.5, -cupRz - 6), d = cableDepth;
        let keys = [
            [s[0], s[1], cushionH + 1.5],
            [o[0], o[1], 1.1],
            [-50, -30 * d, 1.1],
            [-64, -42 * d, 1.1],
            [-60, -57 * d, 1.1],
            [-43, -56 * d, 1.1],
            [-40, -44 * d, 1.1],
            [-52, -39 * d, 1.1],
            [-57, -50 * d, 1.1],
            [-44, -64 * d, 1.1],
            [-20, -74 * d, 1.1],
            [0, -62 * d, 1.1]
        ];
        if (!jack)
            return keys.concat([[18, -70 * d, 1.1], [31, -63 * d, 1.1], [42, -58 * d, 1.1]]);
        // Van tafel omhoog naar de stekker: het snoer hangt eerst van de
        // speler af en buigt dan recht de stekker in.
        let j = jack[0], v = jack[1], hl = Math.hypot(v[0], v[1]);
        let e = [0, 1, 2].map(n => j[n] + v[n] * plugBody), m, n, t;
        if (hl > 0.4) {
            let w = [v[0] / hl, v[1] / hl];
            m = [e[0] + w[0] * 4, e[1] + w[1] * 4, e[2] * 0.85];
            n = [e[0] + w[0] * 8 - 2, e[1] + w[1] * 8, e[2] * 0.35];
            t = [e[0] + w[0] * 10 - 8, e[1] + w[1] * 10 + 1, 1.1];
        } else {
            let w = [-0.85, -0.5];
            m = [e[0] + w[0] * 5, e[1] + w[1] * 5, e[2] + 3.5];
            n = [j[0] + w[0] * 17, j[1] + w[1] * 17, j[2] * 0.75];
            t = [j[0] + w[0] * 25, j[1] + w[1] * 25, 1.1];
        }
        return keys.concat([[t[0] - 12, t[1] - 3, 1.1], t, n, m, e]);
    }
    readonly property var cableWorld: {
        let p = cableKeys, out = [];
        for (let i = 0; i < p.length - 1; i++) {
            let a = p[Math.max(0, i - 1)], b = p[i], c = p[i + 1], d = p[Math.min(p.length - 1, i + 2)];
            for (let j = 0; j < 12; j++) {
                let t = j / 12, t2 = t * t, t3 = t2 * t;
                let q = [0, 1, 2].map(n => 0.5 * (2 * b[n] + (-a[n] + c[n]) * t + (2 * a[n] - 5 * b[n] + 4 * c[n] - d[n]) * t2 + (-a[n] + 3 * b[n] - 3 * c[n] + d[n]) * t3));
                out.push(q);
            }
        }
        out.push(p[p.length - 1]);
        return out;
    }
    readonly property var cableEnd: cableWorld[cableWorld.length - 1]
    // As van de stekker (van het snoer naar de punt), in 3D.
    readonly property var plugDir: {
        if (jack) return jack[1].map(n => -n);
        let a = cableWorld[cableWorld.length - 4], b = cableEnd, l = Math.max(0.001, Math.hypot(b[0] - a[0], b[1] - a[1]));
        return [(b[0] - a[0]) / l, (b[1] - a[1]) / l, 0];
    }
    // Licht van linksboven: glans boven op een liggende stekker, links op een
    // staande.
    readonly property var plugShine: Math.hypot(plugDir[0], plugDir[1]) > 0.5 ? [0, 0, 1] : [-0.8, 0.3, 0]
    function plugAt(d, lift) {
        let b = jack ? 0 : 1.1;
        return project(cableEnd[0] + plugDir[0] * d + plugShine[0] * lift,
                       cableEnd[1] + plugDir[1] * d + plugShine[1] * lift,
                       cableEnd[2] + plugDir[2] * d + plugShine[2] * lift + b);
    }
    readonly property string cablePath: line(cableWorld.map(p => project(p[0], p[1], p[2])))
    readonly property string cableShadow: line(cableWorld.map(p => project(p[0] + 1.4 + p[2] * 0.25, p[1] - 0.8, 0)))
    readonly property string cableShine: line(cableWorld.map(p => project(p[0] - 0.3, p[1] + 0.2, p[2] + 0.7)))
    // 3,5 mm-stekker: knikbeschermer, huls en pin langs de as; in de
    // aansluiting zit de pin erin.
    function seg(d0, d1, lift) {
        let a = plugAt(d0, lift), b = plugAt(d1, lift);
        return "M " + a[0].toFixed(1) + " " + a[1].toFixed(1) + " L " + b[0].toFixed(1) + " " + b[1].toFixed(1);
    }

    // --- Schaduw op tafel (licht van linksboven) --------------------------------
    Item {
        anchors.fill: parent
        visible: phones.showBody
        layer.enabled: visible
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 0.8 }
        Repeater {
            model: phones.cups
            Disc {
                required property var modelData
                cx: modelData.cx + 2.5
                cz: modelData.cz - 1.5
                yaw: modelData.yaw
                rx: phones.cupRx + 2.4
                rz: phones.cupRz + 2.4
                colorA: Qt.rgba(0, 0, 0, phones.flat ? 0.12 : phones.look === "neon" ? 0.35 : 0.5)
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
                PathSvg { path: phones.line(phones.bandPath(0, 1, 0, 1, 24)) }
            }
        }
    }

    // --- Beugel en vorken (achter de schelpen) ----------------------------------
    Shape {
        anchors.fill: parent
        visible: phones.showBody
        preferredRendererType: Shape.CurveRenderer
        // Binnenkant van de band, op zijn kant.
        ShapePath {
            strokeWidth: 1
            strokeColor: phones.lined ? phones.lineColor : Qt.darker(phones.leather, 2)
            fillGradient: LinearGradient {
                x1: 0; y1: phones.bandPath(0.5, 0.5, phones.band1, 0, 1)[0][1] - phones.u * 6
                x2: 0; y2: phones.bandPath(0.5, 0.5, phones.band0, 0, 1)[0][1] + phones.u * 6
                GradientStop { position: 0.0; color: Qt.lighter(phones.leather, 1.15) }
                GradientStop { position: 1.0; color: Qt.darker(phones.leather, 1.6) }
            }
            PathSvg { path: phones.ribbon }
        }
        // Bovenkant van de band: lichter, met stiksel en een metalen rand.
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: phones.flat ? phones.leather : Qt.lighter(phones.leather, 1.45)
            PathSvg { path: phones.ribbonTop }
        }
        ShapePath {
            strokeWidth: Math.max(1, phones.u * 0.35)
            strokeColor: phones.lined ? phones.lineColor : Qt.lighter(phones.leather, 2.1)
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
            PathSvg { path: phones.yoke(phones.cups[0]) + " " + phones.yoke(phones.cups[1]) + " " + phones.slider(phones.cups[0], 0) + " " + phones.slider(phones.cups[1], 1) }
        }
        ShapePath {
            strokeWidth: Math.max(0.8, phones.u * 0.45)
            strokeColor: Qt.lighter(phones.metal, 1.3)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: phones.slider(phones.cups[0], 0) + " " + phones.slider(phones.cups[1], 1) }
        }
    }

    // --- Schelpen ---------------------------------------------------------------
    Repeater {
        model: phones.showBody ? phones.cups : []
        Item {
            id: cup
            required property var modelData
            anchors.fill: parent
            // Leren kussen, bol: smal onderaan, breedst halverwege.
            Wall {
                cup: cup.modelData
                s0: 0.93
                s1: 1
                h0: 0
                h1: phones.cushionH * 0.5
                side: Qt.darker(phones.leather, 1.3)
            }
            Wall {
                cup: cup.modelData
                s0: 1
                s1: 0.96
                h0: phones.cushionH * 0.5
                h1: phones.cushionH
                side: Qt.darker(phones.leather, 1.1)
            }
            Disc {
                cx: cup.modelData.cx
                cz: cup.modelData.cz
                yaw: cup.modelData.yaw
                h: phones.cushionH
                rx: phones.cupRx * 0.96
                rz: phones.cupRz * 0.96
                colorA: phones.flat ? phones.leather : Qt.lighter(phones.leather, 1.1)
                colorB: phones.flat ? phones.leather : Qt.darker(phones.leather, 1.2)
                edge: phones.lined ? phones.lineColor : "transparent"
                edgeWidth: phones.lined ? phones.lineW * 1.2 : 0
            }
            // Metalen sierring tussen kussen en schaal.
            Disc {
                cx: cup.modelData.cx
                cz: cup.modelData.cz
                yaw: cup.modelData.yaw
                h: phones.cushionH + 0.2
                rx: phones.cupRx * 0.93
                rz: phones.cupRz * 0.93
                colorA: "transparent"
                edge: phones.lined ? phones.lineColor : Qt.darker(phones.metal, 1.15)
                edgeWidth: Math.max(1, phones.u * 0.35)
            }
            // Houten schaal, naar boven iets smaller.
            Wall {
                cup: cup.modelData
                s0: 0.9
                s1: 0.84
                h0: phones.cushionH
                h1: phones.shellH
                side: phones.wood
            }
            // Kap met nerf, afgeschuinde rand en een metalen logo.
            Disc {
                cx: cup.modelData.cx
                cz: cup.modelData.cz
                yaw: cup.modelData.yaw
                h: phones.shellH
                rx: phones.cupRx * 0.84
                rz: phones.cupRz * 0.84
                colorA: phones.wood
                edge: phones.lined ? phones.lineColor : "transparent"
                edgeWidth: phones.lined ? phones.lineW * 1.2 : 0
                WoodGrain {
                    visible: phones.look === "wood"
                    anchors.fill: parent
                    anchors.margins: parent.width * 0.04
                    radius: width / 2
                    dark: phones.mocha.crust
                    light: phones.mocha.text
                    seed: 5 + cup.modelData.seed
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
                    visible: !phones.flat
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
                        GradientStop { position: 0.5; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.3
                    height: width
                    radius: width / 2
                    color: phones.flat ? phones.wood : Qt.darker(phones.wood, 1.25)
                    border.width: Math.max(1.5, parent.width * 0.035)
                    border.color: phones.metal
                }
            }
            // Scharnieren van de vork aan de zijkanten.
            Repeater {
                model: [-1, 1]
                Rectangle {
                    required property int modelData
                    readonly property var at: phones.cupPt(cup.modelData, modelData * (phones.cupRx + 1.6), 0, phones.yokeH)
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

    // --- Snoer en stekker -------------------------------------------------------
    Shape {
        anchors.fill: parent
        visible: phones.showCable
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: Math.max(2, phones.u * 2)
            strokeColor: Qt.rgba(0, 0, 0, 0.22)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: phones.cableShadow }
        }
        ShapePath {
            strokeWidth: Math.max(1.5, phones.u * 2)
            strokeColor: phones.flat ? phones.ink : Qt.darker(phones.leather, phones.look === "neon" ? 1.2 : 1.9)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: phones.cablePath }
        }
        // Glans bovenop: waar het snoer over zichzelf ligt, loopt hij door.
        ShapePath {
            strokeWidth: Math.max(0.7, phones.u * 0.5)
            strokeColor: phones.flat ? "transparent" : phones.look === "neon" ? phones.lineColor : Qt.lighter(phones.leather, 1.5)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: phones.cableShine }
        }
        // Stekker: schaduw, knikbeschermer, huls, pin en glans.
        ShapePath {
            strokeWidth: phones.u * 4.6
            strokeColor: Qt.rgba(0, 0, 0, 0.22)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg {
                path: {
                    if (phones.jack) return "M 0 0";
                    let a = phones.project(phones.cableEnd[0] + 1.5, phones.cableEnd[1] - 1, 0);
                    let b = phones.project(phones.cableEnd[0] + phones.plugDir[0] * 22 + 1.5, phones.cableEnd[1] + phones.plugDir[1] * 22 - 1, 0);
                    return "M " + a[0].toFixed(1) + " " + a[1].toFixed(1) + " L " + b[0].toFixed(1) + " " + b[1].toFixed(1);
                }
            }
        }
        ShapePath {
            strokeWidth: phones.u * 3
            strokeColor: Qt.darker(phones.leather, 1.6)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: phones.seg(0, 4, 0) }
        }
        ShapePath {
            strokeWidth: phones.u * 4.4
            strokeColor: Qt.darker(phones.metal, 1.35)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: phones.seg(4.5, 15, 0) }
        }
        ShapePath {
            strokeWidth: phones.u * 1.8
            strokeColor: phones.metal
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: phones.jack ? "M 0 0" : phones.seg(15.5, 23, -0.6) }
        }
        ShapePath {
            strokeWidth: phones.u * 1.4
            strokeColor: Qt.lighter(phones.metal, 1.35)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: phones.seg(5, 14.5, 1.3) }
        }
        ShapePath {
            strokeWidth: phones.u * 0.5
            strokeColor: Qt.darker(phones.metal, 1.8)
            fillColor: "transparent"
            PathSvg { path: phones.jack ? "M 0 0" : phones.seg(18.5, 19.2, -0.4) + " " + phones.seg(20.5, 21.2, -0.4) }
        }
    }
}
