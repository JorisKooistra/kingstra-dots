import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    property string errorText: ""
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

    function request(raw) {
        if (!primed) { primed = true; return; }
        try {
            let d = JSON.parse(raw);
            if (String(d.token) === lastToken) return;
            lastToken = String(d.token);
            if (shown) { shown = false; return; }
            workspace = Number(d.workspace);
            selected = 0; zoom = 1; errorText = "";
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
                    text: "Sleep om vrij te bewegen. Wiel om de kaart te vergroten. Kies een venster om terug te keren."
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
                        onWheel: wheel => {
                            root.zoom = Math.max(0.2, Math.min(4, root.zoom * (wheel.angleDelta.y > 0 ? 1.12 : 1 / 1.12)));
                            wheel.accepted = true;
                        }
                    }
                    Rectangle {
                        x: scene.offsetX + (root.area.x - root.bounds.x) * scene.mapScale
                        y: scene.offsetY + (root.area.y - root.bounds.y) * scene.mapScale
                        width: root.area.w * scene.mapScale
                        height: root.area.h * scene.mapScale
                        color: Qt.alpha(colors.primary, 0.04)
                        border.color: colors.primary
                        border.width: 2
                        radius: 4
                    }
                    Repeater {
                        model: root.windows
                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            required property int index
                            x: scene.offsetX + (modelData.x - root.bounds.x) * scene.mapScale
                            y: scene.offsetY + (modelData.y - root.bounds.y) * scene.mapScale
                            width: Math.max(1, modelData.w * scene.mapScale)
                            height: Math.max(1, modelData.h * scene.mapScale)
                            radius: 6
                            color: root.selected === index ? Qt.alpha(colors.primary, 0.28) : colors.base
                            border.color: root.selected === index ? colors.primary : colors.shellOutline
                            border.width: root.selected === index ? 2 : 1
                            clip: true
                            Text {
                                anchors.fill: parent
                                anchors.margins: 10
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
                                onPressed: mouse => { let p = mapToItem(scene, mouse.x, mouse.y); root.beginDrag(p.x, p.y); root.selected = tile.index; }
                                onPositionChanged: mouse => { if (pressed) { let p = mapToItem(scene, mouse.x, mouse.y); root.drag(p.x, p.y); } }
                                onClicked: if (!root.dragged) root.choose(tile.index)
                                onWheel: wheel => {
                                    root.zoom = Math.max(0.2, Math.min(4, root.zoom * (wheel.angleDelta.y > 0 ? 1.12 : 1 / 1.12)));
                                    wheel.accepted = true;
                                }
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
