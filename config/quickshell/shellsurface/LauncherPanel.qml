import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

// App-launcher die vanaf de onderkant van het scherm uitgroeit, in dezelfde
// chrome-taal als de bar. De desktop-entries komen uit list-apps.py; de
// Quickshell DesktopEntries-API levert op dit systeem geen resultaten.
//
// FocusScope, geen Item: het paneel wordt via een Loader in de PanelHost
// geladen en een Loader geeft toetsenbordfocus niet vanzelf door aan zijn
// inhoud. Daardoor bleef de focus op de PanelHost hangen — Escape kwam wel
// aan, maar getypte tekens bereikten het zoekveld nooit. Als scope kan de
// host hier focus aan geven, die dan bij searchInput (focus: true) landt.
FocusScope {
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
    readonly property int panelCornerRadius: Math.max(18, ThemeConfig.styleWidgetRadius + 8)
    readonly property int controlCornerRadius: Math.max(12, Math.round(panelCornerRadius * 0.62))
    readonly property int rowCornerRadius: Math.max(12, Math.round(panelCornerRadius * 0.56))

    readonly property var filtered: {
        let q = root.normalizeSearch(query);
        if (q === "") return allApps;
        let scored = [];
        for (let i = 0; i < allApps.length; i++) {
            let a = allApps[i];
            let score = root.appScore(a, q);
            if (score > 0) scored.push({ app: a, score: score });
        }
        scored.sort((a, b) => {
            if (a.score !== b.score) return b.score - a.score;
            return String(a.app.name || "").length - String(b.app.name || "").length;
        });
        return scored.map(r => r.app);
    }

    onFilteredChanged: selectedIndex = 0

    function normalizeSearch(value) {
        return String(value || "")
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, " ")
            .trim()
            .replace(/\s+/g, " ");
    }

    function initials(value) {
        let text = normalizeSearch(value);
        if (text === "") return "";
        return text.split(" ").map(w => w.charAt(0)).join("");
    }

    function wordStartsWith(value, q) {
        let words = normalizeSearch(value).split(" ");
        for (let i = 0; i < words.length; i++) {
            if (words[i].indexOf(q) === 0) return true;
        }
        return false;
    }

    function subsequenceScore(value, q, base) {
        let text = normalizeSearch(value);
        if (text === "" || q === "") return 0;
        let qi = 0;
        let first = -1;
        let last = -1;
        let bonus = 0;
        let consecutive = 0;
        for (let i = 0; i < text.length && qi < q.length; i++) {
            if (text.charAt(i) !== q.charAt(qi)) continue;
            if (first < 0) first = i;
            if (i === 0 || text.charAt(i - 1) === " ") bonus += 80;
            if (last >= 0 && i === last + 1) {
                consecutive += 1;
                bonus += 16;
            }
            last = i;
            qi += 1;
        }
        if (qi !== q.length) return 0;
        let span = Math.max(1, last - first + 1);
        return base + bonus + consecutive * 8 - first * 10 - span * 5 - text.length;
    }

    function fieldScore(value, q, base) {
        let text = normalizeSearch(value);
        if (text === "") return 0;
        let acro = initials(text);
        if (text === q) return base + 5000;
        if (text.indexOf(q) === 0) return base + 4200 - text.length;
        if (wordStartsWith(text, q)) return base + 3600 - text.length;
        if (acro === q) return base + 3900 - text.length;
        if (acro.indexOf(q) === 0) return base + 3400 - text.length;
        if (text.indexOf(q) !== -1) return base + 2500 - text.indexOf(q) * 4 - text.length;
        return subsequenceScore(text, q, base + 1200);
    }

    function appScore(app, q) {
        return Math.max(
            fieldScore(app.name, q, 5000),
            fieldScore(app.genericName, q, 3600),
            fieldScore(app.startupClass, q, 3400),
            fieldScore(app.id, q, 3300),
            fieldScore(app.execString || app.exec, q, 3200),
            fieldScore(app.keywords, q, 2600),
            fieldScore(app.comment, q, 2200),
            fieldScore(app.categories, q, 1400)
        );
    }

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
            radius: root.controlCornerRadius
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
                radius: root.rowCornerRadius
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
