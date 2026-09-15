import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

FocusScope {
    id: root

    MatugenColors { id: mocha }

    property var entries: []
    property string query: ""
    property int selectedIndex: 0
    readonly property string bridge: Quickshell.env("HOME") + "/.config/quickshell/shellsurface/clipboard-panel.sh"
    readonly property var filteredEntries: {
        let needle = String(query || "").toLowerCase().trim();
        if (needle === "") return entries;
        return entries.filter(entry => root.previewFor(entry).toLowerCase().indexOf(needle) >= 0);
    }

    function previewFor(entry) {
        let value = String(entry || "").replace(/^\d+\t/, "").trim();
        if (value.indexOf("[[ binary data") === 0) {
            let size = value.match(/\[\[ binary data (.+) \]\]/);
            return size ? "Afbeelding · " + size[1] : "Afbeelding";
        }
        return value.replace(/\s+/g, " ");
    }

    function isImage(entry) {
        return String(entry || "").indexOf("[[ binary data") >= 0;
    }

    function refresh() {
        if (!loadProcess.running) loadProcess.running = true;
    }

    function copyEntry(entry) {
        if (!entry || copyProcess.running) return;
        copyProcess.command = ["bash", bridge, "copy", String(entry)];
        copyProcess.running = true;
    }

    function closePanel() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    onFilteredEntriesChanged: selectedIndex = 0
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
                    root.entries = Array.isArray(parsed) ? parsed : [];
                } catch (error) {
                    root.entries = [];
                }
            }
        }
    }

    Process {
        id: copyProcess
        command: ["bash", "-lc", "true"]
        onExited: (exitCode) => {
            if (exitCode === 0) root.closePanel();
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Keys.onEscapePressed: event => { root.closePanel(); event.accepted = true; }
    Keys.onDownPressed: event => {
        if (root.filteredEntries.length > 0)
            root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredEntries.length - 1);
        event.accepted = true;
    }
    Keys.onUpPressed: event => {
        if (root.filteredEntries.length > 0)
            root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
        event.accepted = true;
    }
    Keys.onReturnPressed: event => { root.copyEntry(root.filteredEntries[root.selectedIndex]); event.accepted = true; }
    Keys.onEnterPressed: event => { root.copyEntry(root.filteredEntries[root.selectedIndex]); event.accepted = true; }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 11
                color: Qt.rgba(mocha.accent1.r, mocha.accent1.g, mocha.accent1.b, 0.18)
                Text { anchors.centerIn: parent; text: "󰄀"; font.family: "Iosevka Nerd Font"; font.pixelSize: 17; color: mocha.accent1 }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { text: "Klembord"; font.family: ThemeConfig.displayFont; font.pixelSize: 18; font.weight: Font.Black; color: mocha.text }
                Text { text: root.entries.length + " recent · klik om te kopiëren"; font.family: ThemeConfig.uiFont; font.pixelSize: 10; color: mocha.subtext0 }
            }
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 10
                color: refreshMouse.containsMouse ? Qt.rgba(mocha.accent1.r, mocha.accent1.g, mocha.accent1.b, 0.16) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.72)
                Text { anchors.centerIn: parent; text: "󰑓"; font.family: "Iosevka Nerd Font"; font.pixelSize: 15; color: mocha.accent1 }
                MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 12
            color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.72)
            border.width: 1
            border.color: searchInput.activeFocus ? Qt.rgba(mocha.accent1.r, mocha.accent1.g, mocha.accent1.b, 0.62) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                Text { text: "󰍉"; font.family: "Iosevka Nerd Font"; font.pixelSize: 15; color: mocha.accent1 }
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: mocha.text; font.family: ThemeConfig.uiFont; font.pixelSize: 13; selectByMouse: true
                    selectionColor: Qt.rgba(mocha.accent1.r, mocha.accent1.g, mocha.accent1.b, 0.34)
                    onTextChanged: root.query = text
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: searchInput.text === ""; text: "Zoek in je recente klembord…"; font: searchInput.font; color: mocha.subtext0 }
                }
            }
        }

        ListView {
            id: entryList
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 7; model: root.filteredEntries
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: Rectangle {
                id: entryRow
                required property var modelData
                required property int index
                readonly property bool current: root.selectedIndex === index
                readonly property bool image: root.isImage(modelData)
                width: entryList.width; height: Math.max(48, previewText.implicitHeight + 22); radius: 13
                color: current || entryMouse.containsMouse ? Qt.rgba(mocha.accent1.r, mocha.accent1.g, mocha.accent1.b, current ? 0.18 : 0.12) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.68)
                border.width: 1
                border.color: current ? Qt.rgba(mocha.accent1.r, mocha.accent1.g, mocha.accent1.b, 0.48) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                    Text { text: entryRow.image ? "󰋩" : "󰆏"; font.family: "Iosevka Nerd Font"; font.pixelSize: 16; color: entryRow.image ? mocha.accent2 : mocha.accent1 }
                    Text {
                        id: previewText
                        Layout.fillWidth: true
                        text: root.previewFor(entryRow.modelData)
                        font.family: ThemeConfig.uiFont; font.pixelSize: 12; color: mocha.text
                        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                    }
                    Text { text: "󰅂"; font.family: "Iosevka Nerd Font"; font.pixelSize: 13; color: current ? mocha.accent1 : mocha.subtext0 }
                }
                MouseArea {
                    id: entryMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = entryRow.index
                    onClicked: root.copyEntry(entryRow.modelData)
                }
            }
            Text {
                anchors.centerIn: parent; visible: entryList.count === 0
                text: root.entries.length === 0 ? "Nog geen klembordgeschiedenis" : "Geen resultaten"
                font.family: ThemeConfig.uiFont; font.pixelSize: 12; color: mocha.subtext0
            }
        }

        Text {
            Layout.fillWidth: true; text: "↑↓ kiezen · Enter kopiëren · Esc sluiten"
            font.family: ThemeConfig.monoFont; font.pixelSize: 10; color: mocha.subtext0
            horizontalAlignment: Text.AlignRight
        }
    }
}
