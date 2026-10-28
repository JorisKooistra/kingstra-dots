import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"

Scope {
    id: root
    property bool shown: false
    property bool primed: false
    property string lastToken: ""
    property int workspace: 0
    property var snapshot: ({area: {x: 0, y: 0, w: 1, h: 1}, windows: []})
    property int selected: 0
    property real zoom: 1
    property real pendingX: 0
    property real pendingY: 0
    property real dragX: 0
    property real dragY: 0
    property bool dragged: false
    // Een venster verslepen naar een andere plek (alleen op de kaart).
    property int movingIndex: -1
    property real moveX: 0
    property real moveY: 0
    readonly property var camera: snapshot.camera || ({col: 0, row: 0, x: 0, y: 0})
    readonly property var pitch: snapshot.pitch || ({x: area.w, y: area.h})
    property string errorText: ""
    // Nieuw bij elke keer openen, zodat bewaarde miniaturen opnieuw laden.
    property int thumbStamp: 0
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/scripts/workspace-layout.py"
    readonly property var windows: snapshot.windows || []
    readonly property var area: snapshot.area || ({x: 0, y: 0, w: 1, h: 1})
    readonly property var bounds: {
        let x = area.x, y = area.y, r = x + area.w, b = y + area.h;
        for (let w of windows) {
            x = Math.min(x, w.x); y = Math.min(y, w.y);
            r = Math.max(r, w.x + w.w); b = Math.max(b, w.y + w.h);
        }
        return {x: x, y: y, w: Math.max(1, r - x), h: Math.max(1, b - y)};
    }
    MatugenColors { id: colors }
    // Wiel zoomt vloeiend: de kaart volgt zoomTarget met een korte animatie.
    property real zoomTarget: 1
    Behavior on zoom { NumberAnimation { duration: ThemeConfig.duration(180); easing.type: Easing.OutCubic } }
    onZoomTargetChanged: zoom = zoomTarget

    // Live beeld per venster: Hyprland-adres → Wayland-toplevel.
    function toplevelFor(address) {
        let wanted = String(address || "").toLowerCase();
        for (let t of ToplevelManager.toplevels.values) {
            let hypr = t.HyprlandToplevel;
            if (hypr && ("0x" + hypr.address).toLowerCase() === wanted) return t;
        }
        return null;
    }
    function zoomBy(angle) {
        zoomTarget = Math.max(0.2, Math.min(4, zoomTarget * (angle > 0 ? 1.12 : 1 / 1.12)));
    }

    function request(raw) {
        if (!primed) { primed = true; return; }
        try {
            let d = JSON.parse(raw);
            if (String(d.token) === lastToken) return;
            lastToken = String(d.token);
            if (shown) { shown = false; return; }
            workspace = Number(d.workspace);
            selected = 0; zoomTarget = 1; errorText = ""; thumbStamp += 1;
            shown = true;
            snapshotFile.reload();
            focusTimer.restart();
        } catch (e) {}
    }
    function choose(index) {
        if (index < 0 || index >= windows.length) return;
        Quickshell.execDetached(["python3", helper, "select", String(windows[index].address)]);
        shown = false;
    }
    function step(dx, dy) {
        let source = windows[selected];
        if (!source) return;
        let best = -1, score = Infinity;
        for (let i = 0; i < windows.length; ++i) {
            let w = windows[i], x = w.col - source.col, y = w.row - source.row;
            if ((dx && x * dx <= 0) || (dy && y * dy <= 0)) continue;
            let distance = Math.abs(dx ? y : x) * 1000 + Math.abs(x) + Math.abs(y);
            if (distance < score) { score = distance; best = i; }
        }
        if (best >= 0) selected = best;
    }
    function beginDrag(x, y) { dragX = x; dragY = y; dragged = false; }
    // Werkvlakcoördinaat → plek (kolom, rij), met dezelfde maat als de layout.
    function cellAt(wx, wy) {
        let px = Math.max(1, Number(pitch.x) || area.w), py = Math.max(1, Number(pitch.y) || area.h);
        return {
            col: Number(camera.col) + Math.round((wx - (area.x + area.w / 2) + Number(camera.x)) / px),
            row: Number(camera.row) + Math.round((wy - (area.y + area.h / 2) + Number(camera.y)) / py)
        };
    }
    function cellBox(cell) {
        let px = Math.max(1, Number(pitch.x) || area.w), py = Math.max(1, Number(pitch.y) || area.h);
        let cx = area.x + area.w / 2 + (cell.col - Number(camera.col)) * px - Number(camera.x);
        let cy = area.y + area.h / 2 + (cell.row - Number(camera.row)) * py - Number(camera.y);
        return {x: cx - px / 2 + 6, y: cy - py / 2 + 6, w: px - 12, h: py - 12};
    }
    // Waar een versleept venster landt: plek, tegelplek (slot) en de vakken
    // om dat te tonen. Op een bezette plek telt het hele tegelvak.
    readonly property var dropSpot: {
        if (movingIndex < 0 || !windows[movingIndex]) return null;
        let moving = windows[movingIndex];
        let px = moving.x + moving.w / 2 + moveX / scene.mapScale;
        let py = moving.y + moving.h / 2 + moveY / scene.mapScale;
        let cells = {};
        for (let i = 0; i < windows.length; ++i) {
            if (i === movingIndex) continue;
            let w = windows[i], key = w.col + ":" + w.row, c = cells[key];
            if (!c) cells[key] = c = {col: w.col, row: w.row, x1: w.x, y1: w.y, x2: w.x + w.w, y2: w.y + w.h, count: 0};
            c.x1 = Math.min(c.x1, w.x); c.y1 = Math.min(c.y1, w.y);
            c.x2 = Math.max(c.x2, w.x + w.w); c.y2 = Math.max(c.y2, w.y + w.h);
            c.count += 1;
        }
        for (let key in cells) {
            let c = cells[key];
            if (px < c.x1 || px > c.x2 || py < c.y1 || py > c.y2) continue;
            let n = Math.min(c.count + 1, Math.max(1, Number(snapshot.max) || 4));
            let cols = n <= 3 ? n : Math.ceil(n / 2), rows = n <= 3 ? 1 : 2;
            let fx = Math.min(0.999, (px - c.x1) / Math.max(1, c.x2 - c.x1));
            let fy = Math.min(0.999, (py - c.y1) / Math.max(1, c.y2 - c.y1));
            let sc = Math.floor(fx * cols), sr = Math.floor(fy * rows);
            let slot = Math.min(sr * cols + sc, c.count);
            let box = {x: c.x1, y: c.y1, w: c.x2 - c.x1, h: c.y2 - c.y1};
            let tw = box.w / cols, th = box.h / rows;
            return {col: c.col, row: c.row, slot: slot, box: box,
                    slotBox: {x: box.x + sc * tw, y: box.y + sr * th, w: tw, h: th}};
        }
        let cell = cellAt(px, py);
        return {col: cell.col, row: cell.row, slot: 0, box: cellBox(cell), slotBox: null};
    }
    function finishMove() {
        let w = windows[movingIndex], spot = dropSpot;
        if (w && spot)
            Quickshell.execDetached(["python3", helper, "place", String(w.address),
                String(spot.col), String(spot.row), String(spot.slot)]);
        movingIndex = -1; moveX = 0; moveY = 0;
    }
    function drag(x, y) {
        let dx = x - dragX, dy = y - dragY;
        if (!dragged && dx * dx + dy * dy < 9) return;
        dragged = true; dragX = x; dragY = y;
        pendingX -= dx / scene.mapScale;
        pendingY -= dy / scene.mapScale;
    }
    onShownChanged: {
        overviewWindow.visible = shown;
        if (!shown) { pendingX = 0; pendingY = 0; }
    }
    FileView {
        id: requestFile
        path: root.runtime + "/kingstra-spatial-overview-request"
        preload: true
        watchChanges: true
        onInternalTextChanged: root.request(__text)
        onLoadFailed: root.primed = true
    }
    FileView {
        id: snapshotFile
        path: root.runtime + "/kingstra-spatial-" + root.workspace + ".json"
        watchChanges: true
        onLoaded: {
            try {
                let d = JSON.parse(text());
                if (Number(d.workspace) !== root.workspace) return;
                root.snapshot = d;
                root.selected = Math.min(root.selected, Math.max(0, root.windows.length - 1));
            } catch (e) {}
        }
    }
    Timer { interval: 200; repeat: true; running: true; onTriggered: requestFile.reload() }
    Timer { interval: 120; repeat: true; running: root.shown; onTriggered: snapshotFile.reload() }
    Timer {
        interval: 32; repeat: true; running: root.shown
        onTriggered: {
            if (panProcess.running || (Math.abs(root.pendingX) < 0.5 && Math.abs(root.pendingY) < 0.5)) return;
            panProcess.command = ["python3", root.helper, "panby", String(root.pendingX), String(root.pendingY)];
            root.pendingX = 0; root.pendingY = 0;
            panProcess.running = true;
        }
    }
    Process {
        id: panProcess
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.errorText = this.text.trim() }
    }
    Timer {
        id: focusTimer
        interval: 140
        onTriggered: {
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/hypr-dispatch.sh",
                "focuswindow", "title:^(Kingstra Werkvlak)$"]);
            content.forceActiveFocus();
        }
    }
    FloatingWindow {
        id: overviewWindow
        visible: false
        title: "Kingstra Werkvlak"
        implicitWidth: 1020
        implicitHeight: 680
        color: colors.base
        onVisibleChanged: if (!visible) root.shown = false

        Item {
            id: content
            anchors.fill: parent
            focus: true
            // Openen voelt als uitzoomen: de kaart komt van iets dichterbij binnen.
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 1.04
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(200); easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(240); easing.type: Easing.OutCubic } }
            Keys.onEscapePressed: root.shown = false
            Keys.onReturnPressed: root.choose(root.selected)
            Keys.onEnterPressed: root.choose(root.selected)
            Keys.onLeftPressed: root.step(-1, 0)
            Keys.onRightPressed: root.step(1, 0)
            Keys.onUpPressed: root.step(0, -1)
            Keys.onDownPressed: root.step(0, 1)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Werkvlak  ·  werkruimte " + root.workspace
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 22
                        font.bold: true
                        color: colors.text
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "Sluiten"
                        color: colors.primary
                        font.family: ThemeConfig.uiFont
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.shown = false }
                    }
                }
                Text {
                    text: "Sleep een venster naar een andere plek; op een venster wordt het een tegel. Sleep de achtergrond om je zicht te verschuiven. Wiel zoomt, klik kiest een venster."
                    color: colors.subtext0
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                Rectangle {
                    id: scene
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: colors.shellRaisedFill
                    radius: 12
                    clip: true
                    readonly property real mapScale: Math.max(0.001, Math.min((width - 48) / root.bounds.w, (height - 48) / root.bounds.h) * root.zoom)
                    readonly property real offsetX: (width - root.bounds.w * mapScale) / 2
                    readonly property real offsetY: (height - root.bounds.h * mapScale) / 2

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: mouse => root.beginDrag(mouse.x, mouse.y)
                        onPositionChanged: mouse => { if (pressed) root.drag(mouse.x, mouse.y); }
                        onWheel: wheel => { root.zoomBy(wheel.angleDelta.y); wheel.accepted = true; }
                    }
                    Repeater {
                        model: root.windows
                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool moving: root.movingIndex === index
                            x: scene.offsetX + (modelData.x - root.bounds.x) * scene.mapScale + (moving ? root.moveX : 0)
                            y: scene.offsetY + (modelData.y - root.bounds.y) * scene.mapScale + (moving ? root.moveY : 0)
                            z: moving ? 3 : 0
                            opacity: moving ? 0.85 : 1
                            width: Math.max(1, modelData.w * scene.mapScale)
                            height: Math.max(1, modelData.h * scene.mapScale)
                            readonly property bool chosen: root.selected === index
                            readonly property var toplevel: root.shown ? root.toplevelFor(modelData.address) : null
                            radius: 8
                            color: colors.base
                            border.color: chosen ? colors.primary : colors.shellOutline
                            border.width: chosen ? 2 : 1
                            clip: true
                            scale: moving ? 0.92 : chosen ? 1.0 : 0.985
                            Behavior on x { enabled: !tile.moving; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on y { enabled: !tile.moving; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(150) } }
                            Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }

                            // Live beeld van het venster zelf, zoals het gewone overzicht.
                            ScreencopyView {
                                id: preview
                                anchors.fill: parent
                                anchors.margins: tile.border.width
                                captureSource: tile.toplevel
                                live: root.shown
                                opacity: hasContent ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(200) } }
                            }
                            // Buiten beeld geeft Hyprland geen live beeld: dan het
                            // laatst bewaarde plaatje (werkvlak-thumb.sh).
                            Image {
                                id: still
                                anchors.fill: parent
                                anchors.margins: tile.border.width
                                visible: !preview.hasContent
                                source: root.shown ? "file://" + root.runtime + "/kingstra-thumbs/"
                                    + String(tile.modelData.address || "").toLowerCase().replace(/^0x/, "")
                                    + ".jpg?" + root.thumbStamp : ""
                                cache: false
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 640
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(200) } }
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: tile.radius
                                color: tile.chosen ? Qt.alpha(colors.primary, 0.16) : "transparent"
                                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                            }
                            // Titel: los op de tegel zonder beeld, als label onderin met beeld.
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                visible: (preview.hasContent || still.status === Image.Ready) && tile.height > 40
                                height: Math.min(26, parent.height / 3)
                                radius: height / 2
                                color: Qt.alpha(colors.base, 0.82)
                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10; anchors.rightMargin: 10
                                    verticalAlignment: Text.AlignVCenter
                                    text: String(tile.modelData.title || "Venster")
                                    color: colors.text
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            Text {
                                anchors.fill: parent
                                anchors.margins: 10
                                visible: !preview.hasContent && still.status !== Image.Ready
                                text: String(tile.modelData.title || "Venster")
                                color: colors.text
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                property real startX: 0
                                property real startY: 0
                                onPressed: mouse => {
                                    let p = mapToItem(scene, mouse.x, mouse.y);
                                    startX = p.x; startY = p.y;
                                    root.dragged = false;
                                    root.selected = tile.index;
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed) return;
                                    let p = mapToItem(scene, mouse.x, mouse.y);
                                    let dx = p.x - startX, dy = p.y - startY;
                                    if (root.movingIndex < 0 && dx * dx + dy * dy < 36) return;
                                    root.dragged = true;
                                    root.movingIndex = tile.index;
                                    root.moveX = dx; root.moveY = dy;
                                }
                                onReleased: if (root.movingIndex === tile.index) root.finishMove()
                                onCanceled: { root.movingIndex = -1; root.moveX = 0; root.moveY = 0; }
                                onClicked: if (!root.dragged) root.choose(tile.index)
                                onWheel: wheel => { root.zoomBy(wheel.angleDelta.y); wheel.accepted = true; }
                            }
                        }
                    }
                    // Doelplek tijdens het verslepen van een venster, met de
                    // tegelplek waar het venster precies komt.
                    Rectangle {
                        z: 1
                        readonly property var box: root.dropSpot ? root.dropSpot.box : null
                        visible: box !== null
                        x: box ? scene.offsetX + (box.x - root.bounds.x) * scene.mapScale : 0
                        y: box ? scene.offsetY + (box.y - root.bounds.y) * scene.mapScale : 0
                        width: box ? box.w * scene.mapScale : 0
                        height: box ? box.h * scene.mapScale : 0
                        radius: 10
                        color: Qt.alpha(colors.primary, 0.08)
                        border.color: Qt.alpha(colors.primary, 0.6)
                        border.width: 1
                        Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    }
                    Rectangle {
                        z: 4
                        readonly property var box: root.dropSpot ? (root.dropSpot.slotBox || root.dropSpot.box) : null
                        visible: box !== null
                        x: box ? scene.offsetX + (box.x - root.bounds.x) * scene.mapScale + 3 : 0
                        y: box ? scene.offsetY + (box.y - root.bounds.y) * scene.mapScale + 3 : 0
                        width: box ? Math.max(1, box.w * scene.mapScale - 6) : 0
                        height: box ? Math.max(1, box.h * scene.mapScale - 6) : 0
                        radius: 8
                        color: Qt.alpha(colors.primary, 0.22)
                        border.color: colors.primary
                        border.width: 2
                        Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    }
                    // Zichtgebied boven de tegels, zodat het kader zichtbaar blijft
                    // ook als een venster precies het hele scherm vult.
                    Rectangle {
                        z: 2
                        x: scene.offsetX + (root.area.x - root.bounds.x) * scene.mapScale - 4
                        y: scene.offsetY + (root.area.y - root.bounds.y) * scene.mapScale - 4
                        width: root.area.w * scene.mapScale + 8
                        height: root.area.h * scene.mapScale + 8
                        color: "transparent"
                        border.color: Qt.alpha(colors.primary, 0.9)
                        border.width: 2
                        radius: 12
                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: -height / 2
                            width: viewLabel.implicitWidth + 16
                            height: 18
                            radius: 9
                            color: colors.primary
                            Text {
                                id: viewLabel
                                anchors.centerIn: parent
                                text: "zicht"
                                color: colors.base
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.windows.length === 0
                        text: "Open een venster op dit werkvlak"
                        color: colors.subtext0
                        font.family: ThemeConfig.uiFont
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.errorText || "Pijltjes: kiezen  ·  Enter: terug naar venster  ·  Esc: sluiten"
                    color: root.errorText ? colors.red : colors.subtext0
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
