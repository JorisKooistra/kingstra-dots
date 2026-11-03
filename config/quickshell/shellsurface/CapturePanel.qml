import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Vastleg-studio: één plek voor schermafbeelding, opname, tekst uit beeld en
// kleur kiezen, zoals de schermafbeeldings-balk van GNOME en het Knipprogramma
// van Windows. Kies wat (gebied, venster, scherm) en hoe (foto of opname) en
// druk Enter. Na een foto komt een melding met de afbeelding en de knoppen
// Bewerken en Map openen; tijdens een opname staat er een rode stip in het
// eiland en toont deze studio een stopknop.
//
// Toetsen: 1/2/3 gebied, venster, scherm · F foto · O opname · G geluid ·
// N met notities · T tekst kopiëren · K kleur · Enter vastleggen · Esc sluit.
FocusScope {
    id: root

    MatugenColors { id: mocha }

    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"
    readonly property int preferredPanelWidth: 700
    readonly property int preferredPanelHeight: recording ? 220 : 300

    property string target: "area"     // area | window | full
    property string kind: "photo"      // photo | video
    property bool withAudio: false
    property bool withNotes: false
    property bool recording: false
    property int recordingSince: 0
    property int now: Math.floor(Date.now() / 1000)

    readonly property var targets: [
        { id: "area", label: "Gebied", glyph: "󰩭", key: "1" },
        { id: "window", label: "Venster", glyph: "󰖯", key: "2" },
        { id: "full", label: "Scherm", glyph: "󰍹", key: "3" }
    ]

    readonly property string elapsed: {
        let s = Math.max(0, now - recordingSince);
        let m = Math.floor(s / 60);
        let r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    function close() {
        Quickshell.execDetached(["bash", scripts + "/qs_manager.sh", "close"]);
    }

    // Eerst het paneel dicht, dan pas vastleggen: anders staat de studio
    // zelf op de foto.
    function runAfterClose(args) {
        close();
        Quickshell.execDetached(["bash", "-c", "sleep 0.3; exec \"$@\"", "bash"].concat(args));
    }

    function capture() {
        if (kind === "video") {
            let args = ["bash", scripts + "/capture.sh", "record", target];
            if (withAudio) args.push("--audio");
            runAfterClose(args);
            return;
        }
        let args = ["bash", scripts + "/screenshot.sh"];
        if (target === "full") args.push("--full");
        if (target === "window") args.push("--window");
        args.push(withNotes ? "--annotate" : "--preview");
        runAfterClose(args);
    }

    function stopRecording() {
        close();
        Quickshell.execDetached(["bash", scripts + "/capture.sh", "record-stop"]);
    }

    Process {
        id: statusProc
        command: ["bash", root.scripts + "/capture.sh", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim());
                    root.recording = d.recording === true;
                    root.recordingSince = Number(d.since) || 0;
                } catch (e) {
                    root.recording = false;
                }
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.now = Math.floor(Date.now() / 1000)
    }

    focus: true
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; return; }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (root.recording) root.stopRecording();
            else root.capture();
            event.accepted = true;
            return;
        }
        if (root.recording) return;
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            let i = root.targets.findIndex(t => t.id === root.target);
            root.target = root.targets[(i + 1) % root.targets.length].id;
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
            let i = root.targets.findIndex(t => t.id === root.target);
            root.target = root.targets[(i + root.targets.length - 1) % root.targets.length].id;
            event.accepted = true;
            return;
        }
        let t = String(event.text || "").toLowerCase();
        if (t === "1" || t === "2" || t === "3") { root.target = root.targets[parseInt(t) - 1].id; event.accepted = true; return; }
        if (t === "f") { root.kind = "photo"; event.accepted = true; return; }
        if (t === "o") { root.kind = "video"; event.accepted = true; return; }
        if (t === "g") { root.withAudio = !root.withAudio; event.accepted = true; return; }
        if (t === "n") { root.withNotes = !root.withNotes; event.accepted = true; return; }
        if (t === "t") { root.runAfterClose(["bash", root.scripts + "/capture.sh", "ocr"]); event.accepted = true; return; }
        if (t === "k") { root.runAfterClose(["bash", root.scripts + "/capture.sh", "color"]); event.accepted = true; return; }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: root.recording ? "󰑋" : "󰄀"
                font.family: ThemeConfig.iconFont
                font.pixelSize: 20
                color: root.recording ? mocha.red : mocha.primary
            }
            Text {
                Layout.fillWidth: true
                text: root.recording ? "Opname loopt  ·  " + root.elapsed : "Vastleggen"
                font.family: ThemeConfig.displayFont
                font.pixelSize: 17
                font.weight: Font.Bold
                color: mocha.text
            }
            Text {
                text: root.recording ? "Enter stopt de opname" : "Enter legt vast  ·  Esc sluit"
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                color: mocha.subtext0
            }
        }

        // Tijdens een opname: alleen de grote stopknop.
        Rectangle {
            visible: root.recording
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            radius: Math.max(14, ThemeConfig.styleWidgetRadius)
            color: stopHover.hovered ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.26) : Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.16)
            border.width: 1
            border.color: Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.6)
            scale: stopHover.hovered ? 1.01 : 1.0
            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
            Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") } }
            HoverHandler { id: stopHover }
            TapHandler { onTapped: root.stopRecording() }
            Row {
                anchors.centerIn: parent
                spacing: 12
                Rectangle {
                    width: 18; height: 18; radius: 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: mocha.red
                }
                Text {
                    text: "Opname stoppen en opslaan"
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: mocha.text
                }
            }
        }

        // Wat: gebied, venster, scherm.
        RowLayout {
            visible: !root.recording
            Layout.fillWidth: true
            spacing: 12
            Repeater {
                model: root.targets
                delegate: Rectangle {
                    id: targetCard
                    required property var modelData
                    readonly property bool chosen: root.target === modelData.id
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    radius: Math.max(14, ThemeConfig.styleWidgetRadius)
                    color: targetHover.hovered || chosen
                        ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, chosen ? 0.18 : 0.10)
                        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.7)
                    border.width: chosen ? 2 : 1
                    border.color: chosen ? mocha.primary : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                    scale: targetHover.hovered ? 1.025 : 1.0
                    Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                    Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") } }
                    HoverHandler { id: targetHover }
                    TapHandler {
                        onTapped: root.target = targetCard.modelData.id
                        onDoubleTapped: { root.target = targetCard.modelData.id; root.capture(); }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: targetCard.modelData.glyph
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: 26
                            color: targetCard.chosen ? mocha.primary : mocha.subtext1
                            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: targetCard.modelData.label + "  ·  " + targetCard.modelData.key
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 12
                            font.weight: targetCard.chosen ? Font.Bold : Font.Normal
                            color: mocha.text
                        }
                    }
                }
            }
        }

        // Hoe: foto of opname, plus de opties, en de losse gereedschappen.
        Flow {
            visible: !root.recording
            Layout.fillWidth: true
            spacing: 8
            Pill { glyph: "󰄀"; label: "Foto  ·  F"; chosen: root.kind === "photo"; onTriggered: root.kind = "photo" }
            Pill { glyph: "󰑋"; label: "Opname  ·  O"; chosen: root.kind === "video"; tone: mocha.red; onTriggered: root.kind = "video" }
            Pill { visible: root.kind === "video"; glyph: root.withAudio ? "󰕾" : "󰖁"; label: root.withAudio ? "Met geluid  ·  G" : "Zonder geluid  ·  G"; chosen: root.withAudio; onTriggered: root.withAudio = !root.withAudio }
            Pill { visible: root.kind === "photo"; glyph: "󰏫"; label: "Met notities  ·  N"; chosen: root.withNotes; onTriggered: root.withNotes = !root.withNotes }
            Item { width: 12; height: 1 }
            Pill { glyph: "󰈙"; label: "Tekst kopiëren  ·  T"; onTriggered: root.runAfterClose(["bash", root.scripts + "/capture.sh", "ocr"]) }
            Pill { glyph: "󰈊"; label: "Kleur kiezen  ·  K"; onTriggered: root.runAfterClose(["bash", root.scripts + "/capture.sh", "color"]) }
        }

        Item { Layout.fillHeight: true; visible: !root.recording }

        Rectangle {
            visible: !root.recording
            Layout.alignment: Qt.AlignRight
            Layout.preferredWidth: goLabel.implicitWidth + 44
            Layout.preferredHeight: 38
            radius: 19
            color: goHover.hovered ? Qt.lighter(root.kind === "video" ? mocha.red : mocha.primary, 1.08) : (root.kind === "video" ? mocha.red : mocha.primary)
            scale: goHover.hovered ? 1.03 : 1.0
            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
            Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") } }
            HoverHandler { id: goHover }
            TapHandler { onTapped: root.capture() }
            Text {
                id: goLabel
                anchors.centerIn: parent
                text: root.kind === "video" ? "Opname starten" : "Vastleggen"
                font.family: ThemeConfig.uiFont
                font.pixelSize: 13
                font.weight: Font.Bold
                color: mocha.base
            }
        }
    }

    component Pill: Rectangle {
        id: pill
        property string glyph: ""
        property string label: ""
        property bool chosen: false
        property color tone: mocha.primary
        signal triggered()
        implicitHeight: 34
        implicitWidth: pillRow.implicitWidth + 26
        radius: height / 2
        color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.20)
            : (pillHover.hovered ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.7))
        border.width: 1
        border.color: chosen ? tone : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
        scale: pillTap.pressed ? 0.96 : 1.0
        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }
        HoverHandler { id: pillHover }
        TapHandler { id: pillTap; onTapped: pill.triggered() }
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 7
            Text { text: pill.glyph; font.family: ThemeConfig.iconFont; font.pixelSize: 14; color: pill.chosen ? pill.tone : mocha.subtext1; anchors.verticalCenter: parent.verticalCenter }
            Text { text: pill.label; font.family: ThemeConfig.uiFont; font.pixelSize: 12; color: mocha.text; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
