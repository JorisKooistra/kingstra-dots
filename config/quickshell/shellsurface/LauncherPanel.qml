import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

// App-launcher die vanaf de onderkant van het scherm uitgroeit, in dezelfde
// chrome-taal als de bar. De desktop-entries komen uit list-apps.py; de
// Quickshell DesktopEntries-API levert op dit systeem geen resultaten.
Item {
    id: root

    MatugenColors { id: mocha }

    property var allApps: []
    property string query: ""
    property int selectedIndex: 0

    readonly property color surfaceColor: {
        let f = mocha.crust;
        let a = mocha.primary;
        return Qt.rgba(f.r + (a.r - f.r) * 0.18,
                       f.g + (a.g - f.g) * 0.18,
                       f.b + (a.b - f.b) * 0.18,
                       1.0);
    }
    readonly property color rowHover: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.16)
    readonly property color rowActive: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.28)

    readonly property var filtered: {
        let q = query.trim().toLowerCase();
        if (q === "") return allApps;
        let starts = [], contains = [];
        for (let i = 0; i < allApps.length; i++) {
            let a = allApps[i];
            let n = String(a.name || "").toLowerCase();
            if (n.indexOf(q) === 0) starts.push(a);
            else if (n.indexOf(q) !== -1 || String(a.comment || "").toLowerCase().indexOf(q) !== -1) contains.push(a);
        }
        return starts.concat(contains);
    }

    onFilteredChanged: selectedIndex = 0

    Process {
        id: scanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/shellsurface/list-apps.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.allApps = JSON.parse(this.text);
                } catch (e) {
                    root.allApps = [];
                }
            }
        }
    }

    function closePanel() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    function launch(app) {
        if (!app) return;
        let cmd = app.terminal ? ("kitty -e " + app.exec) : app.exec;
        Quickshell.execDetached(["bash", "-lc", "setsid " + cmd + " >/dev/null 2>&1 &"]);
        closePanel();
    }

    function move(delta) {
        let n = filtered.length;
        if (n === 0) return;
        selectedIndex = (selectedIndex + delta + n) % n;
        appList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    Keys.onEscapePressed: event => {
        root.closePanel();
        event.accepted = true;
    }
    Keys.onDownPressed: event => { root.move(1); event.accepted = true; }
    Keys.onUpPressed: event => { root.move(-1); event.accepted = true; }
    Keys.onReturnPressed: event => { root.launch(root.filtered[root.selectedIndex]); event.accepted = true; }
    Keys.onEnterPressed: event => { root.launch(root.filtered[root.selectedIndex]); event.accepted = true; }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // --- Zoekveld --------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: Math.max(10, ThemeConfig.styleWidgetRadius + 6)
            color: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.10)
            border.width: 1
            border.color: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.35)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                Text {
                    text: "󱒟"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 16
                    color: mocha.primary
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    focus: true
                    color: mocha.text
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 15
                    selectByMouse: true
                    selectionColor: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.35)
                    onTextChanged: root.query = text
                    Component.onCompleted: forceActiveFocus()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Zoek een app…"
                        font: searchInput.font
                        color: mocha.subtext0
                    }
                }

                Text {
                    text: root.filtered.length + ""
                    font.family: ThemeConfig.monoFont
                    font.pixelSize: 12
                    color: mocha.subtext0
                }
            }
        }

        // --- Resultaten ------------------------------------------------------
        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filtered
            spacing: 2
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property int index
                required property var modelData
                readonly property bool current: index === root.selectedIndex

                width: appList.width
                height: 46
                radius: Math.max(8, ThemeConfig.styleWidgetRadius + 4)
                color: current ? root.rowActive : (rowMouse.containsMouse ? root.rowHover : "transparent")

                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                            visible: status === Image.Ready
                            sourceSize.width: 26
                            sourceSize.height: 26
                            smooth: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready
                            text: "󰄋"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 17
                            color: mocha.primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 14
                            font.weight: row.current ? Font.Bold : Font.DemiBold
                            color: mocha.text
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: String(row.modelData.comment || "") !== ""
                            text: row.modelData.comment
                            elide: Text.ElideRight
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 11
                            color: mocha.subtext0
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selectedIndex = row.index
                    onClicked: root.launch(row.modelData)
                }
            }
        }
    }
}
