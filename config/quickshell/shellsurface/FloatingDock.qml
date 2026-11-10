import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

// Dock op zwevende werkruimtes (indeling "Zwevend met dock", Super+Z):
// onderaan een afgeronde strook met de vastgezette apps uit de launcher,
// de open vensters van deze werkruimte en een knop naar alle apps. De rail
// blijft gewoon staan; op andere werkruimtes is het dock er niet.
Item {
    id: root

    required property var shellWindow
    required property var mocha
    property int bottomInset: 0
    // Aan zolang een paneel uit de onderrand groeit (launcher, menu…).
    property bool suppressed: false

    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"
    readonly property var monitor: shellWindow && shellWindow.screen ? Hyprland.monitorFor(shellWindow.screen) : null
    readonly property var workspace: monitor ? monitor.activeWorkspace : null
    readonly property string workspaceId: workspace ? String(workspace.id) : ""
    property var layouts: ({})
    property var pins: []
    readonly property bool active: workspaceId !== "" && layouts[workspaceId] === "zwevend"
    readonly property bool shown: active && !suppressed
    readonly property var windows: workspace ? workspace.toplevels.values : []

    readonly property int cell: 44
    // Klikbaar stuk voor de input-mask van ShellSurface; 0×0 zonder dock,
    // zodat de onderkant van het scherm dan gewoon doorklikbaar blijft.
    readonly property Item hitItem: hit
    Item {
        id: hit
        width: root.shown ? root.width : 0
        height: root.shown ? root.height : 0
    }
    width: row.implicitWidth + 20
    height: cell + 16
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: bottomInset + 14
    z: 34
    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }
    transform: Translate {
        y: root.shown ? 0 : 18
        Behavior on y { NumberAnimation { duration: ThemeConfig.durationToken("medium"); easing.type: ThemeConfig.easingToken("emphasized") } }
    }

    function iconFor(name) {
        let raw = String(name || "").replace(/\.desktop$/i, "");
        if (raw === "") return "";
        let lower = raw.toLowerCase();
        let entry = DesktopEntries.byId(raw) || DesktopEntries.byId(lower) || DesktopEntries.heuristicLookup(raw);
        return entry && entry.icon ? String(entry.icon) : lower;
    }
    function windowClass(toplevel) {
        let ipc = toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : {};
        let cls = String(ipc.initialClass || ipc.class || "");
        if (cls === "" && toplevel && toplevel.wayland) cls = String(toplevel.wayland.appId || "");
        return cls;
    }
    function focusWindow(toplevel) {
        if (!toplevel) return;
        Quickshell.execDetached(["bash", scripts + "/hypr-dispatch.sh", "focuswindow", "address:0x" + toplevel.address]);
    }

    FileView {
        id: layoutFile
        path: Quickshell.env("HOME") + "/.local/state/kingstra/workspace-layouts.json"
        printErrors: false
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onLoaded: {
            try { root.layouts = JSON.parse(text() || "{}"); } catch (e) {}
        }
        onLoadFailed: root.layouts = ({})
    }
    FileView {
        id: pinFile
        path: Quickshell.env("HOME") + "/.cache/kingstra/launcher-state.json"
        printErrors: false
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let data = JSON.parse(text() || "{}");
                root.pins = Array.isArray(data.pins) ? data.pins.slice(0, 8) : [];
            } catch (e) {}
        }
    }
    // FileView mist soms een schrijfactie; rustig nalezen is genoeg.
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: layoutFile.reload()
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(height / 2, Math.max(14, ThemeConfig.styleWidgetRadius + 6))
        color: Qt.rgba(root.mocha.base.r, root.mocha.base.g, root.mocha.base.b, 0.86)
        border.width: 1
        border.color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.10)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        // Vastgezette apps uit de launcher.
        Repeater {
            model: root.pins
            delegate: DockButton {
                required property var modelData
                readonly property var entry: DesktopEntries.byId(String(modelData))
                visible: entry !== null
                iconName: entry ? String(entry.icon || "") : ""
                fallback: entry ? String(entry.name || "?") : "?"
                tip: entry ? String(entry.name || "") : ""
                onClicked: if (entry) entry.execute()
            }
        }

        Rectangle {
            visible: root.pins.length > 0 && root.windows.length > 0
            Layout.preferredWidth: 1
            Layout.preferredHeight: root.cell - 16
            color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.16)
        }

        // Open vensters op deze werkruimte; de actieve krijgt een stip.
        Repeater {
            model: root.windows
            delegate: DockButton {
                required property var modelData
                iconName: root.iconFor(root.windowClass(modelData))
                fallback: root.windowClass(modelData) || "?"
                tip: String(modelData.title || root.windowClass(modelData))
                running: true
                focused: modelData.activated === true
                onClicked: root.focusWindow(modelData)
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: root.cell - 16
            color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.16)
        }

        // Alle apps.
        DockButton {
            glyph: "󰀻"
            tip: "Alle apps"
            onClicked: Quickshell.execDetached(["bash", root.scripts + "/qs_manager.sh", "toggle", "launcher"])
        }
    }

    component DockButton: Item {
        id: button
        property string iconName: ""
        property string fallback: ""
        property string glyph: ""
        property string tip: ""
        property bool running: false
        property bool focused: false
        signal clicked()
        Layout.preferredWidth: root.cell
        Layout.preferredHeight: root.cell

        Rectangle {
            anchors.fill: parent
            radius: Math.min(14, root.cell / 2)
            color: mouse.containsMouse
                ? Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.12)
                : "transparent"
            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        }
        Image {
            id: img
            anchors.centerIn: parent
            width: 30
            height: 30
            sourceSize: Qt.size(60, 60)
            visible: button.glyph === "" && status === Image.Ready
            source: button.glyph === "" && button.iconName !== "" ? Quickshell.iconPath(button.iconName, true) : ""
            scale: mouse.pressed ? 0.9 : (mouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: Easing.OutCubic } }
        }
        Text {
            anchors.centerIn: parent
            visible: button.glyph !== "" || img.status !== Image.Ready
            text: button.glyph !== "" ? button.glyph : String(button.fallback).charAt(0).toUpperCase()
            font.family: button.glyph !== "" ? ThemeConfig.iconFont : ThemeConfig.displayFont
            font.pixelSize: button.glyph !== "" ? 20 : 18
            font.weight: Font.Black
            color: root.mocha.text
        }
        Rectangle {
            visible: button.running
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: button.focused ? 14 : 5
            height: 4
            radius: 2
            color: button.focused ? root.mocha.primary : Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.5)
            Behavior on width { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
