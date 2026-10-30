import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import ".."

// Gedeeld podium voor de schermvullende cassettespeler en discman. Apparaat
// en koptelefoon staan op één tafel voor één camera met echt perspectief
// (cam/proj): schuin gedraaid (yaw) en van iets boven (pitch). De overgang
// vanuit de kleine speler op het bureaublad loopt in rustige fases: eerst
// groeit de platte speler naar zijn plek, dan draait hij in de camerastand
// en komt de kast erbij, pas daarna de details.
//
// Staand (upright, de cassettespeler): je ziet het front (topData), de
// bovenkant met de knoppen en de rechterzijkant met het wieltje
// (shellData). Liggend (de discman): je ziet de bovenkant (topData) en de
// zijkant, met de knoppen op de rand (frontData, via sidePoint). Het vlak
// van topData wordt met een homografie op de camera gelegd, dus alles erop
// staat vanzelf in perspectief. Alleen QtQuick: het venster eromheen staat
// in VinylStage.qml.
FocusScope {
    id: stage

    required property var mocha
    property color accent: mocha.primary
    // Uitvoering en kleuren van het apparaat (zie CassetteDeck/DiscDeck).
    property var skin: ({})
    property string look: "mono"

    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property bool playing: false
    property string hint: ""

    // Verhoudingen van het apparaat t.o.v. zijn breedte.
    property real topAspect: 0.75
    property real frontRatio: 0.12
    property real widthShare: 0.52
    // Hoekradius van de kast op de uiteindelijke grootte (in pixels).
    property real bodyRadius: 12
    property bool upright: false
    // Staand: hoogte van het front t.o.v. de breedte.
    property real faceAspect: 0.71
    // Staand: diepte van de kast (liggend is dat frontRatio, de dikte). De
    // camera in graden; afstand t.o.v. de breedte, kleiner = sterker
    // perspectief.
    property real depthRatio: 0.24
    property real camYaw: -27
    property real camPitch: 14
    property real camDistance: 4.5
    // Organic: breedte van de koptelefoon t.o.v. het apparaat (echte maat:
    // een koptelefoon is breder dan een walkman of discman).
    property real phonesScale: 1.4
    readonly property bool hasPhones: true
    readonly property real phonesWidth: rigWidth * phonesScale
    // Apparaat en koptelefoon samen in het midden.
    readonly property real sceneShift: hasPhones ? phonesWidth * 0.55 : 0

    // 0 = dicht, 1 = open; het venster animeert dit.
    property real reveal: 1
    // Plek van de kleine speler op het scherm; de grote groeit daaruit.
    property rect originRect: Qt.rect(0, 0, 0, 0)
    readonly property bool fromOrigin: originRect.width > 0
    function lerp(a, b, t) { return a + (b - a) * t; }
    function clamp01(t) { return Math.max(0, Math.min(1, t)); }
    function ease(t) { t = clamp01(t); return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; }
    readonly property real growT: fromOrigin ? ease(reveal / 0.62) : reveal
    readonly property real tiltT: fromOrigin ? ease((reveal - 0.38) / 0.62) : reveal
    readonly property real detailT: fromOrigin ? clamp01((reveal - 0.75) / 0.25) : 1
    readonly property bool settled: reveal > 0.99
    // Koptelefoon: rustig infaden als de speler staat, snel weg bij sluiten.
    property real phonesT: settled ? 1 : 0
    Behavior on phonesT { NumberAnimation { duration: ThemeConfig.duration(stage.settled ? 380 : 160); easing.type: Easing.OutQuad } }

    property alias topData: topFace.data
    property alias frontData: frontContent.data
    property alias shellData: shellLayer.data

    signal togglePlay()
    signal previous()
    signal next()
    signal nudge(real seconds)
    signal closeRequested()

    property real sway: 0
    // Wat de camera-zwaai doet met de zijkanten van knoppen en onderdelen.
    readonly property real viewLean: sway / 2.4 * 0.2
    SequentialAnimation {
        running: stage.playing && stage.settled
        loops: Animation.Infinite
        NumberAnimation { target: stage; property: "sway"; to: 2.4; duration: 9000; easing.type: Easing.InOutSine }
        NumberAnimation { target: stage; property: "sway"; to: -2.4; duration: 18000; easing.type: Easing.InOutSine }
        NumberAnimation { target: stage; property: "sway"; to: 0; duration: 9000; easing.type: Easing.InOutSine }
    }

    function clock(sec) {
        let s = Math.max(0, Math.floor(Number(sec) || 0));
        let m = Math.floor(s / 60);
        let r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    focus: true
    Keys.onEscapePressed: event => { stage.closeRequested(); event.accepted = true; }
    Keys.onSpacePressed: event => { stage.togglePlay(); event.accepted = true; }
    Keys.onLeftPressed: event => { stage.nudge(-10); event.accepted = true; }
    Keys.onRightPressed: event => { stage.nudge(10); event.accepted = true; }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_N) { stage.next(); event.accepted = true; }
        else if (event.key === Qt.Key_P) { stage.previous(); event.accepted = true; }
        else if (event.key === Qt.Key_Q) { stage.closeRequested(); event.accepted = true; }
    }

    // --- Achtergrond ---------------------------------------------------------
    // Niet zwart: de basis van het thema met een zweem van de containers,
    // daarover de vervaagde hoes en een zacht vignet.
    readonly property color secondaryContainer: mocha.accent2Container !== undefined ? mocha.accent2Container
        : mocha.secondaryContainer !== undefined ? mocha.secondaryContainer : mocha.surface1
    readonly property color tertiaryContainer: mocha.tertiaryContainer !== undefined ? mocha.tertiaryContainer : mocha.surface1
    readonly property color primaryContainer: mocha.primaryContainer !== undefined ? mocha.primaryContainer : mocha.surface1
    Rectangle {
        anchors.fill: parent
        opacity: stage.reveal
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: stage.look === "paper" ? Qt.darker(stage.mocha.base, 1.04)
                    : Qt.tint(stage.mocha.base, Qt.rgba(stage.primaryContainer.r, stage.primaryContainer.g, stage.primaryContainer.b, 0.30))
            }
            GradientStop {
                position: 1.0
                color: stage.look === "paper" ? Qt.darker(stage.mocha.base, 1.12)
                    : Qt.tint(stage.mocha.mantle, Qt.rgba(stage.secondaryContainer.r, stage.secondaryContainer.g, stage.secondaryContainer.b, 0.32))
            }
        }
    }
    Image {
        id: backdropArt
        anchors.fill: parent
        source: stage.artUrl
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 512
        sourceSize.height: 512
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: backdropArt
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        saturation: 0.2
        opacity: backdropArt.status === Image.Ready ? 0.28 * stage.reveal : 0
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(600) } }
    }
    Rectangle {
        anchors.fill: parent
        visible: stage.look !== "paper"
        opacity: stage.reveal
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(stage.tertiaryContainer.r, stage.tertiaryContainer.g, stage.tertiaryContainer.b, 0.16) }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(stage.secondaryContainer.r, stage.secondaryContainer.g, stage.secondaryContainer.b, 0.16) }
        }
    }
    Rectangle {
        anchors.fill: parent
        opacity: stage.reveal
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, stage.look === "paper" ? 0.04 : 0.18) }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, stage.look === "paper" ? 0.08 : 0.30) }
        }
    }
    // Klik naast het apparaat sluit.
    MouseArea {
        anchors.fill: parent
        onClicked: stage.closeRequested()
    }

    // --- Het apparaat ---------------------------------------------------------
    // Eén camera voor apparaat en koptelefoon. Wereld: midden van de rig,
    // Y omhoog, Z naar je toe, in pixels op de eindgrootte. yaw draait de
    // tafel, pitch is hoe ver je erop neerkijkt (90 = recht van boven).
    // Begin van de overgang: staand recht van voren (yaw 0, pitch 0), liggend
    // recht van boven (pitch 90). Dan valt het front of de bovenkant precies
    // op de rig en groeit hij naadloos uit de kleine speler.
    readonly property real camT: extrudeT
    readonly property real extrudeT: fromOrigin ? tiltT : reveal
    readonly property real yawNow: camYaw * camT * Math.PI / 180
    readonly property real pitchNow: (upright ? camPitch * camT : 90 + (camPitch - 90) * camT) * Math.PI / 180
    readonly property real camD: rigWidth * camDistance
    readonly property real pitchFinal: camPitch * Math.PI / 180

    readonly property real rigWidth: upright
        ? Math.min(width * widthShare, height * 0.62 / (faceAspect + depthRatio * 0.3))
        : Math.min(width * widthShare, height * 0.64 / (Math.sin(pitchFinal) + frontRatio * Math.cos(pitchFinal)))
    readonly property real topDepth: upright ? rigWidth * faceAspect : rigWidth * topAspect
    // Dikte van de kast: staand naar achteren, liggend naar beneden.
    readonly property real boxDepth: upright ? rigWidth * depthRatio : rigWidth * frontRatio
    readonly property real frontHeight: boxDepth
    readonly property real finalX: (width - rigWidth) / 2 + sceneShift
    readonly property real finalY: upright
        ? (height * 0.88 - topDepth) / 2 + rigWidth * depthRatio * 0.15
        : (height * 0.86 - topDepth) / 2 - boxDepth * Math.cos(pitchFinal) * 0.5

    function cam(X, Y, Z) { return camAt(X, Y, Z, yawNow, pitchNow); }
    // Eindstand van de camera: de koptelefoon komt pas in beeld als de
    // camera stilstaat en hoeft dus niet elk frame opnieuw berekend te worden.
    readonly property real yawFinal: camYaw * Math.PI / 180
    function camFinal(X, Y, Z) { return camAt(X, Y, Z, yawFinal, pitchFinal); }
    function camAt(X, Y, Z, yaw, pitch) {
        let cy = Math.cos(yaw), sy = Math.sin(yaw), cp = Math.cos(pitch), sp = Math.sin(pitch);
        let x1 = X * cy + Z * sy, z1 = -X * sy + Z * cy;
        let y2 = Y * cp - z1 * sp, z2 = Y * sp + z1 * cp - (upright ? boxDepth / 2 : 0);
        let s = camD / Math.max(1, camD - z2);
        return [rigWidth / 2 + x1 * s, topDepth / 2 - y2 * s, s];
    }
    // Staand: x en y zoals op het front (links-boven 0,0), z naar achteren.
    // Liggend: x en y zoals op de bovenkant, z naar beneden (dikte).
    function proj(x, y, z) {
        return upright ? cam(x - rigWidth / 2, topDepth / 2 - y, boxDepth / 2 - z)
                       : cam(x - rigWidth / 2, -z, y - topDepth / 2);
    }
    // Hoe plat een cirkel op het bovenvlak of de tafel in beeld staat.
    readonly property real tableSquash: Math.max(0.02, Math.sin(pitchNow))
    // Homografie: legt een rechthoek (w x h) op vier geprojecteerde hoeken.
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
    readonly property matrix4x4 faceMatrix: quadMatrix(rigWidth, topDepth,
        [proj(0, 0, 0), proj(rigWidth, 0, 0), proj(rigWidth, topDepth, 0), proj(0, topDepth, 0)])

    // Liggend, ronde kast: een plek op de zijkant. a in graden rond de kast
    // (0 = midden voor, positief naar rechts), f van boven (0) naar onder
    // (1). Geeft plek, schaal, hoe veel hij naar je toe staat, hoe schuin
    // de rand daar in beeld loopt en hoe hoog de zijkant in beeld is.
    function sidePoint(a, f) {
        let A = a * Math.PI / 180, R = rigWidth / 2, Y = -boxDepth * f;
        let p = cam(R * Math.sin(A), Y, R * Math.cos(A));
        let q = cam(R * Math.sin(A + 0.02), Y, R * Math.cos(A + 0.02));
        return {
            x: p[0], y: p[1], s: p[2],
            facing: Math.max(0.05, Math.cos(A + yawNow)),
            angle: Math.atan2(q[1] - p[1], q[0] - p[0]) * 180 / Math.PI,
            ys: Math.cos(pitchNow) * p[2]
        };
    }

    // Omtrek van de kast (liggend): punten op de afgeronde rand met hun
    // naar buiten wijzende richting.
    function rimPoints() {
        let w = rigWidth, h = topDepth, r = Math.min(bodyRadius, w / 2, h / 2), n = Math.max(8, Math.round(r / w * 64));
        let pts = [];
        let cs = [[w - r, h - r, 0], [r, h - r, 0.5], [r, r, 1], [w - r, r, 1.5]];
        for (let c of cs) {
            for (let i = 0; i <= n; i++) {
                let a = (c[2] + 0.5 * i / n) * Math.PI;
                // a: 0 = rechts, pi/2 = voor (y groeit naar voren).
                pts.push([c[0] + r * Math.cos(a), c[1] + r * Math.sin(a), Math.cos(a), Math.sin(a)]);
            }
        }
        return pts;
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
    function svg(pts, close) {
        if (pts.length === 0) return "M 0 0";
        let d = "M " + pts[0][0].toFixed(2) + " " + pts[0][1].toFixed(2);
        for (let i = 1; i < pts.length; i++) d += " L " + pts[i][0].toFixed(2) + " " + pts[i][1].toFixed(2);
        return close ? d + " Z" : d;
    }
    // Liggend: zichtbare zijkant (rand boven, rand onder terug) en het
    // silhouet. Alleen opnieuw bij een andere camerastand.
    readonly property var lyingShell: {
        if (upright) return { side: "M 0 0", top: "M 0 0", outline: "M 0 0" };
        let rim = rimPoints(), cy = Math.cos(yawNow), sy = Math.sin(yawNow);
        let vis = rim.map(p => -p[2] * sy + p[3] * cy > 0);
        // Begin net na een onzichtbaar punt, zodat de zichtbare boog heel blijft.
        let start = vis.indexOf(false);
        let topRun = [], botRun = [];
        if (start >= 0) {
            for (let k = 1; k <= rim.length; k++) {
                let i = (start + k) % rim.length;
                if (!vis[i]) continue;
                topRun.push(proj(rim[i][0], rim[i][1], 0));
                botRun.push(proj(rim[i][0], rim[i][1], boxDepth));
            }
        }
        let all = rim.map(p => proj(p[0], p[1], 0)).concat(rim.map(p => proj(p[0], p[1], boxDepth)));
        return {
            side: svg(topRun.concat(botRun.reverse()), true),
            top: svg(topRun, false),
            outline: svg(hull(all), true)
        };
    }

    // Organic: een houten koptelefoon ligt naast het apparaat op tafel, door
    // dezelfde camera. Komt pas aan het eind van de overgang in beeld.
    WoodHeadphones {
        id: decoration
        anchors.fill: parent
        part: "body"
        cableDepth: stage.upright ? 0.5 : 0.6
        jack: stage.phonesJack
        visible: stage.hasPhones && opacity > 0.01
        opacity: stage.phonesT
        // Tijdens het infaden als één geheel, anders schijnen de delen
        // door elkaar heen.
        layer.enabled: visible && opacity < 0.99
        mocha: stage.mocha
        u: stage.phonesWidth / 100
        k: Math.max(0.02, Math.sin(stage.pitchFinal))
        project: (X, Z, H) => stage.phonesProject(X, Z, H)
        look: stage.look
        ink: stage.mocha.text
        glow: stage.accent
        // Per thema: houten kap en leer (Organic), donker met gloed (Neon),
        // papier (Paper) of mat kunststof (Mono).
        wood: stage.look === "neon" ? Qt.darker(stage.mocha.crust, 1.1)
            : stage.look === "paper" ? stage.mocha.base
            : stage.look === "wood" ? Qt.tint("#7a4e2d", Qt.rgba(stage.tertiaryContainer.r, stage.tertiaryContainer.g, stage.tertiaryContainer.b, 0.06))
            : stage.mocha.surface1
        metal: stage.look === "paper" ? stage.mocha.text : stage.skin.metal || stage.mocha.subtext1
        leather: stage.look === "neon" ? Qt.darker(stage.mocha.base, 1.25)
            : stage.look === "paper" ? stage.mocha.base
            : stage.look === "wood" ? Qt.tint("#2e2520", Qt.rgba(stage.mocha.surface1.r, stage.mocha.surface1.g, stage.mocha.surface1.b, 0.12))
            : Qt.darker(stage.mocha.surface0, 1.35)
        transform: Rotation {
            origin.x: stage.finalX + stage.rigWidth / 2
            origin.y: stage.finalY + stage.topDepth
            axis { x: 0; y: 1; z: 0 }
            angle: stage.sway
        }
    }
    // Koptelefoon: links naast de speler op tafel, iets gedraaid en iets
    // naar voren. X en Z in eenheden van de koptelefoon (Z naar achteren).
    property real phonesTurn: 14
    property real phonesForward: upright ? 0.3 : -0.15
    // Aansluiting voor het snoer: [punt, richting naar buiten] in
    // cameracoördinaten (zoals cam()); null = losse stekker.
    property var jackAt: null
    // Terug van camera- naar koptelefoon-coördinaten (X, Z, H), het
    // omgekeerde van phonesProject vóór de camera.
    function toPhones(c, dir) {
        let u = phonesWidth / 100, t = phonesTurn * Math.PI / 180;
        let ct = Math.cos(t), st = Math.sin(t);
        let tableY = upright ? -topDepth / 2 : -boxDepth;
        let front = upright ? boxDepth / 2 : topDepth / 2;
        let px = dir ? c[0] : c[0] + rigWidth / 2 + phonesWidth * 0.56;
        let pz = dir ? -c[2] : front - topDepth * 0.1 + rigWidth * phonesForward - c[2];
        let h = dir ? c[1] : c[1] - tableY;
        // Een richting blijft een eenheidsvector, een punt gaat naar u.
        let d = dir ? 1 : u;
        return [(px * ct + pz * st) / d, (-px * st + pz * ct) / d, h / d];
    }
    readonly property var phonesJack: jackAt ? [toPhones(jackAt[0], false), toPhones(jackAt[1], true)] : null
    function phonesProject(X, Z, H) {
        let u = phonesWidth / 100, t = phonesTurn * Math.PI / 180;
        let ct = Math.cos(t), st = Math.sin(t);
        let px = (X * ct - Z * st) * u, pz = (X * st + Z * ct) * u;
        let tableY = upright ? -topDepth / 2 : -boxDepth;
        let front = upright ? boxDepth / 2 : topDepth / 2;
        let p = camFinal(-rigWidth / 2 - phonesWidth * 0.56 + px, tableY + H * u,
                    front - topDepth * 0.1 + rigWidth * phonesForward - pz);
        return [finalX + p[0], finalY + p[1], p[2]];
    }

    Item {
        id: rig
        width: stage.rigWidth
        height: stage.topDepth
        x: stage.fromOrigin ? stage.lerp(stage.originRect.x, stage.finalX, stage.growT) : stage.finalX
        y: stage.fromOrigin ? stage.lerp(stage.originRect.y, stage.finalY, stage.growT)
                            : stage.finalY + (1 - stage.reveal) * 60
        transformOrigin: stage.fromOrigin ? Item.TopLeft : Item.Center
        opacity: stage.fromOrigin ? 1 : stage.reveal
        scale: stage.fromOrigin
            ? stage.lerp(stage.originRect.width / stage.rigWidth, 1, stage.growT)
            : 0.9 + 0.1 * stage.reveal
        transform: Rotation {
            origin.x: rig.width / 2
            origin.y: rig.height
            axis { x: 0; y: 1; z: 0 }
            angle: stage.sway
        }

        // Zachte schaduw op tafel onder de kast.
        Shape {
            id: shadow
            visible: stage.look !== "paper" && stage.camT > 0.01
            opacity: stage.reveal * stage.camT
            preferredRendererType: stage.settled ? Shape.CurveRenderer : Shape.GeometryRenderer
            layer.enabled: visible
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 48; blur: 1.0 }
            readonly property string path: {
                let pts = [], n = 28, w = stage.rigWidth, d = stage.boxDepth;
                for (let i = 0; i < n; i++) {
                    let a = i / n * Math.PI * 2;
                    if (stage.upright)
                        pts.push(stage.proj(w / 2 + Math.cos(a) * w * 0.56, stage.topDepth, d / 2 + Math.sin(a) * d * 0.75));
                    else
                        pts.push(stage.proj(w / 2 + Math.cos(a) * w * 0.53, stage.topDepth / 2 + Math.sin(a) * stage.topDepth * 0.53, d));
                }
                return stage.svg(pts, true);
            }
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Qt.rgba(0, 0, 0, 0.5)
                PathSvg { path: shadow.path }
            }
        }

        // Klikken op het apparaat zelf sluit niet.
        MouseArea {
            x: -parent.width * 0.05
            y: -parent.height * 0.15
            width: parent.width * 1.15
            height: parent.height * 1.35
        }

        // Paper: harde inktschaduw, zoals een getekend apparaat.
        Shape {
            visible: stage.look === "paper"
            x: 9
            y: 9
            preferredRendererType: stage.settled ? Shape.CurveRenderer : Shape.GeometryRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Qt.rgba(stage.mocha.text.r, stage.mocha.text.g, stage.mocha.text.b, 0.85)
                PathSvg { path: stage.upright ? shell.outline : stage.lyingShell.outline }
            }
        }

        // Staand: de kast achter het front. De omtrek is het front plus
        // dezelfde vorm naar achteren (convex omhulsel); daarover de
        // bovenkant lichter.
        Shape {
            id: shell
            visible: stage.upright && stage.camT > 0.01
            preferredRendererType: stage.settled ? Shape.CurveRenderer : Shape.GeometryRenderer
            readonly property real r: Math.min(stage.bodyRadius, stage.rigWidth * 0.2)
            // Hoekpunten van het afgeronde front, alleen de gevraagde hoeken.
            function corners(which, z) {
                let pts = [], n = 6, w = stage.rigWidth, h = stage.topDepth;
                let c = { tr: [w - r, r, 0], tl: [r, r, 0.5], bl: [r, h - r, 1], br: [w - r, h - r, 1.5] };
                for (let key of which) {
                    let cc = c[key];
                    for (let i = 0; i <= n; i++) {
                        let a = (cc[2] + 0.5 * i / n) * Math.PI;
                        pts.push(stage.proj(cc[0] + r * Math.cos(a), cc[1] - r * Math.sin(a), z));
                    }
                }
                return pts;
            }
            readonly property var all: ["tr", "tl", "bl", "br"]
            readonly property string outline: stage.upright ? stage.svg(stage.hull(corners(all, 0).concat(corners(all, stage.boxDepth))), true) : "M 0 0"
            readonly property string topOutline: stage.upright ? stage.svg(stage.hull(corners(["tr", "tl"], 0).concat(corners(["tr", "tl"], stage.boxDepth))), true) : "M 0 0"
            readonly property var sideA: stage.proj(stage.rigWidth, 0, 0)
            readonly property var sideB: stage.proj(stage.rigWidth, 0, stage.boxDepth)
            ShapePath {
                strokeWidth: stage.look === "paper" ? 2 : 1
                strokeColor: stage.look === "paper" ? stage.mocha.text : stage.skin.shellEdge || Qt.rgba(0, 0, 0, 0.4)
                fillGradient: LinearGradient {
                    x1: shell.sideA[0]; y1: 0
                    x2: shell.sideB[0]; y2: 0
                    GradientStop { position: 0.0; color: stage.skin.shellSide || "#333" }
                    GradientStop { position: 1.0; color: Qt.darker(stage.skin.shellSide || "#333", stage.look === "paper" ? 1 : 1.3) }
                }
                PathSvg { path: shell.outline }
            }
            ShapePath {
                strokeWidth: stage.look === "paper" ? 2 : 0
                strokeColor: stage.look === "paper" ? stage.mocha.text : "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: shell.sideB[1]
                    x2: 0; y2: shell.sideA[1]
                    GradientStop { position: 0.0; color: Qt.darker(stage.skin.shellTop || "#555", stage.look === "paper" ? 1 : 1.12) }
                    GradientStop { position: 1.0; color: stage.skin.shellTop || "#555" }
                }
                PathSvg { path: shell.topOutline }
            }
        }

        // Liggend: de zichtbare zijkant van de kast, belicht van links.
        Shape {
            id: side
            visible: !stage.upright && stage.camT > 0.01
            preferredRendererType: stage.settled ? Shape.CurveRenderer : Shape.GeometryRenderer
            ShapePath {
                strokeWidth: stage.look === "paper" ? 2 : stage.look === "neon" ? 1.5 : 1
                strokeColor: stage.look === "paper" ? stage.mocha.text
                    : stage.look === "neon" ? Qt.rgba(stage.accent.r, stage.accent.g, stage.accent.b, 0.7)
                    : Qt.rgba(0, 0, 0, 0.35)
                fillGradient: LinearGradient {
                    x1: 0; y1: 0
                    x2: stage.rigWidth; y2: 0
                    GradientStop { position: 0.0; color: Qt.lighter(stage.skin.frontA || "#333", stage.look === "paper" ? 1 : 1.15) }
                    GradientStop { position: 0.55; color: stage.skin.frontA || "#333" }
                    GradientStop { position: 1.0; color: stage.skin.frontB || "#222" }
                }
                PathSvg { path: stage.lyingShell.side }
            }
            // Lichtrand langs de bovenrand.
            ShapePath {
                strokeWidth: stage.look === "wood" ? 2.5 : stage.look === "neon" ? 2 : 1.2
                strokeColor: stage.skin.frontEdge || "transparent"
                fillColor: "transparent"
                PathSvg { path: stage.lyingShell.top }
            }
        }
        // Neon: gloed langs de omtrek.
        Shape {
            visible: stage.look === "neon" && stage.camT > 0.01
            preferredRendererType: stage.settled ? Shape.CurveRenderer : Shape.GeometryRenderer
            opacity: stage.playing ? 0.8 : 0.5
            ShapePath {
                strokeWidth: 1.5
                strokeColor: stage.accent
                fillColor: "transparent"
                PathSvg { path: stage.upright ? shell.outline : stage.lyingShell.outline }
            }
        }

        // Bovenkant (liggend) of front (staand), op de camera gelegd.
        Item {
            id: topFace
            width: parent.width
            height: stage.topDepth
            transform: Matrix4x4 { matrix: stage.faceMatrix }
        }
        // Onderdelen op de kast (knoppen, wieltje), in rig-coördinaten.
        Item {
            id: shellLayer
        }
        Item {
            id: frontContent
            opacity: stage.fromOrigin ? stage.clamp01((stage.camT - 0.3) * 2) : 1
            visible: opacity > 0.01
        }
    }

    // Het snoer ligt voor het apparaat langs, dus erover heen getekend.
    WoodHeadphones {
        anchors.fill: parent
        part: "cable"
        cableDepth: decoration.cableDepth
        jack: decoration.jack
        visible: decoration.visible
        opacity: decoration.opacity
        layer.enabled: decoration.layer.enabled
        mocha: decoration.mocha
        u: decoration.u
        k: decoration.k
        project: decoration.project
        wood: decoration.wood
        metal: decoration.metal
        leather: decoration.leather
        look: decoration.look
        ink: decoration.ink
        glow: decoration.glow
        transform: Rotation {
            origin.x: stage.finalX + stage.rigWidth / 2
            origin.y: stage.finalY + stage.topDepth
            axis { x: 0; y: 1; z: 0 }
            angle: stage.sway
        }
    }

    // Laagste punt van het apparaat in beeld, voor de titel eronder.
    readonly property real imageBottom: upright
        ? Math.max(proj(0, topDepth, 0)[1], proj(rigWidth, topDepth, 0)[1], proj(rigWidth, topDepth, boxDepth)[1])
        : proj(rigWidth / 2, topDepth, boxDepth)[1]


    // --- Titel en hint -------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.finalY + Math.max(stage.topDepth, stage.imageBottom) + stage.height * 0.035
        spacing: 4
        opacity: stage.reveal
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, stage.width * 0.8)
            horizontalAlignment: Text.AlignHCenter
            text: stage.title
            elide: Text.ElideRight
            font.family: ThemeConfig.displayFont
            font.pixelSize: Math.max(20, stage.height * 0.034)
            font.weight: Font.Black
            color: stage.mocha.text
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, stage.width * 0.8)
            horizontalAlignment: Text.AlignHCenter
            text: [stage.artist, stage.album].filter(t => t !== "").join("  ·  ")
            visible: text !== ""
            elide: Text.ElideRight
            font.family: ThemeConfig.uiFont
            font.pixelSize: Math.max(13, stage.height * 0.017)
            color: stage.mocha.subtext0
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        opacity: 0.6 * stage.reveal
        text: stage.hint
        font.family: ThemeConfig.uiFont
        font.pixelSize: 12
        color: stage.skin.hint || stage.mocha.subtext0
    }
}
