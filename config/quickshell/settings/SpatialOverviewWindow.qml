import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../overview/common/kingstra"
import "SpatialOverviewLogic.js" as MapLogic

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
    property string movingAddress: ""
    property real moveX: 0
    property real moveY: 0
    property real pointerX: 0
    property real pointerY: 0
    property bool cameraDragging: false
    property bool superHeld: false
    property bool mapReady: false
    property bool awaitingPan: false
    property real dragScale: 1
    property real anchorX: 0
    property real anchorY: 0
    property real displayX: 0
    property real displayY: 0
    property var bounds: ({x: 0, y: 0, w: 1, h: 1})
    Behavior on displayX { enabled: root.mapReady && !root.cameraDragging; NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    Behavior on displayY { enabled: root.mapReady && !root.cameraDragging; NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    ListModel { id: windowModel; dynamicRoles: true }
    property string errorText: ""
    // Nieuw bij elke keer openen, zodat bewaarde miniaturen opnieuw laden.
    property int thumbStamp: 0
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/scripts/workspace-layout.py"
    readonly property var windows: snapshot.windows || []
    readonly property var area: snapshot.area || ({x: 0, y: 0, w: 1, h: 1})
    MatugenColors { id: colors }
    // Zelfde stijlbron als het werkruimte-overzicht.
    KingstraLook { id: mapLook }
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
            mapReady = false; awaitingPan = false;
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
            let w = windows[i], x = (w.x + w.w / 2) - (source.x + source.w / 2), y = (w.y + w.h / 2) - (source.y + source.h / 2);
            if ((dx && x * dx <= 0) || (dy && y * dy <= 0)) continue;
            let distance = Math.abs(dx ? y : x) * 3 + Math.abs(x) + Math.abs(y);
            if (distance < score) { score = distance; best = i; }
        }
        if (best >= 0) selected = best;
    }
    function updateSnapshot(d) {
        let offset = MapLogic.cameraOffset(d);
        if (!mapReady) {
            anchorX = offset.x; anchorY = offset.y;
            displayX = offset.x; displayY = offset.y;
        }
        let rows = MapLogic.entries(d, anchorX, anchorY);
        let changed = MapLogic.syncWindows(windowModel, rows);
        if ((!mapReady || changed) && !cameraDragging && movingAddress === "") bounds = MapLogic.bounds(rows, d.area);
        snapshot = d;
        if (!cameraDragging && !awaitingPan) { displayX = offset.x; displayY = offset.y; }
        mapReady = true;
        selected = Math.min(selected, Math.max(0, windows.length - 1));
    }
    function sceneRows() {
        let rows = [];
        for (let i = 0; i < windowModel.count; ++i) {
            let w = windowModel.get(i).entry;
            rows.push({address:w.address,index:i,floating:w.floating,col:w.col,row:w.row,
                x:scene.offsetX + (w.x + (w.floating ? 0 : anchorX-displayX) - bounds.x) * scene.mapScale,
                y:scene.offsetY + (w.y + (w.floating ? 0 : anchorY-displayY) - bounds.y) * scene.mapScale,
                w:w.w*scene.mapScale,h:w.h*scene.mapScale});
        }
        return rows;
    }
    function hitAt(x, y) { return MapLogic.hit(sceneRows(), x, y, ""); }
    function beginMove(index, x, y) {
        movingAddress = windowModel.get(index).entry.address;
        dragX = x; dragY = y; pointerX = x; pointerY = y;
        moveX = 0; moveY = 0; dragged = false;
    }
    function move(x, y) {
        let dx=x-dragX, dy=y-dragY;
        if (!dragged && dx*dx+dy*dy < 16) return;
        dragged = true; moveX = dx; moveY = dy; pointerX=x; pointerY=y;
    }
    function cancelMove() { movingAddress=""; moveX=0; moveY=0; }
    readonly property var dropTarget: {
        // ListModel wijzigingen zijn niet automatisch een JS-bindingdependency.
        let currentSnapshot = snapshot;
        if (!movingAddress || !dragged) return null;
        let rows=sceneRows(), source=rows.find(w => w.address === movingAddress);
        if (!source) return null;
        if (source.floating) return {kind:"floating",box:{x:source.x+moveX,y:source.y+moveY,w:source.w,h:source.h}};
        let tiles=rows.filter(w => !w.floating);
        let index=MapLogic.hit(tiles,pointerX,pointerY,movingAddress);
        if (index >= 0) {
            let w=tiles[index], edge=MapLogic.placementEdge(source,w,pointerX,pointerY);
            let box={x:w.x,y:w.y,w:w.w,h:w.h};
            if (edge==="left" || edge==="right") { box.w/=2; if (edge==="right") box.x+=box.w; }
            if (edge==="up" || edge==="down") { box.h/=2; if (edge==="down") box.y+=box.h; }
            return {kind:"tile",address:w.address,edge:edge,box:box};
        }
        let pitch=snapshot.pitch || {x:area.w,y:area.h};
        let wx=(pointerX-scene.offsetX)/scene.mapScale+bounds.x+displayX;
        let wy=(pointerY-scene.offsetY)/scene.mapScale+bounds.y+displayY;
        let col=Math.round((wx-area.x-area.w/2)/pitch.x);
        let row=Math.round((wy-area.y-area.h/2)/pitch.y);
        return {kind:"page",col:col,row:row,box:{
            x:scene.offsetX+(area.x+area.w/2+col*pitch.x-displayX-(pitch.x-12)/2-bounds.x)*scene.mapScale,
            y:scene.offsetY+(area.y+area.h/2+row*pitch.y-displayY-(pitch.y-12)/2-bounds.y)*scene.mapScale,
            w:(pitch.x-12)*scene.mapScale,h:(pitch.y-12)*scene.mapScale}};
    }
    function finishMove() {
        let target=dropTarget, address=movingAddress;
        if (target && dragged && !dropProcess.running) {
            let command=["python3",helper];
            if (target.kind==="tile") command.push("tileplace",address,target.address,target.edge);
            else if (target.kind==="page") command.push("place",address,String(target.col),String(target.row));
            else {
                let row=windows.find(w => String(w.address)===address);
                command.push("movefloating",address,String(Math.round(row.x+moveX/scene.mapScale)),String(Math.round(row.y+moveY/scene.mapScale)));
            }
            dropProcess.command=command;
            dropProcess.running=true;
        }
        cancelMove();
    }
    function beginDrag(x, y) {
        dragX = x; dragY = y; dragged = false;
        dragScale = scene.mapScale;
        cameraDragging = true;
        awaitingPan = true;
    }
    function drag(x, y) {
        let dx = x - dragX, dy = y - dragY;
        if (!dragged && dx * dx + dy * dy < 9) return;
        dragged = true; dragX = x; dragY = y;
        let px = -dx / dragScale, py = -dy / dragScale;
        pendingX += px; pendingY += py;
        displayX += px; displayY += py;
    }
    function endDrag() {
        cameraDragging = false;
        settleCamera.restart();
    }
    onShownChanged: {
        overviewWindow.visible = shown;
        if (!shown) { pendingX = 0; pendingY = 0; cameraDragging = false; superHeld = false; cancelMove(); }
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
                root.updateSnapshot(d);
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
        onExited: { snapshotFile.reload(); settleCamera.restart(); }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.errorText = this.text.trim() }
    }
    Process {
        id: dropProcess
        onExited: snapshotFile.reload()
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.errorText = this.text.trim() }
    }
    Timer {
        interval: 500; repeat: true; running: root.shown
        onTriggered: Hyprland.dispatch('hl.dsp.layout("snapshot")')
    }
    Timer {
        id: settleCamera
        interval: 220
        onTriggered: {
            if (root.cameraDragging || panProcess.running || Math.abs(root.pendingX) >= 0.5 || Math.abs(root.pendingY) >= 0.5) return;
            root.awaitingPan = false;
            let offset = MapLogic.cameraOffset(root.snapshot);
            root.displayX = offset.x; root.displayY = offset.y;
        }
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
        color: mapLook.panelFill
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
            Keys.onPressed: event => {
                root.superHeld = event.key === Qt.Key_Meta || !!(event.modifiers & Qt.MetaModifier);
                event.accepted = false;
            }
            Keys.onReleased: event => {
                root.superHeld = event.key !== Qt.Key_Meta && !!(event.modifiers & Qt.MetaModifier);
                event.accepted = false;
            }
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
                // Zelfde kop als het werkruimte-overzicht.
                OverviewHeader {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width
                    look: mapLook
                    heading: "Werkvlak  ·  werkruimte " + root.workspace
                    hint: "Slepen verplaatst je zicht  ·  Super + slepen of lang indrukken verplaatst een app  ·  knijpen of wiel zoomt, tik kiest"
                }
                Rectangle {
                    id: scene
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: mapLook.raisedFill
                    radius: mapLook.panelRadius
                    clip: true
                    readonly property real mapScale: Math.max(0.001, Math.min((width - 48) / root.bounds.w, (height - 48) / root.bounds.h) * root.zoom)
                    readonly property real offsetX: (width - root.bounds.w * mapScale) / 2
                    readonly property real offsetY: (height - root.bounds.h * mapScale) / 2

                    // Eén vaste muislaag: camera en vensters delen dezelfde
                    // coördinaten; de bewegende miniaturen pakken de muis niet af.
                    SpatialMapInput {
                        id: mapInput
                        anchors.fill: parent
                        z: 10
                        controller: root
                    }
                    Repeater {
                        model: windowModel
                        delegate: Item {
                            id: tile
                            required property var entry
                            readonly property var modelData: entry
                            required property int index
                            readonly property bool moving: root.movingAddress === modelData.address
                            z: moving ? 6 : modelData.floating ? 5 : 0
                            x: scene.offsetX + (modelData.x + (modelData.floating ? 0 : root.anchorX - root.displayX) - root.bounds.x) * scene.mapScale + (moving ? root.moveX : 0)
                            y: scene.offsetY + (modelData.y + (modelData.floating ? 0 : root.anchorY - root.displayY) - root.bounds.y) * scene.mapScale + (moving ? root.moveY : 0)
                            width: Math.max(1, modelData.w * scene.mapScale)
                            height: Math.max(1, modelData.h * scene.mapScale)
                            readonly property bool chosen: root.selected === index
                            readonly property var toplevel: root.shown ? root.toplevelFor(modelData.address) : null
                            readonly property var desktopEntry: toplevel ? DesktopEntries.heuristicLookup(toplevel.appId) : null
                            scale: moving ? 0.95 : chosen ? 1.0 : 0.985
                            opacity: moving ? 0.8 : 1
                            Behavior on opacity { NumberAnimation { duration: mapLook.duration(150) } }
                            Behavior on scale { NumberAnimation { duration: mapLook.duration(160); easing.type: Easing.OutCubic } }

                            // Zelfde kaart als het werkruimte-overzicht. Buiten beeld
                            // geeft Hyprland geen live beeld: dan het laatst bewaarde
                            // plaatje (werkvlak-thumb.sh), anders het app-icoon.
                            OverviewWindowCard {
                                anchors.fill: parent
                                look: mapLook
                                captureSource: tile.toplevel
                                liveCapture: root.shown && !root.cameraDragging && !root.movingAddress
                                stillSource: root.shown ? "file://" + root.runtime + "/kingstra-thumbs/"
                                    + String(tile.modelData.address || "").toLowerCase().replace(/^0x/, "")
                                    + ".jpg?" + root.thumbStamp : ""
                                iconSource: tile.desktopEntry && tile.desktopEntry.icon
                                    ? Quickshell.iconPath(String(tile.desktopEntry.icon), "application-x-executable") : ""
                                label: String(tile.modelData.title || "Venster")
                                floatingWindow: tile.modelData.floating === true
                                chosen: tile.chosen
                                hovering: mapInput.hoverIndex === tile.index
                            }
                        }
                    }
                    Rectangle {
                        z: 7
                        readonly property var box: root.dropTarget ? root.dropTarget.box : null
                        visible: box !== null
                        x: box ? box.x : 0; y: box ? box.y : 0
                        width: box ? box.w : 0; height: box ? box.h : 0
                        radius: mapLook.cardRadius
                        color: mapLook.selectedTint
                        border.color: mapLook.primary
                        border.width: 2
                        Text {
                            anchors.centerIn: parent
                            text: root.dropTarget && root.dropTarget.edge === "center" ? "Wisselen" : ""
                            color: mapLook.text
                            font.family: mapLook.uiFont
                        }
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
                        border.color: Qt.alpha(mapLook.primary, 0.9)
                        border.width: 2
                        radius: mapLook.panelRadius
                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: -height / 2
                            width: viewLabel.implicitWidth + 16
                            height: 18
                            radius: 9
                            color: mapLook.primary
                            Text {
                                id: viewLabel
                                anchors.centerIn: parent
                                text: "zicht"
                                color: mapLook.primaryText
                                font.family: mapLook.uiFont
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.windows.length === 0
                        text: "Open een venster op dit werkvlak"
                        color: mapLook.subtext0
                        font.family: mapLook.uiFont
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: root.errorText || "Pijltjes kiezen  ·  Enter terug naar venster  ·  Esc sluit  ·  één vinger sleept, twee vingers knijpen"
                        color: root.errorText ? mapLook.red : mapLook.subtext0
                        font.family: mapLook.uiFont
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    Text {
                        text: "Sluiten"
                        color: mapLook.primary
                        font.family: mapLook.uiFont
                        font.pixelSize: 12
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.shown = false }
                    }
                }
            }
        }
    }
}
