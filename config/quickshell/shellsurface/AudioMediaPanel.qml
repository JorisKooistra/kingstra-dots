import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import ".."

// Geluid & media: volume, microfoon en de lopende speler in één paneel, zoals
// de media/volume-widgets van Caelestia. De rail heeft hiervoor een eigen
// tegel; netwerk en batterij staan daar los van in de statustegel.
// Dit is ook het volumepaneel: de oude VolumePopup (uitvoer, invoer, apps)
// zit hier compact in, als uitklapbare lijsten onder de schuifregelaars.
// Het "volume"-doel van rail, sneltoetsen en qs_manager opent dit paneel.
// Het volledige muziekpaneel blijft bereikbaar via het pijltje in de kaart.
// De vorm (blob, hoeken, groei-animatie) komt volledig uit PanelHost.
Item {
    id: root

    MatugenColors { id: mocha }
    // Voor PanelSliders binnen een inline component: daar zou `mocha: mocha`
    // naar de eigen (lege) property van de slider wijzen in plaats van de id.
    readonly property var mochaPalette: mocha

    signal panelSwitchRequested(string entryId)

    readonly property int pad: 16
    readonly property int itemRadius: Math.max(10, Math.min(16, ThemeConfig.styleWidgetRadius))
    readonly property int preferredPanelWidth: 420
    // Groeit mee met de uitgeklapte lijsten; boven deze maat scrollt de
    // inhoud in plaats van dat het paneel van het scherm loopt.
    readonly property int maxPanelHeight: 760
    readonly property int preferredPanelHeight: Math.min(maxPanelHeight, Math.ceil(content.implicitHeight + pad * 2))

    // --- Speler --------------------------------------------------------------
    // Zelfde voorkeur als de rail: eerst wat speelt, dan een gepauzeerde speler
    // met titel. Met meerdere spelers kun je hier doorschakelen.
    property string pinnedIdentity: ""
    readonly property var players: Mpris.players.values
    readonly property var player: {
        let list = players;
        if (list.length === 0) return null;
        if (pinnedIdentity !== "") {
            for (let i = 0; i < list.length; i++) {
                if (String(list[i].identity || "") === pinnedIdentity) return list[i];
            }
        }
        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing) return list[i];
        }
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].trackTitle || "").trim() !== "") return list[i];
        }
        return list[0];
    }
    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: hasPlayer
        ? (String(player.trackTitle || "").trim() !== "" ? String(player.trackTitle) : String(player.identity || "Media"))
        : ""
    readonly property string trackArtist: hasPlayer ? String(player.trackArtist || "") : ""
    readonly property real trackLength: hasPlayer && player.lengthSupported ? Number(player.length || 0) : 0
    readonly property bool canSeek: hasPlayer && player.canSeek && player.positionSupported && trackLength > 0
    property real trackPosition: 0
    property bool draggingSeek: false

    function cyclePlayer() {
        let list = players;
        if (list.length < 2) return;
        let idx = list.indexOf(player);
        root.pinnedIdentity = String(list[(idx + 1) % list.length].identity || "");
    }

    function formatTime(seconds) {
        let s = Math.max(0, Math.floor(seconds || 0));
        let m = Math.floor(s / 60);
        let rest = s % 60;
        return m + ":" + (rest < 10 ? "0" : "") + rest;
    }

    // Mpris werkt `position` niet zelf bij; zonder deze tik staat de
    // voortgangsbalk stil.
    Timer {
        interval: 1000
        running: root.hasPlayer
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.hasPlayer || root.draggingSeek) return;
            root.player.positionChanged();
            root.trackPosition = Number(root.player.position || 0);
        }
    }

    // --- Audio (wpctl, net als de rail) -------------------------------------
    property int volume: 0
    property bool muted: false
    property int micVolume: 0
    property bool micMuted: false
    property bool micKnown: false
    property string sinkName: ""
    property bool draggingVolume: false
    property bool draggingMic: false

    function setVolume(target, percent) {
        let v = Math.max(0, Math.min(100, Math.round(percent)));
        let isSink = target === "@DEFAULT_AUDIO_SINK@";
        // Omhoog schuiven terwijl gedempt heft het dempen op, net als de
        // oude volumepopup deed.
        if (v > 0 && (isSink ? root.muted : root.micMuted)) {
            if (isSink) root.muted = false;
            else root.micMuted = false;
            Quickshell.execDetached(["wpctl", "set-mute", target, "0"]);
        }
        if (isSink) root.volume = v;
        else root.micVolume = v;
        Quickshell.execDetached(["wpctl", "set-volume", target, v + "%"]);
    }

    function toggleMute(target) {
        if (target === "@DEFAULT_AUDIO_SINK@") root.muted = !root.muted;
        else root.micMuted = !root.micMuted;
        Quickshell.execDetached(["wpctl", "set-mute", target, "toggle"]);
        refreshSoon.restart();
    }

    function refresh() {
        if (!audioPoller.running) audioPoller.running = true;
        if (!devicePoller.running) devicePoller.running = true;
        if (!eqPoller.running) eqPoller.running = true;
    }

    Component.onCompleted: refresh()

    // --- Apparaten en apps (uit de oude VolumePopup) ------------------------
    // get_audio_state.py levert uitvoer, invoer, app-streams en een
    // hardwaremelding; audio_control.sh voert de acties uit. Dezelfde scripts
    // gebruikt de instellingen-app.
    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/volume"
    property bool outputsExpanded: false
    property bool inputsExpanded: false
    property bool appsExpanded: false
    property bool eqExpanded: false
    // Equalizer-presets via EasyEffects, dezelfde als in de muziekpopup.
    readonly property string eqScript: Quickshell.env("HOME") + "/.config/quickshell/music/equalizer.sh"
    readonly property var eqPresets: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
    property bool eqAvailable: false
    property string eqPreset: ""
    property string hardwareNoticeTitle: ""
    property string hardwareNoticeText: ""
    // ListModel.get() geeft geen binding door; deze teller laat afgeleide
    // properties (standaarduitgang) opnieuw rekenen na elke poll.
    property int devicesRevision: 0
    // Knooppunten die nu gesleept worden; de poll laat hun volume met rust.
    property var draggingNodes: ({})

    ListModel { id: outputsModel }
    ListModel { id: inputsModel }
    ListModel { id: appsModel }

    readonly property var defaultOutput: {
        let revision = root.devicesRevision;
        for (let i = 0; i < outputsModel.count; i++) {
            let d = outputsModel.get(i);
            if (d.is_default) return { id: d.id, name: d.name };
        }
        if (outputsModel.count > 0) return { id: outputsModel.get(0).id, name: outputsModel.get(0).name };
        return { id: "", name: "" };
    }

    function toggleSection(section) {
        if (section === "outputs") root.outputsExpanded = !root.outputsExpanded;
        else if (section === "inputs") root.inputsExpanded = !root.inputsExpanded;
        else if (section === "eq") root.eqExpanded = !root.eqExpanded;
        else root.appsExpanded = !root.appsExpanded;
    }

    function setEqPreset(preset) {
        root.eqPreset = preset;
        Quickshell.execDetached(["bash", root.eqScript, "preset", preset]);
    }

    // Tab wisselde in de oude popup tussen Uitvoer, Invoer en Apps; hier
    // klapt hij die lijsten om de beurt open.
    function cycleSection() {
        let next = "outputs";
        if (root.outputsExpanded) next = root.micKnown ? "inputs" : "apps";
        else if (root.inputsExpanded) next = "apps";
        root.outputsExpanded = next === "outputs";
        root.inputsExpanded = next === "inputs";
        root.appsExpanded = next === "apps";
    }

    Shortcut {
        sequence: "Tab"
        onActivated: root.cycleSection()
    }

    function kindIcon(kind) {
        if (kind === "headset") return "󰋎";
        if (kind === "display") return "󰍹";
        if (kind === "microphone") return "󰍬";
        if (kind === "application") return "󰎆";
        return "󰓃";
    }

    function audioControl(args) {
        Quickshell.execDetached(["bash", root.scriptsDir + "/audio_control.sh"].concat(args));
    }

    function setNodeLocal(listModel, nodeId, key, value) {
        for (let i = 0; i < listModel.count; i++) {
            if (listModel.get(i).id === nodeId) {
                listModel.setProperty(i, key, value);
                return;
            }
        }
    }

    // Kiest een apparaat als standaard; audio_control.sh verhuist meteen
    // alle lopende streams mee. "Route herstellen" doet hetzelfde met de
    // huidige standaarduitgang.
    function setDefaultNode(type, nodeId, nodeName) {
        root.audioControl(["set-default", type, nodeId, nodeName]);
        refreshSoon.restart();
    }

    function toggleNodeMute(listModel, type, nodeId, currentlyMuted) {
        root.setNodeLocal(listModel, nodeId, "mute", !currentlyMuted);
        root.audioControl(["toggle-mute", type, nodeId]);
        refreshSoon.restart();
    }

    function setNodeDragging(nodeId, dragging) {
        if (dragging) {
            dragRelease.stop();
            root.draggingNodes[nodeId] = true;
        } else {
            dragRelease.restart();
        }
    }

    Timer {
        id: dragRelease
        interval: 600
        repeat: false
        onTriggered: {
            root.draggingNodes = ({});
            root.refresh();
        }
    }

    function syncModel(listModel, dataArray) {
        for (let i = listModel.count - 1; i >= 0; i--) {
            let nodeId = listModel.get(i).id;
            let found = false;
            for (let j = 0; j < dataArray.length; j++) {
                if (nodeId === dataArray[j].id) { found = true; break; }
            }
            if (!found) listModel.remove(i);
        }

        for (let i = 0; i < dataArray.length; i++) {
            let d = dataArray[i];
            let foundIdx = -1;
            for (let j = i; j < listModel.count; j++) {
                if (listModel.get(j).id === d.id) { foundIdx = j; break; }
            }

            let obj = {
                id: String(d.id), name: String(d.name || ""), description: String(d.description || ""),
                subtitle: String(d.subtitle || d.name || ""), kind: String(d.kind || "audio"),
                volume: Number(d.volume || 0), mute: !!d.mute, is_default: !!d.is_default,
                target: String(d.target || ""), corked: !!d.corked,
                portsJson: JSON.stringify(d.ports || [])
            };

            if (foundIdx === -1) {
                listModel.insert(i, obj);
            } else {
                if (foundIdx !== i) listModel.move(foundIdx, i, 1);
                for (let key in obj) {
                    if (key === "volume" && root.draggingNodes[obj.id]) continue;
                    if (listModel.get(i)[key] !== obj[key]) listModel.setProperty(i, key, obj[key]);
                }
            }
        }
    }

    Process {
        id: eqPoller
        command: ["bash", "-lc",
            "command -v easyeffects >/dev/null 2>&1 || { echo none; exit 0; }; bash \"$1\" get", "eq", root.eqScript]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                root.eqAvailable = raw !== "" && raw !== "none";
                if (!root.eqAvailable) return;
                try { root.eqPreset = String(JSON.parse(raw).preset || ""); } catch (e) {}
            }
        }
    }

    Process {
        id: devicePoller
        command: ["python3", root.scriptsDir + "/get_audio_state.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = null;
                try { data = JSON.parse(this.text.trim()); } catch (e) { return; }
                if (!data) return;
                root.syncModel(outputsModel, data.outputs || []);
                root.syncModel(inputsModel, data.inputs || []);
                root.syncModel(appsModel, data.apps || []);
                let notice = data.hardware_notice || {};
                root.hardwareNoticeTitle = notice.title || "";
                root.hardwareNoticeText = notice.message || "";
                root.devicesRevision += 1;
            }
        }
    }

    Process {
        id: audioPoller
        command: ["bash", "-lc",
            "sink=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | head -n1); " +
            "src=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | head -n1); " +
            "name=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk -F'\"' '/node.description/{print $2; exit}'); " +
            "printf 'sink=%s\\nsrc=%s\\nname=%s\\n' \"$sink\" \"$src\" \"$name\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let state = {};
                let lines = this.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let eq = lines[i].indexOf("=");
                    if (eq > 0) state[lines[i].substring(0, eq)] = lines[i].substring(eq + 1).trim();
                }

                let sink = state.sink || "";
                let sinkMatch = sink.match(/Volume:\s+([\d.]+)/);
                if (sinkMatch && !root.draggingVolume) root.volume = Math.round(parseFloat(sinkMatch[1]) * 100);
                root.muted = sink.indexOf("[MUTED]") !== -1;

                let source = state.src || "";
                let srcMatch = source.match(/Volume:\s+([\d.]+)/);
                root.micKnown = srcMatch !== null;
                if (srcMatch && !root.draggingMic) root.micVolume = Math.round(parseFloat(srcMatch[1]) * 100);
                root.micMuted = source.indexOf("[MUTED]") !== -1;

                root.sinkName = state.name || "";
            }
        }
    }

    Timer {
        id: refreshSoon
        interval: 300
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight + root.pad * 2
        // Alleen scrollen als de inhoud echt niet past; anders zou een
        // verticale sleep op een schuifregelaar het paneel laten verschuiven.
        interactive: contentHeight > height + 1
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        clip: true

        ColumnLayout {
            id: content
            x: root.pad
            y: root.pad
            width: flick.width - root.pad * 2
            spacing: 12

            // --- Kop ---------------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "Geluid & media"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 17
                    font.weight: Font.Black
                    color: mocha.text
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.sinkName
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    color: mocha.subtext0
                    elide: Text.ElideRight
                }

                // Melding uit get_audio_state.py, bijv. een USB-headset die
                // na een kernelupdate pas na een herstart weer werkt.
                Reveal {
                    shown: root.hardwareNoticeTitle !== ""
                    gap: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: noticeRow.implicitHeight + 20
                        radius: root.itemRadius
                        color: Qt.rgba(mocha.peach.r, mocha.peach.g, mocha.peach.b, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(mocha.peach.r, mocha.peach.g, mocha.peach.b, 0.50)

                        RowLayout {
                            id: noticeRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: "󰌪"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 20
                                color: mocha.peach
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: root.hardwareNoticeTitle
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: mocha.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.hardwareNoticeText
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 10
                                    color: mocha.subtext0
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            // --- Mediakaart ------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: mediaColumn.implicitHeight + 20
                radius: root.itemRadius
                color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.26)
                border.width: 1
                border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

                ColumnLayout {
                    id: mediaColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            radius: Math.min(root.itemRadius, 14)
                            color: Qt.rgba(mocha.accent3.r, mocha.accent3.g, mocha.accent3.b, 0.14)
                            clip: true

                            Image {
                                id: cover
                                anchors.fill: parent
                                source: root.hasPlayer && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                                asynchronous: true
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: cover.status !== Image.Ready
                                text: "󰎆"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 26
                                color: mocha.accent3
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: root.hasPlayer ? root.trackTitle : "Geen media actief"
                                font.family: ThemeConfig.displayFont
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: mocha.text
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: root.trackArtist
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 11
                                color: mocha.subtext0
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.topMargin: 4
                                spacing: 6

                                CtlButton {
                                    visible: root.hasPlayer
                                    icon: "󰒮"
                                    enabled: root.hasPlayer && root.player.canGoPrevious
                                    onTriggered: root.player.previous()
                                }
                                CtlButton {
                                    visible: root.hasPlayer
                                    primary: true
                                    icon: root.playing ? "󰏤" : "󰐊"
                                    enabled: root.hasPlayer && (root.player.canTogglePlaying || root.player.canPlay)
                                    onTriggered: {
                                        if (root.player.canTogglePlaying) root.player.togglePlaying();
                                        else root.player.play();
                                    }
                                }
                                CtlButton {
                                    visible: root.hasPlayer
                                    icon: "󰒭"
                                    enabled: root.hasPlayer && root.player.canGoNext
                                    onTriggered: root.player.next()
                                }
                                Item { Layout.fillWidth: true }
                                CtlButton {
                                    visible: root.players.length > 1
                                    icon: "󰓃"
                                    label: root.hasPlayer ? String(root.player.identity || "") : ""
                                    onTriggered: root.cyclePlayer()
                                }
                                CtlButton {
                                    icon: "󰅂"
                                    onTriggered: root.panelSwitchRequested("music")
                                }
                            }
                        }
                    }

                    PanelSlider {
                        mocha: mocha
                        itemRadius: root.itemRadius
                        visible: root.canSeek
                        showIcon: false
                        value: root.trackLength > 0 ? Math.round(root.trackPosition / root.trackLength * 100) : 0
                        valueText: root.formatTime(root.trackPosition) + " / " + root.formatTime(root.trackLength)
                        accent: mocha.accent3
                        onDragToggled: (dragging) => root.draggingSeek = dragging
                        onMoved: (percent) => {
                            let target = root.trackLength * percent / 100;
                            root.trackPosition = target;
                            if (root.canSeek) root.player.position = target;
                        }
                    }
                }
            }
            // --- Volume en uitvoerapparaten -------------------------------
            // Het pijltje klapt de lijst met uitvoerapparaten open: kiezen
            // als standaard, poort (speakers/koptelefoon), los volume en
            // dempen per apparaat, testtoon en route herstellen.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PanelSlider {
                    mocha: mocha
                    itemRadius: root.itemRadius
                    icon: root.muted || root.volume === 0 ? "󰝟" : (root.volume >= 70 ? "󰕾" : (root.volume >= 30 ? "󰖀" : "󰕿"))
                    label: "Volume"
                    value: root.volume
                    dimmed: root.muted
                    accent: mocha.accent3
                    detailTooltip: "Uitvoerapparaten"
                    detailExpanded: root.outputsExpanded
                    onIconClicked: root.toggleMute("@DEFAULT_AUDIO_SINK@")
                    onDragToggled: (dragging) => root.draggingVolume = dragging
                    onMoved: (percent) => root.setVolume("@DEFAULT_AUDIO_SINK@", percent)
                    onDetailRequested: root.toggleSection("outputs")
                }

                Reveal {
                    shown: root.outputsExpanded
                    gap: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        SectionLabel { text: "Uitvoer" }
                        Item { Layout.fillWidth: true }
                        CtlButton {
                            visible: root.defaultOutput.name !== ""
                            icon: "󰋋"
                            label: "Testtoon"
                            onTriggered: root.audioControl(["test-sound", "sink", root.defaultOutput.name])
                        }
                        CtlButton {
                            visible: root.defaultOutput.name !== ""
                            icon: "󰓦"
                            label: "Route herstellen"
                            onTriggered: root.setDefaultNode("sink", root.defaultOutput.id, root.defaultOutput.name)
                        }
                    }

                    Repeater {
                        model: outputsModel
                        delegate: NodeRow {
                            node: model
                            listModel: outputsModel
                            nodeType: "sink"
                        }
                    }

                    EmptyNote {
                        visible: outputsModel.count === 0
                        text: "Geen uitvoer gevonden"
                    }
                }

                // --- Microfoon en invoerapparaten --------------------------
                Reveal {
                    shown: root.micKnown
                    gap: 12

                    // Eigen kolom zonder tussenruimte: de gap van de invoerlijst
                    // zit in zijn animatie, anders springt hij 8 px bij openen.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        PanelSlider {
                            mocha: mocha
                            itemRadius: root.itemRadius
                            icon: root.micMuted ? "󰍭" : "󰍬"
                            label: "Microfoon"
                            value: root.micVolume
                            dimmed: root.micMuted
                            accent: mocha.accent1
                            detailTooltip: "Invoerapparaten"
                            detailExpanded: root.inputsExpanded
                            onIconClicked: root.toggleMute("@DEFAULT_AUDIO_SOURCE@")
                            onDragToggled: (dragging) => root.draggingMic = dragging
                            onMoved: (percent) => root.setVolume("@DEFAULT_AUDIO_SOURCE@", percent)
                            onDetailRequested: root.toggleSection("inputs")
                        }

                        Reveal {
                            shown: root.inputsExpanded
                            gap: 8

                            SectionLabel { text: "Invoer" }

                            Repeater {
                                model: inputsModel
                                delegate: NodeRow {
                                    node: model
                                    listModel: inputsModel
                                    nodeType: "source"
                                }
                            }

                            EmptyNote {
                                visible: inputsModel.count === 0
                                text: "Geen invoer actief"
                            }
                        }
                    }
                }
            }

            // --- Apps --------------------------------------------------------
            // Volume en dempen per app-stream, met de uitgang waar hij heen
            // speelt; standaard ingeklapt.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                SectionToggle {
                    icon: "󰎆"
                    label: "Apps"
                    detail: appsModel.count === 0 ? "geen geluid" : (appsModel.count === 1 ? "1 stream" : appsModel.count + " streams")
                    expanded: root.appsExpanded
                    onTriggered: root.toggleSection("apps")
                }

                Reveal {
                    shown: root.appsExpanded
                    gap: 8

                    Repeater {
                        model: appsModel
                        delegate: NodeRow {
                            node: model
                            listModel: appsModel
                            nodeType: "sink-input"
                        }
                    }

                    EmptyNote {
                        visible: appsModel.count === 0
                        text: "Geen apps met geluid"
                    }
                }
            }

            // --- Equalizer ---------------------------------------------------
            // Alleen met EasyEffects; een preset geldt direct voor alle uitvoer.
            ColumnLayout {
                visible: root.eqAvailable
                Layout.fillWidth: true
                spacing: 0

                SectionToggle {
                    icon: ""
                    label: "Equalizer"
                    detail: root.eqPreset === "Custom" ? "eigen instelling" : root.eqPreset
                    expanded: root.eqExpanded
                    onTriggered: root.toggleSection("eq")
                }

                Reveal {
                    shown: root.eqExpanded
                    gap: 8

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.eqPresets
                            delegate: Rectangle {
                                id: eqChip
                                required property string modelData
                                readonly property bool active: root.eqPreset === modelData
                                width: eqChipText.implicitWidth + 22
                                height: 28
                                radius: height / 2
                                color: active
                                    ? Qt.rgba(mocha.accent3.r, mocha.accent3.g, mocha.accent3.b, 0.26)
                                    : (eqChipMouse.containsMouse
                                        ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
                                        : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05))
                                border.width: 1
                                border.color: active
                                    ? Qt.rgba(mocha.accent3.r, mocha.accent3.g, mocha.accent3.b, 0.62)
                                    : "transparent"
                                scale: eqChipMouse.pressed ? 0.94 : (eqChipMouse.containsMouse ? 1.05 : 1.0)
                                Behavior on color {
                                    ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                                }
                                Behavior on scale {
                                    NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
                                }

                                Text {
                                    id: eqChipText
                                    anchors.centerIn: parent
                                    text: eqChip.modelData
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 11
                                    font.weight: eqChip.active ? Font.Bold : Font.Normal
                                    color: eqChip.active ? mocha.accent3 : mocha.text
                                }

                                MouseArea {
                                    id: eqChipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setEqPreset(eqChip.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Klapt zijn inhoud vloeiend open en dicht. De hoogte volgt de inhoud
    // direct; alleen het openen en sluiten zelf animeert, zodat geneste
    // lijsten niet achter elkaar aan lopen. De tussenruimte (gap) zit in de
    // animatie, zodat er bij het verbergen geen sprong overblijft.
    component Reveal: Item {
        id: reveal
        property bool shown: false
        property int gap: 8
        default property alias content: revealColumn.data
        property real progress: shown ? 1 : 0

        Layout.fillWidth: true
        Layout.preferredHeight: Math.ceil((revealColumn.implicitHeight + gap) * progress)
        visible: shown || progress > 0.001
        opacity: progress
        clip: true

        Behavior on progress {
            NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        ColumnLayout {
            id: revealColumn
            y: reveal.gap
            width: reveal.width
            spacing: 8
        }
    }

    component SectionLabel: Text {
        Layout.fillWidth: true
        font.family: ThemeConfig.uiFont
        font.pixelSize: 10
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
        color: mocha.subtext0
    }

    component EmptyNote: Text {
        Layout.fillWidth: true
        topPadding: 4
        bottomPadding: 4
        horizontalAlignment: Text.AlignHCenter
        font.family: ThemeConfig.uiFont
        font.pixelSize: 11
        color: mocha.subtext0
    }

    // Kopregel die een lijst open- en dichtklapt, in de maat van een
    // PanelSlider zodat de iconen netjes onder elkaar staan.
    component SectionToggle: Rectangle {
        id: toggle
        property string icon: ""
        property string label: ""
        property string detail: ""
        property bool expanded: false
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: Math.min(root.itemRadius, 16)
        color: toggleMouse.containsMouse
            ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
            : "transparent"
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Math.min(root.itemRadius, 16)
                color: Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, toggleMouse.containsMouse ? 0.22 : 0.10)
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
                Text {
                    anchors.centerIn: parent
                    text: toggle.icon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 16
                    color: mocha.green
                }
            }
            Text {
                text: toggle.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 12
                font.weight: Font.Bold
                color: mocha.text
            }
            Text {
                Layout.fillWidth: true
                text: toggle.detail
                font.family: ThemeConfig.monoFont
                font.pixelSize: 9
                font.weight: Font.Bold
                color: mocha.subtext0
                elide: Text.ElideRight
            }
            Text {
                Layout.preferredWidth: 24
                horizontalAlignment: Text.AlignHCenter
                text: "󰅂"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 14
                color: toggleMouse.containsMouse || toggle.expanded ? mocha.text : mocha.subtext0
                rotation: toggle.expanded ? 90 : 0
                Behavior on rotation {
                    NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
                }
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.triggered()
        }
    }

    // Eén apparaat of app-stream. Klik op de kop maakt een apparaat de
    // standaard; de actieve uitgang toont zijn poorten, de rest een eigen
    // schuifregelaar met dempknop. Apps hebben altijd een schuifregelaar.
    component NodeRow: Rectangle {
        id: row
        property var node: null
        property var listModel: null
        property string nodeType: "sink"
        readonly property bool isApp: nodeType === "sink-input"
        readonly property string nodeId: node ? String(node.id) : ""
        readonly property bool nodeMuted: node ? !!node.mute : false
        readonly property int nodeVolume: node ? Number(node.volume || 0) : 0
        readonly property bool isDefault: !isApp && !!node && !!node.is_default
        readonly property var ports: {
            try { return JSON.parse(node ? (node.portsJson || "[]") : "[]"); }
            catch (e) { return []; }
        }
        readonly property bool showsPorts: isDefault && nodeType === "sink" && ports.length > 0
        readonly property color accent: nodeType === "source" ? mocha.accent1 : (isApp ? mocha.green : mocha.accent3)

        Layout.fillWidth: true
        Layout.preferredHeight: rowColumn.implicitHeight + 16
        radius: Math.min(root.itemRadius, 14)
        color: isDefault
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.14)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, headMouse.containsMouse ? 0.08 : 0.04)
        border.width: 1
        border.color: isDefault
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.45)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on border.color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        // Elke schuifbeweging een eigen bash-proces is te veel; bundel tot
        // één opdracht per 50 ms, net als de oude popup.
        Timer {
            id: volumeThrottle
            interval: 50
            repeat: false
            property int targetPct: -1
            onTriggered: {
                if (targetPct < 0 || row.nodeId === "") return;
                root.audioControl(["set-volume", row.nodeType, row.nodeId, String(targetPct)]);
                targetPct = -1;
            }
        }

        ColumnLayout {
            id: rowColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: headRow.implicitHeight

                MouseArea {
                    id: headMouse
                    anchors.fill: parent
                    enabled: !row.isApp
                    hoverEnabled: !row.isApp && !row.isDefault
                    cursorShape: !row.isApp && !row.isDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (!row.isDefault && row.nodeId !== "")
                            root.setDefaultNode(row.nodeType, row.nodeId, String(row.node.name || ""));
                    }
                }

                RowLayout {
                    id: headRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Math.min(root.itemRadius, 14)
                        color: Qt.rgba(row.accent.r, row.accent.g, row.accent.b, row.isDefault ? 0.26 : 0.12)
                        Behavior on color {
                            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: root.kindIcon(row.node ? String(row.node.kind || "") : "")
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 15
                            color: row.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.node ? String(row.node.description || "") : ""
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: mocha.text
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: {
                                if (!row.node) return "";
                                if (row.isApp && String(row.node.target || "") !== "")
                                    return String(row.node.target) + (row.node.corked ? " · gepauzeerd" : " · speelt");
                                return String(row.node.subtitle || "");
                            }
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 10
                            color: mocha.subtext0
                            elide: Text.ElideRight
                        }
                    }

                    // Standaard-badge, of bij hover een hint dat klikken kiest.
                    Rectangle {
                        visible: !row.isApp
                        Layout.preferredWidth: badgeText.implicitWidth + 16
                        Layout.preferredHeight: 20
                        radius: height / 2
                        opacity: row.isDefault || headMouse.containsMouse ? 1.0 : 0.0
                        color: row.isDefault
                            ? Qt.rgba(row.accent.r, row.accent.g, row.accent.b, 0.30)
                            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
                        Behavior on opacity {
                            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                        }
                        Behavior on color {
                            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                        }
                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: row.isDefault ? "Standaard" : "Kiezen"
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: row.isDefault ? row.accent : mocha.text
                        }
                    }
                }
            }

            // Poorten van de actieve uitgang (speakers, koptelefoon, HDMI).
            Reveal {
                shown: row.showsPorts
                gap: 8

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: row.ports

                        delegate: Rectangle {
                            id: portChip
                            required property var modelData
                            readonly property bool unavailable: String(modelData.availability) === "not available"
                            width: portLabel.implicitWidth + 20
                            height: 24
                            radius: height / 2
                            opacity: unavailable && !modelData.active ? 0.42 : 1.0
                            color: modelData.active
                                ? Qt.rgba(row.accent.r, row.accent.g, row.accent.b, 0.34)
                                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, portMouse.containsMouse ? 0.14 : 0.06)
                            border.width: 1
                            border.color: modelData.active
                                ? Qt.rgba(row.accent.r, row.accent.g, row.accent.b, 0.60)
                                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
                            Behavior on color {
                                ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                            }

                            Text {
                                id: portLabel
                                anchors.centerIn: parent
                                text: (portChip.modelData.active ? "● " : "") + String(portChip.modelData.description || "Poort")
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 10
                                font.weight: portChip.modelData.active ? Font.Bold : Font.Medium
                                color: portChip.modelData.active ? mocha.text : mocha.subtext0
                            }

                            MouseArea {
                                id: portMouse
                                anchors.fill: parent
                                enabled: !portChip.unavailable && !portChip.modelData.active
                                hoverEnabled: enabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    root.audioControl(["set-port", "sink", String(row.node.name || ""), String(portChip.modelData.name)]);
                                    refreshSoon.restart();
                                }
                            }
                        }
                    }
                }
            }

            // Eigen volume en dempen; de actieve uitgang/invoer heeft die al
            // in de hoofdregelaar erboven.
            Reveal {
                shown: !row.isDefault
                gap: 4

                PanelSlider {
                    mocha: root.mochaPalette
                    itemRadius: root.itemRadius
                    icon: row.nodeMuted || row.nodeVolume === 0 ? "󰖁" : (row.nodeVolume > 50 ? "󰕾" : "󰖀")
                    value: row.nodeVolume
                    valueText: row.nodeVolume + "%"
                    dimmed: row.nodeMuted
                    accent: row.accent
                    onIconClicked: root.toggleNodeMute(row.listModel, row.nodeType, row.nodeId, row.nodeMuted)
                    onDragToggled: (dragging) => root.setNodeDragging(row.nodeId, dragging)
                    onMoved: (percent) => {
                        let v = Math.max(0, Math.min(100, Math.round(percent)));
                        // Omhoog schuiven heft dempen op; lokaal meteen
                        // bijwerken, anders schakelt elke tik het opnieuw.
                        if (v > 0 && row.nodeMuted) root.toggleNodeMute(row.listModel, row.nodeType, row.nodeId, true);
                        root.setNodeLocal(row.listModel, row.nodeId, "volume", v);
                        volumeThrottle.targetPct = v;
                        if (!volumeThrottle.running) volumeThrottle.start();
                    }
                }
            }
        }
    }

    component CtlButton: Rectangle {
        id: ctl
        property string icon: ""
        property string label: ""
        property bool primary: false
        signal triggered()

        Layout.preferredWidth: label !== "" ? ctlRow.implicitWidth + 16 : (primary ? 36 : 30)
        Layout.preferredHeight: 28
        radius: Math.min(root.itemRadius, 14)
        opacity: enabled ? 1.0 : 0.4
        color: primary
            ? Qt.rgba(mocha.accent3.r, mocha.accent3.g, mocha.accent3.b, ctlMouse.containsMouse ? 0.40 : 0.26)
            : (ctlMouse.containsMouse
                ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05))
        scale: ctlMouse.pressed ? 0.94 : (ctlMouse.containsMouse ? 1.05 : 1.0)
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        Row {
            id: ctlRow
            anchors.centerIn: parent
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ctl.icon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 14
                color: ctl.primary ? mocha.accent3 : mocha.text
            }
            Text {
                visible: ctl.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: ctl.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                color: mocha.subtext0
                width: Math.min(implicitWidth, 90)
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: ctlMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: ctl.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: ctl.triggered()
        }
    }
}
