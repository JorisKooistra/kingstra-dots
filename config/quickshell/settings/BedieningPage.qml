import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    signal pageRequested(string page)
    property string selectedName: ""
    property string currentLayout: ""
    property string layoutError: ""
    readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/scripts/workspace-layout.py"
    readonly property var monitor: {
        let list = ScreenProfiles.monitors;
        for (let m of list) if (m.name === selectedName) return m;
        for (let m of list) if (m.focused) return m;
        return list.length ? list[0] : null;
    }
    readonly property string screenName: monitor ? monitor.name : ""
    readonly property var profile: ScreenProfiles.profile(screenName)
    readonly property int workspace: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0
    readonly property var modeData: ScreenProfiles.state.presets[profile.mode] || ({})
    readonly property var modules: profile.rail.modules !== undefined ? profile.rail.modules : (modeData.modules || [])
    readonly property var pins: profile.rail.pins !== undefined ? profile.rail.pins : RailPins.pins
    readonly property bool autohide: profile.rail.autohide !== undefined ? profile.rail.autohide : modeData.bar_autohide === true
    MatugenColors { id: palette }

    function set(field, value) {
        if (!screenName) return;
        ScreenProfiles.action(["set", screenName, field, JSON.stringify(value)]);
    }
    function toggleModule(id) {
        let next = modules.slice(), index = next.indexOf(id);
        if (index >= 0) next.splice(index, 1); else next.push(id);
        set("rail.modules", next);
    }
    function movePin(index, delta) {
        let next = pins.slice(), target = index + delta;
        if (target < 0 || target >= next.length) return;
        let value = next.splice(index, 1)[0];
        next.splice(target, 0, value);
        set("rail.pins", next);
    }
    function inspect() {
        if (!workspace || layoutProcess.running) return;
        layoutProcess.command = ["python3", helper, "inspect", String(workspace)];
        layoutProcess.running = true;
    }
    function applyLayout(preset) {
        if (!workspace || layoutProcess.running) return;
        layoutError = "";
        layoutProcess.command = ["python3", helper, "apply", preset, String(workspace)];
        layoutProcess.running = true;
    }
    onWorkspaceChanged: inspect()
    Component.onCompleted: inspect()
    Timer { interval: 2000; repeat: true; running: root.visible; onTriggered: root.inspect() }
    Process {
        id: layoutProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.currentLayout = JSON.parse(this.text).preset || ""; root.layoutError = ""; }
                catch (e) {}
            }
        }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.layoutError = this.text.trim() }
    }

    component Action: Rectangle {
        id: button
        property string label: ""
        property bool chosen: false
        property bool allowed: true
        signal triggered()
        implicitHeight: 34
        implicitWidth: caption.implicitWidth + 24
        radius: 8
        opacity: allowed ? 1 : 0.45
        color: chosen ? Qt.alpha(palette.primary, 0.2) : mouse.containsMouse ? palette.shellHoverFill : palette.shellRaisedFill
        border.width: 1
        border.color: chosen ? palette.primary : palette.shellOutline
        Text {
            id: caption
            anchors.centerIn: parent
            text: button.label
            color: palette.text
            font.family: ThemeConfig.uiFont
            font.pixelSize: 12
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.allowed
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
    component Heading: Text {
        color: palette.text
        font.family: ThemeConfig.uiFont
        font.pixelSize: 16
        font.bold: true
    }
    component Hint: Text {
        color: palette.subtext0
        font.family: ThemeConfig.uiFont
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 22
        contentHeight: body.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: body
            width: parent.width
            spacing: 16
            Heading { text: "Bediening"; font.pixelSize: 24 }
            Hint { text: "Kies een scherm. Mode, rail en muziek worden voor dat scherm bewaard."; Layout.fillWidth: true }

            Item {
                id: screenMap
                Layout.fillWidth: true
                Layout.preferredHeight: 148
                readonly property var box: {
                    let list = ScreenProfiles.monitors;
                    let x = 0, y = 0, right = 1, bottom = 1;
                    for (let m of list) {
                        let scale = Number(m.scale) || 1;
                        x = Math.min(x, m.x); y = Math.min(y, m.y);
                        right = Math.max(right, m.x + m.width / scale);
                        bottom = Math.max(bottom, m.y + m.height / scale);
                    }
                    return {x: x, y: y, w: right - x, h: bottom - y};
                }
                readonly property real ratio: Math.min(width / box.w, height / box.h)
                Repeater {
                    model: ScreenProfiles.monitors
                    delegate: Rectangle {
                        id: display
                        required property var modelData
                        x: (modelData.x - screenMap.box.x) * screenMap.ratio + 3
                        y: (modelData.y - screenMap.box.y) * screenMap.ratio + 3
                        width: Math.max(20, modelData.width / (modelData.scale || 1) * screenMap.ratio - 6)
                        height: Math.max(20, modelData.height / (modelData.scale || 1) * screenMap.ratio - 6)
                        radius: 8
                        color: modelData.name === root.screenName ? Qt.alpha(palette.primary, 0.2) : palette.shellRaisedFill
                        border.color: modelData.name === root.screenName ? palette.primary : palette.shellOutline
                        border.width: 2
                        clip: true
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 12
                            horizontalAlignment: Text.AlignHCenter
                            text: display.modelData.name + "\n" + ScreenProfiles.profile(display.modelData.name).mode
                            color: palette.text
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedName = display.modelData.name }
                    }
                }
            }
            Heading { text: root.screenName ? "Dit scherm  ·  " + root.screenName : "Geen schermgegevens" }
            Hint { text: root.monitor ? String(root.monitor.description || root.monitor.name) : ScreenProfiles.errorText; Layout.fillWidth: true }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [{id: "inherit", title: "Volg standaard"}, {id: "office", title: "Office"}, {id: "media", title: "Media"}, {id: "gaming", title: "Gaming"}]
                    delegate: Action {
                        required property var modelData
                        label: modelData.title
                        chosen: modelData.id === "inherit" ? root.profile.inherited : !root.profile.inherited && root.profile.mode === modelData.id
                        allowed: !!root.screenName && !ScreenProfiles.busy
                        onTriggered: ScreenProfiles.action(["mode", root.screenName, modelData.id])
                    }
                }
            }

            Heading { text: "Werkruimte " + root.workspace + " op dit scherm" }
            Hint { text: "Indeling geldt voor deze werkruimte. Ruimtelijk laat vensters boven, onder en naast elkaar staan."; Layout.fillWidth: true }
            Flow {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: [{id: "tegels", title: "Tegelen"}, {id: "ruimtelijk", title: "Ruimtelijk werkvlak"}, {id: "scrollen", title: "Scrollstrook"}, {id: "50-50", title: "50 / 50"}, {id: "70-30", title: "70 / 30"}, {id: "focus", title: "Eén tegelijk"}]
                    delegate: Action {
                        required property var modelData
                        label: modelData.title
                        chosen: root.currentLayout === modelData.id
                        allowed: root.workspace > 0 && !layoutProcess.running
                        onTriggered: root.applyLayout(modelData.id)
                    }
                }
                Action {
                    label: "Open overzicht"
                    allowed: root.workspace > 0
                    onTriggered: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/overview-toggle.sh"])
                }
            }
            Hint { text: root.layoutError; visible: text !== ""; color: palette.red; Layout.fillWidth: true }

            Heading { text: "Rail  ·  " + root.profile.mode }
            Flow {
                Layout.fillWidth: true; spacing: 8
                Action { label: root.autohide ? "Automatisch verbergen: aan" : "Automatisch verbergen: uit"; chosen: root.autohide; allowed: !ScreenProfiles.busy; onTriggered: root.set("rail.autohide", !root.autohide) }
                Action { label: "Herstel keuzes voor deze mode"; allowed: !ScreenProfiles.busy; onTriggered: ScreenProfiles.action(["reset", root.screenName]) }
            }
            Hint { text: "Zichtbare onderdelen"; Layout.fillWidth: true }
            Flow {
                Layout.fillWidth: true; spacing: 7
                Repeater {
                    model: [{id: "workspaces", title: "Werkruimtes"}, {id: "clock", title: "Klok"}, {id: "updates", title: "Updates"}, {id: "cpu_temp", title: "Systeem"}, {id: "network", title: "Netwerk"}, {id: "battery", title: "Batterij"}, {id: "volume", title: "Geluid"}, {id: "bluetooth", title: "Bluetooth"}, {id: "notifications", title: "Meldingen"}, {id: "media_controls", title: "Media"}]
                    delegate: Action {
                        required property var modelData
                        label: modelData.title
                        chosen: root.modules.indexOf(modelData.id) >= 0
                        allowed: !ScreenProfiles.busy
                        onTriggered: root.toggleModule(modelData.id)
                    }
                }
            }
            Hint { text: "Extra railknoppen"; Layout.fillWidth: true }
            Flow {
                Layout.fillWidth: true; spacing: 7
                Repeater {
                    model: ["wifi", "bt", "dnd", "power", "media"]
                    delegate: Action {
                        required property string modelData
                        label: ({wifi: "Wi-Fi", bt: "Bluetooth", dnd: "Niet storen", power: "Energie", media: "Speler"})[modelData]
                        chosen: root.pins.indexOf(modelData) >= 0
                        allowed: !ScreenProfiles.busy
                        onTriggered: ScreenProfiles.togglePin(root.screenName, modelData, root.pins)
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: root.pins
                    delegate: RowLayout {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        Hint { text: modelData; Layout.fillWidth: true }
                        Action { label: "Omhoog"; allowed: index > 0 && !ScreenProfiles.busy; onTriggered: root.movePin(index, -1) }
                        Action { label: "Omlaag"; allowed: index < root.pins.length - 1 && !ScreenProfiles.busy; onTriggered: root.movePin(index, 1) }
                    }
                }
            }

            Heading { text: "Muziek op dit scherm" }
            Flow {
                Layout.fillWidth: true; spacing: 8
                Action { label: "Gebruik als vast mediascherm"; allowed: !ScreenProfiles.busy; onTriggered: ScreenProfiles.action(["anchor", root.screenName]) }
                Action { label: root.profile.desktopMedia ? "Desktopspeler: aan" : "Desktopspeler: uit"; chosen: root.profile.desktopMedia; allowed: !ScreenProfiles.busy; onTriggered: root.set("desktopMedia", !root.profile.desktopMedia) }
                Repeater {
                    model: [{id: "auto", title: "Pill: automatisch"}, {id: "show", title: "Pill: tonen"}, {id: "hide", title: "Pill: verbergen"}]
                    delegate: Action {
                        required property var modelData
                        label: modelData.title
                        chosen: root.profile.nowPlaying === modelData.id
                        allowed: !ScreenProfiles.busy
                        onTriggered: root.set("nowPlaying", modelData.id)
                    }
                }
            }
            Heading { text: "Hele desktop" }
            Hint { text: "Thema, energieprofiel en Niet storen zijn gedeeld tussen je schermen."; Layout.fillWidth: true }
            Flow {
                Layout.fillWidth: true; spacing: 8
                Action { label: "Thema"; onTriggered: root.pageRequested("thema") }
                Action { label: "Wallpaper"; onTriggered: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-picker-safe.sh"]) }
                Action { label: "Sneltoetsen"; onTriggered: root.pageRequested("sneltoetsen") }
                Action { label: "Beeldschermen"; onTriggered: root.pageRequested("beeldschermen") }
            }
            Hint { text: ScreenProfiles.errorText; visible: text !== ""; color: palette.red; Layout.fillWidth: true }
        }
    }
}
