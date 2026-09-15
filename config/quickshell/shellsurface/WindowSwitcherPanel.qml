import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

FocusScope {
    id: root

    MatugenColors { id: mocha }

    property var windows: []
    property string query: ""
    property int selectedIndex: 0
    readonly property string bridge: Quickshell.env("HOME") + "/.config/quickshell/shellsurface/window-switcher.sh"
    readonly property var filteredWindows: {
        let needle = String(query || "").toLowerCase().trim();
        if (needle === "") return windows;
        return windows.filter(win => (String(win.title || "") + " " + String(win.className || "") + " " + String(win.workspace || "")).toLowerCase().indexOf(needle) >= 0);
    }

    function refresh() {
        if (!loadProcess.running) loadProcess.running = true;
    }

    function focusWindow(win) {
        if (!win || focusProcess.running) return;
        focusProcess.command = ["bash", bridge, "focus", String(win.address), String(win.workspace)];
        focusProcess.running = true;
    }

    function closePanel() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    function initialFor(name) {
        let clean = String(name || "?").trim();
        return clean.length > 0 ? clean.charAt(0).toUpperCase() : "?";
    }

    onFilteredWindowsChanged: selectedIndex = 0
    Component.onCompleted: {
        refresh();
        searchInput.forceActiveFocus();
    }

    Process {
        id: loadProcess
        command: ["bash", root.bridge, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(this.text);
                    root.windows = Array.isArray(parsed) ? parsed : [];
                } catch (error) {
                    root.windows = [];
                }
            }
        }
    }

    Process {
        id: focusProcess
        command: ["bash", "-lc", "true"]
        onExited: (exitCode) => {
            if (exitCode === 0) root.closePanel();
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Keys.onEscapePressed: event => { root.closePanel(); event.accepted = true; }
    Keys.onDownPressed: event => {
        if (root.filteredWindows.length > 0)
            root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredWindows.length - 1);
        windowList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        event.accepted = true;
    }
    Keys.onUpPressed: event => {
        if (root.filteredWindows.length > 0)
            root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
        windowList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        event.accepted = true;
    }
    Keys.onReturnPressed: event => { root.focusWindow(root.filteredWindows[root.selectedIndex]); event.accepted = true; }
    Keys.onEnterPressed: event => { root.focusWindow(root.filteredWindows[root.selectedIndex]); event.accepted = true; }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 11
                color: Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.18)
                Text { anchors.centerIn: parent; text: "󰖯"; font.family: "Iosevka Nerd Font"; font.pixelSize: 17; color: mocha.accent2 }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { text: "Vensters"; font.family: ThemeConfig.displayFont; font.pixelSize: 18; font.weight: Font.Black; color: mocha.text }
                Text { text: root.windows.length + " open · spring direct naar een app"; font.family: ThemeConfig.uiFont; font.pixelSize: 10; color: mocha.subtext0 }
            }
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 10
                color: refreshMouse.containsMouse ? Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.16) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.72)
                Text { anchors.centerIn: parent; text: "󰑓"; font.family: "Iosevka Nerd Font"; font.pixelSize: 15; color: mocha.accent2 }
                MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 12
            color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.72)
            border.width: 1
            border.color: searchInput.activeFocus ? Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.62) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                Text { text: "󰍉"; font.family: "Iosevka Nerd Font"; font.pixelSize: 15; color: mocha.accent2 }
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: mocha.text; font.family: ThemeConfig.uiFont; font.pixelSize: 13; selectByMouse: true
                    selectionColor: Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.34)
                    onTextChanged: root.query = text
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: searchInput.text === ""; text: "Zoek vensters, apps of workspaces…"; font: searchInput.font; color: mocha.subtext0 }
                }
            }
        }

        ListView {
            id: windowList
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 7; model: root.filteredWindows
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: Rectangle {
                id: windowRow
                required property var modelData
                required property int index
                readonly property bool current: root.selectedIndex === index
                width: windowList.width; height: 58; radius: 13
                color: current || windowMouse.containsMouse ? Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, current ? 0.18 : 0.12) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.68)
                border.width: 1
                border.color: current ? Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.48) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
                        color: Qt.rgba(mocha.accent1.r, mocha.accent1.g, mocha.accent1.b, 0.16)
                        Text { anchors.centerIn: parent; text: root.initialFor(windowRow.modelData.className); font.family: ThemeConfig.monoFont; font.pixelSize: 12; font.weight: Font.Black; color: mocha.accent1 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { Layout.fillWidth: true; text: String(windowRow.modelData.title || "Zonder titel"); font.family: ThemeConfig.uiFont; font.pixelSize: 12; font.weight: Font.DemiBold; color: mocha.text; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: String(windowRow.modelData.className || "App") + " · workspace " + String(windowRow.modelData.workspace); font.family: ThemeConfig.uiFont; font.pixelSize: 10; color: mocha.subtext0; elide: Text.ElideRight }
                    }
                    Rectangle {
                        visible: Boolean(windowRow.modelData.focused)
                        Layout.preferredWidth: 7; Layout.preferredHeight: 7; radius: 4
                        color: mocha.accent2
                    }
                    Text { text: "󰅂"; font.family: "Iosevka Nerd Font"; font.pixelSize: 13; color: current ? mocha.accent2 : mocha.subtext0 }
                }
                MouseArea {
                    id: windowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = windowRow.index
                    onClicked: root.focusWindow(windowRow.modelData)
                }
            }
            Text {
                anchors.centerIn: parent; visible: windowList.count === 0
                text: root.windows.length === 0 ? "Geen open vensters" : "Geen resultaten"
                font.family: ThemeConfig.uiFont; font.pixelSize: 12; color: mocha.subtext0
            }
        }

        Text {
            Layout.fillWidth: true; text: "↑↓ kiezen · Enter wisselen · Esc sluiten"
            font.family: ThemeConfig.monoFont; font.pixelSize: 10; color: mocha.subtext0
            horizontalAlignment: Text.AlignRight
        }
    }
}
