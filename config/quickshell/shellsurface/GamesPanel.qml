import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import ".."

// Games: eigen, eenvoudige launcher in plaats van quickshell-games-launchers.
// Hoesjes van Steam, Heroic, Lutris en games uit het appmenu, laatst gespeeld
// eerst. Klik of Enter start, typen zoekt, Esc sluit. Onderaan een smalle
// strook met CPU, GPU en RAM (wat dit paneel vroeger alleen liet zien).
FocusScope {
    id: root

    MatugenColors { id: mocha }

    property var games: []
    property bool loaded: false
    property string query: ""
    property int selectedIndex: 0
    property string launchingId: ""
    property int cpuPct: 0
    property int gpuPct: 0
    property int ramPct: 0
    readonly property string tool: Quickshell.env("HOME") + "/.local/bin/kingstra-games"
    readonly property var filteredGames: {
        let needle = String(query || "").toLowerCase().trim();
        if (needle === "") return games;
        return games.filter(g => String(g.title).toLowerCase().indexOf(needle) >= 0
            || String(g.source).toLowerCase().indexOf(needle) >= 0);
    }
    readonly property int columns: Math.max(2, Math.floor((width - 36 + 12) / (132 + 12)))

    function refresh() {
        if (!listProcess.running) listProcess.running = true;
        if (!usageProcess.running) usageProcess.running = true;
    }
    function closePanel() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }
    function launch(game) {
        if (!game || launchingId !== "") return;
        launchingId = game.id;
        Quickshell.execDetached([root.tool, "launch", game.id]);
        closeTimer.restart();
    }
    function coverSource(game) {
        let cover = String(game.cover || "");
        if (cover === "") return "";
        return cover.indexOf("://") > 0 ? cover : "file://" + cover;
    }
    function clampPct(v) {
        let n = parseInt(v);
        return isNaN(n) ? 0 : Math.max(0, Math.min(100, n));
    }
    function moveSelection(step) {
        if (filteredGames.length === 0) return;
        selectedIndex = Math.max(0, Math.min(filteredGames.length - 1, selectedIndex + step));
        grid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }

    onFilteredGamesChanged: selectedIndex = 0
    Component.onCompleted: {
        refresh();
        searchInput.forceActiveFocus();
    }

    // Kort na het starten sluiten, zodat je de klik nog ziet.
    Timer { id: closeTimer; interval: 450; onTriggered: { root.launchingId = ""; root.closePanel(); } }
    Timer { interval: 2500; running: true; repeat: true; onTriggered: if (!usageProcess.running) usageProcess.running = true }

    Process {
        id: listProcess
        command: [root.tool, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(this.text);
                    root.games = Array.isArray(parsed) ? parsed : [];
                } catch (error) {
                    root.games = [];
                }
                root.loaded = true;
            }
        }
        onExited: (code) => { if (code !== 0) root.loaded = true; }
    }

    Process {
        id: usageProcess
        command: ["bash", "-c",
            "cpu=$(awk '/^cpu /{u=$2+$4; t=$2+$3+$4+$5; if(pt>0){printf \"%.0f\",(u-pu)*100/(t-pt)}; pt=t; pu=u}' <(cat /proc/stat; sleep 0.25; cat /proc/stat)); " +
            "gpu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1); " +
            "[ -n \"$gpu\" ] || gpu=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1); " +
            "ram=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.0f\",((t-a)*100)/t}' /proc/meminfo); " +
            "echo \"${cpu:-0}|${gpu:-0}|${ram:-0}\""]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|");
                if (parts.length < 3) return;
                root.cpuPct = root.clampPct(parts[0]);
                root.gpuPct = root.clampPct(parts[1]);
                root.ramPct = root.clampPct(parts[2]);
            }
        }
    }

    Keys.onEscapePressed: event => { root.closePanel(); event.accepted = true; }
    Keys.onLeftPressed: event => { root.moveSelection(-1); event.accepted = true; }
    Keys.onRightPressed: event => { root.moveSelection(1); event.accepted = true; }
    Keys.onUpPressed: event => { root.moveSelection(-root.columns); event.accepted = true; }
    Keys.onDownPressed: event => { root.moveSelection(root.columns); event.accepted = true; }
    Keys.onReturnPressed: event => { root.launch(root.filteredGames[root.selectedIndex]); event.accepted = true; }
    Keys.onEnterPressed: event => { root.launch(root.filteredGames[root.selectedIndex]); event.accepted = true; }

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
                Text { anchors.centerIn: parent; text: "󰊴"; font.family: ThemeConfig.iconFont; font.pixelSize: 17; color: mocha.accent2 }
            }
            ColumnLayout {
                spacing: 1
                Text { text: "Games"; font.family: ThemeConfig.displayFont; font.pixelSize: 18; font.weight: Font.Black; color: mocha.text }
                Text {
                    text: !root.loaded ? "Bibliotheek lezen…"
                        : root.games.length + (root.games.length === 1 ? " game" : " games") + " · laatst gespeeld eerst · Enter start"
                    font.family: ThemeConfig.uiFont; font.pixelSize: 10; color: mocha.subtext0
                }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 10
                color: refreshMouse.containsMouse ? Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.16) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.72)
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                Text { anchors.centerIn: parent; text: "󰑓"; font.family: ThemeConfig.iconFont; font.pixelSize: 15; color: mocha.accent2 }
                MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 12
            color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.72)
            border.width: 1
            border.color: searchInput.activeFocus ? Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.62) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                Text { text: "󰍉"; font.family: ThemeConfig.iconFont; font.pixelSize: 15; color: mocha.accent2 }
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: mocha.text; font.family: ThemeConfig.uiFont; font.pixelSize: 13; selectByMouse: true
                    selectionColor: Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.34)
                    onTextChanged: root.query = text
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: searchInput.text === ""; text: "Zoek een game…"; font: searchInput.font; color: mocha.subtext0 }
                }
            }
        }

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            GridView {
                id: grid
                anchors.fill: parent
                clip: true
                model: root.filteredGames
                cellWidth: Math.floor(width / root.columns)
                cellHeight: Math.round((cellWidth - 12) * 1.5) + 34
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool current: root.selectedIndex === index
                    readonly property bool hovered: cardMouse.containsMouse
                    readonly property string coverUrl: root.coverSource(modelData)
                    width: grid.cellWidth; height: grid.cellHeight

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        ClippingRectangle {
                            id: frame
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(width * 1.5)
                            radius: 14
                            color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.72)
                            border.width: card.current ? 2 : 1
                            border.color: card.current
                                ? mocha.accent2
                                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, card.hovered ? 0.22 : 0.08)
                            scale: card.hovered || card.current ? 1.03 : 1.0
                            Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: Easing.OutBack } }
                            Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }

                            Image {
                                id: cover
                                anchors.fill: parent
                                source: card.coverUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: 300
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }
                            }
                            // Zonder hoesje: het app-icoon (uit het icoonthema of een
                            // pad in de .desktop), anders een gamepad. iconPath(…, true)
                            // geeft "" als het thema het icoon niet kent; met een
                            // fallback-naam toont Qt anders een zwart-magenta schaakbord.
                            Image {
                                id: appIcon
                                readonly property string name: String(card.modelData.icon || "")
                                anchors.centerIn: parent
                                width: parent.width * 0.46; height: width
                                visible: cover.status !== Image.Ready && status === Image.Ready
                                source: cover.status === Image.Ready || name === "" ? ""
                                    : (name.charAt(0) === "/" ? "file://" + name : Quickshell.iconPath(name, true))
                                sourceSize.width: 256; sourceSize.height: 256
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: cover.status !== Image.Ready && appIcon.status !== Image.Ready
                                text: "󰊴"; font.family: ThemeConfig.iconFont; font.pixelSize: 34
                                color: Qt.rgba(mocha.subtext0.r, mocha.subtext0.g, mocha.subtext0.b, 0.7)
                            }
                            Rectangle {
                                anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 7
                                width: sourceLabel.implicitWidth + 12; height: 18; radius: 9
                                color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.78)
                                Text { id: sourceLabel; anchors.centerIn: parent; text: card.modelData.source; font.family: ThemeConfig.uiFont; font.pixelSize: 9; font.weight: Font.Bold; color: mocha.subtext1 }
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.35)
                                opacity: root.launchingId === card.modelData.id ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }
                                Text { anchors.centerIn: parent; text: "󰐊"; font.family: ThemeConfig.iconFont; font.pixelSize: 36; color: mocha.text }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.title
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: ThemeConfig.uiFont; font.pixelSize: 11
                            font.weight: card.current ? Font.Bold : Font.Normal
                            color: card.current ? mocha.text : mocha.subtext1
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = card.index
                        onClicked: root.launch(card.modelData)
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width * 0.8
                visible: root.loaded && root.filteredGames.length === 0
                spacing: 6
                Text { Layout.alignment: Qt.AlignHCenter; text: "󰊴"; font.family: ThemeConfig.iconFont; font.pixelSize: 30; color: mocha.subtext0 }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.games.length === 0
                        ? "Nog geen games gevonden. Installeer ze via Steam, Heroic of Lutris; ze verschijnen hier vanzelf."
                        : "Niets gevonden voor “" + root.query + "”."
                    font.family: ThemeConfig.uiFont; font.pixelSize: 12; color: mocha.subtext0
                }
            }
        }

        // CPU, GPU en RAM in één smalle strook.
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Repeater {
                model: [
                    { label: "CPU", value: root.cpuPct, tint: mocha.blue },
                    { label: "GPU", value: root.gpuPct, tint: mocha.mauve },
                    { label: "RAM", value: root.ramPct, tint: mocha.green }
                ]
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6
                    Text { text: modelData.label; font.family: ThemeConfig.uiFont; font.pixelSize: 10; color: mocha.subtext0 }
                    Rectangle {
                        Layout.fillWidth: true; height: 6; radius: 3
                        color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.8)
                        Rectangle {
                            width: parent.width * (modelData.value / 100.0); height: parent.height; radius: parent.radius
                            color: modelData.tint
                            Behavior on width { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }
                        }
                    }
                    Text { text: modelData.value + "%"; font.family: ThemeConfig.uiFont; font.pixelSize: 10; color: mocha.text; Layout.preferredWidth: 30 }
                }
            }
        }
    }
}
