import QtQuick
import ".."

// Target-lock omlijning rond elk zichtbaar venster.
//
// Twee dingen bepalen of dit vloeiend oogt:
//
//  1. Hoe vers de vensterpositie is. Hyprland stuurt tijdens een muis-drag géén
//     geometrie-events, dus die moet gepold worden. Dat doet WindowFrameSource
//     in een helperproces, dat alleen bij wijziging iets doorgeeft.
//  2. Hoe duur één frame is. Het frame bestaat uit vaste, één keer geschilderde
//     hoek- en knikcanvassen plus uitrekbare Rectangles, zodat verplaatsen en
//     verschalen puur geometrie is. De vorige versie hertekende per beweging
//     een Canvas ter grootte van het venster in een layer-FBO; dat is wat de
//     haperingen veroorzaakte.
//
// De delegates hangen aan een ListModel dat op adres gesynchroniseerd wordt.
// Bij een kale JS-array vervangt de Repeater alle delegates bij elke update,
// waardoor er niets valt te animeren.
Item {
    id: root

    required property var mocha
    required property var source
    required property string screenName
    property int monitorId: -1

    readonly property bool active: String(ThemeConfig.theme || ThemeConfig.styleFamily || "").toLowerCase() === "neon"
    readonly property color accentA: mocha.accent2 || mocha.teal || "#4de8f2"
    readonly property color accentB: mocha.accent3 || mocha.pink || "#ff4fd8"

    anchors.fill: parent
    visible: active

    function monitorForScreen() {
        let monitors = source.monitors || [];
        for (let i = 0; i < monitors.length; i++) {
            let mon = monitors[i];
            if (monitorId >= 0 && Number(mon.id) === Number(monitorId))
                return mon;
            if (String(mon.name || "") === screenName)
                return mon;
        }
        return null;
    }

    function onThisScreen(win, mon) {
        if (Number(win.m) !== Number(mon.id))
            return false;
        if (Number(win.p) === 1)
            return true;
        let workspaceId = Number(win.ws || 0);
        let activeWorkspaceId = Number(mon.aws || 0);
        let specialWorkspaceId = Number(mon.sws || 0);
        return workspaceId === activeWorkspaceId
            || (specialWorkspaceId !== 0 && workspaceId === specialWorkspaceId);
    }

    function rebuild() {
        if (!active) {
            if (frameModel.count > 0)
                frameModel.clear();
            return;
        }

        let mon = monitorForScreen();
        if (!mon) {
            if (frameModel.count > 0)
                frameModel.clear();
            return;
        }

        let list = source.clients || [];
        let mx = Number(mon.x || 0);
        let my = Number(mon.y || 0);
        let next = [];
        for (let i = 0; i < list.length; i++) {
            let win = list[i];
            if (!onThisScreen(win, mon))
                continue;
            next.push({
                address: String(win.a || ""),
                fx: Number(win.x || 0) - mx,
                fy: Number(win.y || 0) - my,
                fw: Number(win.w || 0),
                fh: Number(win.h || 0),
                factive: Number(win.f) === 1,
                ffloating: false
            });
        }
        syncFrames(next);
    }

    // Werkt het model bij zonder delegates te slopen. Geeft terug of er iets
    // aan de geometrie veranderde, zodat de polltik zich kan aanpassen.
    function syncFrames(next) {
        let changed = false;

        for (let i = frameModel.count - 1; i >= 0; i--) {
            let addr = frameModel.get(i).address;
            let stillThere = false;
            for (let j = 0; j < next.length; j++) {
                if (next[j].address === addr) {
                    stillThere = true;
                    break;
                }
            }
            if (!stillThere) {
                frameModel.remove(i);
                changed = true;
            }
        }

        for (let i = 0; i < next.length; i++) {
            let item = next[i];
            let idx = -1;
            for (let j = 0; j < frameModel.count; j++) {
                if (frameModel.get(j).address === item.address) {
                    idx = j;
                    break;
                }
            }
            if (idx === -1) {
                frameModel.append(item);
                changed = true;
                continue;
            }
            let row = frameModel.get(idx);
            if (row.fx !== item.fx) { frameModel.setProperty(idx, "fx", item.fx); changed = true; }
            if (row.fy !== item.fy) { frameModel.setProperty(idx, "fy", item.fy); changed = true; }
            if (row.fw !== item.fw) { frameModel.setProperty(idx, "fw", item.fw); changed = true; }
            if (row.fh !== item.fh) { frameModel.setProperty(idx, "fh", item.fh); changed = true; }
            if (row.factive !== item.factive) frameModel.setProperty(idx, "factive", item.factive);
            if (row.ffloating !== item.ffloating) frameModel.setProperty(idx, "ffloating", item.ffloating);
        }

        return changed;
    }

    ListModel { id: frameModel }

    Connections {
        target: root.source
        function onClientsChanged() { root.rebuild(); }
        function onMonitorsChanged() { root.rebuild(); }
    }

    onActiveChanged: rebuild()
    onScreenNameChanged: rebuild()
    onMonitorIdChanged: rebuild()
    Component.onCompleted: rebuild()

    Repeater {
        model: frameModel

        delegate: Item {
            id: frame

            required property string address
            required property real fx
            required property real fy
            required property real fw
            required property real fh
            required property bool factive
            required property bool ffloating

            readonly property real pad: 5
            readonly property real coreWidth: factive ? 1.6 : 1.15
            readonly property real glowAlpha: factive ? 0.20 : 0.10

            readonly property real targetX: fx - pad
            readonly property real targetY: fy - pad
            readonly property real targetW: fw + pad * 2
            readonly property real targetH: fh + pad * 2

            // Hoe ver het frame nog achterloopt op zijn doel.
            readonly property real drift: Math.abs(targetX - x) + Math.abs(targetY - y)
                + Math.abs(targetW - width) + Math.abs(targetH - height)

            // Spreiding van de hoekhaken: puur een transform, dus geen
            // hertekening tijdens de achtervolging. Met de tragere veer loopt
            // het frame verder achter, dus de deler is ruim: anders staat de
            // spreiding bij elke beweging meteen op zijn maximum.
            readonly property real chase: Math.min(1.0, drift / 480)

            // 1 = het frame zit vast om het venster, 0 = het is nog onderweg.
            // De laatste 40 pixels van de veerstaart zijn precies de inloop
            // waarin de kleur terugkomt.
            readonly property real lockAmount: Math.max(0.0, Math.min(1.0, 1.0 - drift / 40))

            readonly property color lockedColor: factive ? root.accentA : root.accentB
            readonly property color searchColor: "#96a0ac"
            readonly property color strokeColor: Qt.rgba(
                searchColor.r + (lockedColor.r - searchColor.r) * lockAmount,
                searchColor.g + (lockedColor.g - searchColor.g) * lockAmount,
                searchColor.b + (lockedColor.b - searchColor.b) * lockAmount,
                1.0)

            property bool primed: false
            Component.onCompleted: primed = true

            x: targetX
            y: targetY
            width: targetW
            height: targetH
            opacity: factive ? 1.0 : 0.58
            visible: width > 0 && height > 0

            // Veer in plaats van een vaste inhaalsnelheid: de trekkracht is
            // evenredig met de achterstand, dus het frame blijft tijdens het
            // slepen op een vaste afstand hangen en glijdt er daarna zacht in.
            // Bij een snelheidslimiet zou de achterstand tijdens een snelle
            // sleep onbegrensd oplopen.
            Behavior on x {
                enabled: frame.primed
                SpringAnimation { spring: 2.4; damping: 0.55; mass: 1.15; epsilon: 0.3 }
            }
            Behavior on y {
                enabled: frame.primed
                SpringAnimation { spring: 2.4; damping: 0.55; mass: 1.15; epsilon: 0.3 }
            }
            // De maten mogen minder naschommelen: een frame dat "ademt" leest
            // als een fout, een frame dat naloopt als een lock.
            Behavior on width {
                enabled: frame.primed
                SpringAnimation { spring: 3.0; damping: 0.8; mass: 1.0; epsilon: 0.3 }
            }
            Behavior on height {
                enabled: frame.primed
                SpringAnimation { spring: 3.0; damping: 0.8; mass: 1.0; epsilon: 0.3 }
            }
            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
            }

            Item {
                id: reticle
                anchors.fill: parent
                anchors.margins: 2.5

                readonly property real cut: 16
                readonly property real armLen: 30
                readonly property real cornerSize: cut + armLen
                // Vaste knikbreedte, zodat het canvas nooit hoeft te
                // hertekenen. Te smalle vensters krijgen een doorlopende rand.
                readonly property real jogWidth:
                    width > cornerSize * 2 + 190 ? 150 : 0
                readonly property real segmentWidth:
                    Math.max(0, (width - jogWidth) / 2 - cornerSize)

                // -- randen ------------------------------------------------
                TechLine {
                    x: reticle.cornerSize
                    y: 0
                    width: reticle.segmentWidth
                    tint: frame.strokeColor
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }
                TechLine {
                    x: (reticle.width + reticle.jogWidth) / 2
                    y: 0
                    width: reticle.segmentWidth
                    tint: frame.strokeColor
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }
                TechLine {
                    x: reticle.cornerSize
                    y: reticle.height
                    width: reticle.segmentWidth
                    tint: frame.strokeColor
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }
                TechLine {
                    x: (reticle.width + reticle.jogWidth) / 2
                    y: reticle.height
                    width: reticle.segmentWidth
                    tint: frame.strokeColor
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }
                TechLine {
                    horizontal: false
                    x: 0
                    y: reticle.cornerSize
                    height: Math.max(0, reticle.height - reticle.cornerSize * 2)
                    tint: frame.strokeColor
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }
                TechLine {
                    horizontal: false
                    x: reticle.width
                    y: reticle.cornerSize
                    height: Math.max(0, reticle.height - reticle.cornerSize * 2)
                    tint: frame.strokeColor
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }

                // -- middenknik boven en onder -----------------------------
                TechJog {
                    visible: reticle.jogWidth > 0
                    x: (reticle.width - reticle.jogWidth) / 2
                    y: -jogPad
                    tint: frame.lockedColor
                    idleTint: frame.searchColor
                    lock: frame.lockAmount
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }
                TechJog {
                    visible: reticle.jogWidth > 0
                    x: (reticle.width - reticle.jogWidth) / 2
                    y: reticle.height - height + jogPad
                    rotation: 180
                    tint: frame.lockedColor
                    idleTint: frame.searchColor
                    lock: frame.lockAmount
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }

                // -- hoekhaken ---------------------------------------------
                // Eén geschilderd canvas, vier keer geroteerd neergezet.
                TechCorner {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    rotation: 0
                    scale: 1 + frame.chase * 0.20
                    tint: frame.lockedColor
                    idleTint: frame.searchColor
                    lock: frame.lockAmount
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }
                TechCorner {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    rotation: 90
                    scale: 1 + frame.chase * 0.20
                    tint: frame.lockedColor
                    idleTint: frame.searchColor
                    lock: frame.lockAmount
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }
                TechCorner {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    rotation: 180
                    scale: 1 + frame.chase * 0.20
                    tint: frame.lockedColor
                    idleTint: frame.searchColor
                    lock: frame.lockAmount
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }
                TechCorner {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    rotation: 270
                    scale: 1 + frame.chase * 0.20
                    tint: frame.lockedColor
                    idleTint: frame.searchColor
                    lock: frame.lockAmount
                    strong: frame.factive
                    coreWidth: frame.coreWidth
                    glowAlpha: frame.glowAlpha
                }

                // -- streepjes bij de hoeken -------------------------------
                Repeater {
                    model: 4
                    Rectangle {
                        width: 20
                        height: 1
                        color: Qt.rgba(frame.strokeColor.r, frame.strokeColor.g, frame.strokeColor.b,
                            frame.factive ? 0.78 : 0.46)
                        x: index % 2 === 0
                            ? reticle.cut + 8
                            : reticle.width - reticle.cut - 28
                        y: index < 2 ? 9 : reticle.height - 9
                    }
                }
            }
        }
    }

    // Uitrekbaar randsegment: donkere onderlaag voor contrast, brede zachte
    // gloed, dunne kern. Alle drie zijn Rectangles, dus meebewegen kost niets.
    component TechLine: Item {
        property bool horizontal: true
        property color tint: "#ffffff"
        property bool strong: false
        property real coreWidth: 1.4
        property real glowAlpha: 0.14

        Rectangle {
            anchors.centerIn: parent
            width: parent.horizontal ? parent.width : 3
            height: parent.horizontal ? 3 : parent.height
            color: Qt.rgba(0, 0, 0, parent.strong ? 0.38 : 0.22)
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.horizontal ? parent.width : 6
            height: parent.horizontal ? 6 : parent.height
            color: Qt.rgba(parent.tint.r, parent.tint.g, parent.tint.b, parent.glowAlpha)
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.horizontal ? parent.width : parent.coreWidth
            height: parent.horizontal ? parent.coreWidth : parent.height
            color: Qt.rgba(parent.tint.r, parent.tint.g, parent.tint.b, parent.strong ? 1.0 : 0.72)
        }
    }

    // De knik in het midden van de boven- en onderrand. Vaste maat, dus dit
    // canvas wordt één keer geschilderd en daarna alleen nog verplaatst.
    //
    // De grijs/gekleurd-wissel gaat via twee over elkaar gefade tekeningen, niet
    // via één canvas met een wisselende kleur: dat laatste zou per beeldje een
    // hertekening kosten, precies waar deze opzet vanaf wilde.
    component TechJog: Item {
        property color tint: "#ffffff"
        property color idleTint: "#96a0ac"
        property real lock: 1
        property bool strong: false
        property real coreWidth: 1.4
        property real glowAlpha: 0.14
        readonly property real jogPad: 4

        width: 150
        height: 19
        transformOrigin: Item.Center

        TechJogArt {
            anchors.fill: parent
            // Volledig uitfaden in plaats van eronder blijven liggen: anders
            // mengt de antialias-rand van de gekleurde lijn met het grijs.
            opacity: 1 - parent.lock
            tint: parent.idleTint
            strong: parent.strong
            coreWidth: parent.coreWidth
            glowAlpha: parent.glowAlpha
        }
        TechJogArt {
            anchors.fill: parent
            opacity: parent.lock
            tint: parent.tint
            strong: parent.strong
            coreWidth: parent.coreWidth
            glowAlpha: parent.glowAlpha
        }
    }

    component TechJogArt: Canvas {
        property color tint: "#ffffff"
        property bool strong: false
        property real coreWidth: 1.4
        property real glowAlpha: 0.14
        readonly property real jogPad: 4
        readonly property real depth: 11
        readonly property real slope: 18

        antialiasing: true
        smooth: true

        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = jogPad;
            ctx.lineJoin = "miter";
            ctx.lineCap = "butt";

            ctx.beginPath();
            ctx.moveTo(0, p);
            ctx.lineTo(slope, p + depth);
            ctx.lineTo(width - slope, p + depth);
            ctx.lineTo(width, p);

            ctx.strokeStyle = Qt.rgba(0, 0, 0, strong ? 0.38 : 0.22);
            ctx.lineWidth = strong ? 3.4 : 2.6;
            ctx.stroke();

            ctx.strokeStyle = Qt.rgba(tint.r, tint.g, tint.b, glowAlpha * 1.6);
            ctx.lineWidth = 6;
            ctx.stroke();

            ctx.strokeStyle = Qt.rgba(tint.r, tint.g, tint.b, strong ? 1.0 : 0.72);
            ctx.lineWidth = coreWidth;
            ctx.stroke();
        }

        onTintChanged: requestPaint()
        onStrongChanged: requestPaint()
    }

    // Hoekhaak met afgesneden punt. Vierkant, zodat dezelfde tekening met
    // 90-graden-stappen op alle vier de hoeken past. Net als bij de knik zitten
    // er twee vaste tekeningen in die over elkaar heen faden.
    component TechCorner: Item {
        property color tint: "#ffffff"
        property color idleTint: "#96a0ac"
        property real lock: 1
        property bool strong: false
        property real coreWidth: 1.4
        property real glowAlpha: 0.14
        readonly property real cornerPad: 3

        width: 16 + 30 + cornerPad
        height: width
        anchors.margins: -cornerPad
        transformOrigin: Item.Center

        TechCornerArt {
            anchors.fill: parent
            // Volledig uitfaden in plaats van eronder blijven liggen: anders
            // mengt de antialias-rand van de gekleurde lijn met het grijs.
            opacity: 1 - parent.lock
            tint: parent.idleTint
            strong: parent.strong
            coreWidth: parent.coreWidth
            glowAlpha: parent.glowAlpha
        }
        TechCornerArt {
            anchors.fill: parent
            opacity: parent.lock
            tint: parent.tint
            strong: parent.strong
            coreWidth: parent.coreWidth
            glowAlpha: parent.glowAlpha
        }
    }

    component TechCornerArt: Canvas {
        property color tint: "#ffffff"
        property bool strong: false
        property real coreWidth: 1.4
        property real glowAlpha: 0.14
        readonly property real cornerPad: 3
        readonly property real cut: 16
        readonly property real armLen: 30

        antialiasing: true
        smooth: true

        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let p = cornerPad;
            ctx.lineJoin = "miter";
            ctx.lineCap = "butt";

            ctx.beginPath();
            ctx.moveTo(p + cut + armLen, p);
            ctx.lineTo(p + cut, p);
            ctx.lineTo(p, p + cut);
            ctx.lineTo(p, p + cut + armLen);

            ctx.strokeStyle = Qt.rgba(0, 0, 0, strong ? 0.38 : 0.22);
            ctx.lineWidth = strong ? 3.4 : 2.6;
            ctx.stroke();

            ctx.strokeStyle = Qt.rgba(tint.r, tint.g, tint.b, glowAlpha * 1.6);
            ctx.lineWidth = 6;
            ctx.stroke();

            ctx.strokeStyle = Qt.rgba(tint.r, tint.g, tint.b, strong ? 1.0 : 0.72);
            ctx.lineWidth = coreWidth;
            ctx.shadowColor = Qt.rgba(tint.r, tint.g, tint.b, strong ? 0.70 : 0.30);
            ctx.shadowBlur = strong ? 9 : 4;
            ctx.stroke();
        }

        onTintChanged: requestPaint()
        onStrongChanged: requestPaint()
    }
}
