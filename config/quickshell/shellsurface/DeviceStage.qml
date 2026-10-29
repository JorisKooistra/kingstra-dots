import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import ".."

// Gedeeld podium voor de schermvullende cassettespeler en discman, met
// dezelfde regels als de draaitafel (VinylStageContent): de bovenkant van
// het apparaat staat in perspectief, de voorkant kijkt naar je en draagt de
// knoppen. De overgang vanuit de kleine speler op het bureaublad loopt in
// rustige fases: eerst groeit de platte speler naar zijn plek, dan kantelt
// hij en vouwt de voorkant uit, pas daarna komen de details erbij.
//
// Inhoud: topData (de bovenkant, vult het vlak) en frontData (de knoppen op
// de voorkant). Alleen QtQuick: het venster eromheen staat in VinylStage.qml.
//
// Staand (upright, de cassettespeler): het front kijkt recht naar je en de
// kast heeft diepte naar achteren. Je kijkt er iets van rechtsboven op, dus
// je ziet de bovenkant (met de knoppen, shellData) en de rechterzijkant
// (met het wieltje). Die vouwen uit in de tweede fase van de overgang.
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
    property real maxTilt: 38
    property bool upright: false
    // Staand: hoogte van het front en hoe ver de achterkant in beeld
    // verschuift (naar rechtsboven), beide t.o.v. de breedte.
    property real faceAspect: 0.71
    property real obliqueX: 0.085
    property real obliqueY: 0.12

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

    property alias topData: topFace.data
    property alias frontData: frontContent.data
    property alias shellData: shellLayer.data
    readonly property alias frontWidth: front.width

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
    readonly property real foreshorten: Math.cos(maxTilt * Math.PI / 180)
    readonly property real rigWidth: upright
        ? Math.min(width * widthShare, height * 0.64 / (faceAspect + obliqueY))
        : Math.min(width * widthShare, height * 0.70 / (topAspect * foreshorten + frontRatio))
    readonly property real topDepth: upright ? rigWidth * faceAspect : rigWidth * topAspect
    readonly property real frontHeight: upright ? 0 : rigWidth * frontRatio
    readonly property real tilt: upright ? 0 : fromOrigin ? maxTilt * tiltT : 8 + (maxTilt - 8) * reveal
    // Staand: diepte van de kast in beeld; groeit mee in de tweede fase.
    readonly property real extrudeT: fromOrigin ? tiltT : reveal
    readonly property real offX: upright ? rigWidth * obliqueX * extrudeT : 0
    readonly property real offY: upright ? rigWidth * obliqueY * extrudeT : 0
    readonly property real finalX: upright ? (width - rigWidth * (1 + obliqueX)) / 2 + rigWidth * 0.06 : (width - rigWidth) / 2
    readonly property real visibleHeight: upright ? topDepth + rigWidth * obliqueY : topDepth * foreshorten + frontHeight
    readonly property real finalY: upright
        ? (height - visibleHeight - height * 0.11) / 2 + rigWidth * obliqueY
        : (height - visibleHeight - height * 0.11) / 2 - topDepth * (1 - foreshorten)
    // Kast-hoeken in de voorkant: de afronding van de bovenkant, gezien
    // onder de eindhoek (ellips). Een ronde kast (discman) heeft als
    // voorkant een gebogen band.
    readonly property real cornerX: Math.min(bodyRadius, rigWidth * 0.5)
    readonly property real cornerY: cornerX * foreshorten
    // Bovenrand van de voorkant op hoogte x (in pixels, t.o.v. de voorkant),
    // om knoppen op een gebogen band te zetten.
    function rimY(x) {
        let p = band.rim;
        if (p.length === 0) return 0;
        if (x <= p[0][0]) return p[0][1];
        for (let i = 1; i < p.length; i++) {
            if (x <= p[i][0]) {
                let a = p[i - 1], b = p[i];
                let t = b[0] > a[0] ? (x - a[0]) / (b[0] - a[0]) : 0;
                return a[1] + (b[1] - a[1]) * t;
            }
        }
        return p[p.length - 1][1];
    }

    // Organic: een houten koptelefoon ligt naast het apparaat op tafel, in
    // hetzelfde perspectief. Komt pas aan het eind van de overgang in beeld.
    WoodHeadphones {
        id: decoration
        visible: stage.look === "wood" && stage.detailT > 0.01
        opacity: stage.detailT
        mocha: stage.mocha
        width: stage.rigWidth * (stage.upright ? 0.58 : 0.5)
        // Tafel in beeld: hoe plat het tafelblad staat en hoe hoog dingen
        // erop worden.
        k: stage.upright ? 0.42 : Math.sin(stage.maxTilt * Math.PI / 180) * 0.9 + 0.12
        v: stage.upright ? 0.92 : Math.cos(stage.maxTilt * Math.PI / 180) * 0.55
        x: stage.finalX - width * (stage.upright ? 1.0 : 0.98)
        y: stage.upright ? stage.finalY + stage.topDepth - height * 0.86
                         : stage.finalY + stage.topDepth + stage.frontHeight - height * 0.9
        wood: Qt.tint(Qt.darker(stage.mocha.peach, 1.9), Qt.rgba(stage.tertiaryContainer.r, stage.tertiaryContainer.g, stage.tertiaryContainer.b, 0.35))
        metal: stage.skin.metal || stage.mocha.subtext1
        leather: Qt.tint(Qt.darker(stage.mocha.surface1, 1.2), Qt.rgba(stage.tertiaryContainer.r, stage.tertiaryContainer.g, stage.tertiaryContainer.b, 0.45))
        transform: Rotation {
            origin.x: decoration.width + stage.rigWidth / 2
            origin.y: decoration.height
            axis { x: 0; y: 1; z: 0 }
            angle: stage.sway
        }
    }

    Item {
        id: rig
        width: stage.rigWidth
        height: stage.topDepth + stage.frontHeight
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

        // Zachte schaduw onder de kast.
        Rectangle {
            visible: stage.look !== "paper" && !stage.upright
            opacity: stage.reveal
            width: parent.width * 1.02
            height: stage.frontHeight * 1.3
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height * 0.4
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.5)
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 48; blur: 1.0 }
        }

        // Staand: schaduw op tafel, onder de hele kast tot achteren.
        Rectangle {
            visible: stage.look !== "paper" && stage.upright
            opacity: stage.reveal
            x: -stage.rigWidth * 0.02
            width: parent.width + stage.offX + stage.rigWidth * 0.06
            height: stage.offY + stage.rigWidth * 0.07
            y: parent.height - height + stage.rigWidth * 0.035
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.55)
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 48; blur: 1.0 }
        }

        // Klikken op het apparaat zelf sluit niet.
        MouseArea {
            x: 0
            y: -stage.offY
            width: parent.width + stage.offX
            height: parent.height + stage.offY
        }

        // Staand: de kast achter het front. De omtrek is het front plus
        // dezelfde vorm naar achteren geschoven (convex omhulsel); daarover
        // de bovenkant lichter en een randje waar licht op valt.
        Shape {
            id: shell
            visible: stage.upright && stage.offY > 0.5
            preferredRendererType: Shape.CurveRenderer
            readonly property real r: Math.min(stage.bodyRadius, stage.rigWidth * 0.2)
            function corners(ox, oy, w, h, r, top) {
                let pts = [], n = 6;
                function arc(cx, cy, a0, a1) {
                    for (let i = 0; i <= n; i++) {
                        let a = a0 + (a1 - a0) * i / n;
                        pts.push([cx + r * Math.cos(a), cy - r * Math.sin(a)]);
                    }
                }
                arc(ox + w - r, oy + r, 0, Math.PI / 2);
                arc(ox + r, oy + r, Math.PI / 2, Math.PI);
                if (!top) {
                    arc(ox + r, oy + h - r, Math.PI, 1.5 * Math.PI);
                    arc(ox + w - r, oy + h - r, 1.5 * Math.PI, 2 * Math.PI);
                }
                return pts;
            }
            function hull(pts) {
                pts.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
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
                let out = lower.concat(upper), d = "M " + out[0][0].toFixed(2) + " " + out[0][1].toFixed(2);
                for (let i = 1; i < out.length; i++) d += " L " + out[i][0].toFixed(2) + " " + out[i][1].toFixed(2);
                return d + " Z";
            }
            readonly property string outline: {
                if (!stage.upright) return "";
                let w = stage.rigWidth, h = stage.topDepth;
                return hull(corners(0, 0, w, h, r, false).concat(corners(stage.offX, -stage.offY, w, h, r, false)));
            }
            readonly property string topOutline: {
                if (!stage.upright) return "";
                let w = stage.rigWidth;
                return hull(corners(0, 0, w, 0, r, true).concat(corners(stage.offX, -stage.offY, w, 0, r, true)));
            }
            ShapePath {
                strokeWidth: stage.look === "paper" ? 2 : 1
                strokeColor: stage.look === "paper" ? stage.mocha.text : stage.skin.shellEdge || Qt.rgba(0, 0, 0, 0.4)
                fillGradient: LinearGradient {
                    x1: stage.rigWidth; y1: 0
                    x2: stage.rigWidth + stage.offX; y2: 0
                    GradientStop { position: 0.0; color: stage.skin.shellSide || "#333" }
                    GradientStop { position: 1.0; color: Qt.darker(stage.skin.shellSide || "#333", stage.look === "paper" ? 1 : 1.25) }
                }
                PathSvg { path: shell.outline }
            }
            ShapePath {
                strokeWidth: stage.look === "paper" ? 2 : 0
                strokeColor: stage.look === "paper" ? stage.mocha.text : "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: -stage.offY
                    x2: 0; y2: 0
                    GradientStop { position: 0.0; color: Qt.darker(stage.skin.shellTop || "#555", stage.look === "paper" ? 1 : 1.12) }
                    GradientStop { position: 1.0; color: stage.skin.shellTop || "#555" }
                }
                PathSvg { path: shell.topOutline }
            }
        }
        // Neon: gloed langs de achterrand.
        Shape {
            visible: stage.upright && stage.look === "neon" && stage.offY > 0.5
            preferredRendererType: Shape.CurveRenderer
            opacity: stage.playing ? 0.8 : 0.5
            ShapePath {
                strokeWidth: 1.5
                strokeColor: stage.accent
                fillColor: "transparent"
                PathSvg { path: shell.outline }
            }
        }

        // Bovenkant, achterover gekanteld rond de voorrand.
        Item {
            id: topFace
            width: parent.width
            height: stage.topDepth
            transform: Rotation {
                origin.x: topFace.width / 2
                origin.y: topFace.height
                axis { x: 1; y: 0; z: 0 }
                angle: stage.tilt
            }
        }
        // Staand: alles op de bovenkant en zijkant (knoppen, wieltje).
        Item {
            id: shellLayer
            visible: stage.upright
        }

        // Voorkant: draait als één kast mee met de bovenkant.
        Item {
            id: front
            y: stage.topDepth
            width: parent.width
            height: stage.frontHeight
            opacity: stage.fromOrigin ? stage.clamp01((stage.tiltT - 0.06) * 3) : 1
            visible: !stage.upright && opacity > 0.01
            transform: Rotation {
                origin.x: front.width / 2
                origin.y: 0
                axis { x: 1; y: 0; z: 0 }
                angle: stage.tilt - stage.maxTilt
            }

            // Paper: harde inktschaduw, zoals een getekend apparaat.
            Shape {
                visible: stage.look === "paper"
                x: 9
                y: 9
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: Qt.rgba(stage.mocha.text.r, stage.mocha.text.g, stage.mocha.text.b, 0.85)
                    PathSvg { path: band.outline }
                }
            }
            Shape {
                id: band
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // Bovenrand volgt de afgeronde voorrand van de bovenkant, zoals
                // die onder de eindhoek in perspectief staat (Qt rekent met een
                // camera op 1024 px); de onderrand is dezelfde rand, een
                // kastdikte lager. Eén keer berekend, alleen bij een nieuwe maat.
                readonly property var rim: {
                    let w = front.width, r = stage.cornerX, t = stage.maxTilt * Math.PI / 180;
                    let cx = w / 2, d = 1024, pts = [];
                    function add(x, yy) {
                        let z = -yy * Math.sin(t), s = d / (d + z);
                        pts.push([cx + (x - cx) * s, yy * Math.cos(t) * s, s]);
                    }
                    // Meer punten bij een grote afronding (ronde kast).
                    let n = 8 + Math.round(r / Math.max(1, w) * 48);
                    for (let i = 0; i <= n; i++) {
                        let a = i / n * Math.PI / 2;
                        add(r - r * Math.cos(a), -r + r * Math.sin(a));
                    }
                    for (let i = n; i >= 0; i--) {
                        let a = i / n * Math.PI / 2;
                        add(w - r + r * Math.cos(a), -r + r * Math.sin(a));
                    }
                    return pts;
                }
                function fmt(p, dy) { return p[0].toFixed(2) + " " + (p[1] + dy * p[2]).toFixed(2); }
                readonly property string topEdge: {
                    let p = rim, out = "M " + fmt(p[0], 0);
                    for (let i = 1; i < p.length; i++) out += " L " + fmt(p[i], 0);
                    return out;
                }
                readonly property string outline: {
                    let p = rim, f = front.height, out = topEdge;
                    for (let i = p.length - 1; i >= 0; i--) out += " L " + fmt(p[i], f);
                    return out + " Z";
                }
                readonly property real ry: stage.cornerY
                readonly property real f: front.height
                ShapePath {
                    strokeWidth: stage.look === "paper" ? 2 : stage.look === "neon" ? 1.5 : 1
                    strokeColor: stage.look === "paper" ? stage.mocha.text
                        : stage.look === "neon" ? Qt.rgba(stage.accent.r, stage.accent.g, stage.accent.b, 0.7)
                        : Qt.rgba(0, 0, 0, 0.35)
                    fillGradient: LinearGradient {
                        x1: 0; y1: -band.ry
                        x2: 0; y2: band.f
                        GradientStop { position: 0.0; color: stage.skin.frontA || "#333" }
                        GradientStop { position: 1.0; color: stage.skin.frontB || "#222" }
                    }
                    PathSvg { path: band.outline }
                }
                // Lichtrand langs de bovenkant van de voorkant.
                ShapePath {
                    strokeWidth: stage.look === "wood" ? 2.5 : stage.look === "neon" ? 2 : 1.2
                    strokeColor: stage.skin.frontEdge || "transparent"
                    fillColor: "transparent"
                    PathSvg { path: band.topEdge }
                }
            }
            // Neon: scanlijnen over de voorkant.
            Repeater {
                model: stage.look === "neon" ? Math.floor(front.height / 4) : 0
                Rectangle {
                    required property int index
                    x: stage.cornerX
                    width: front.width - 2 * stage.cornerX
                    y: 3 + index * 4
                    height: 1
                    color: Qt.rgba(stage.accent.r, stage.accent.g, stage.accent.b, 0.04)
                }
            }
            Item {
                id: frontContent
                anchors.fill: parent
            }
        }
    }

    // --- Titel en hint -------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.finalY + rig.height + stage.height * 0.035
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
