import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Andere machine (kingstra koppel), in dezelfde vormtaal als het
// telefoonpaneel: afgeronde tegels, Matugen-kleuren, ThemeConfig-animaties.
// De vorm (blob, hoeken, groei) komt uit PanelHost.
//  - kaart met naam, bereikbaarheid (snelle ssh-check, hooguit elke 10 s
//    zolang het paneel open is), delen aan/uit en de kant waar hij staat;
//  - tegels: delen aan/uit, bestanden sturen, venster daar openen, plaats
//    naast je schermen (Beeldschermen), bladeren in Bestanden, status;
//  - dropvak: bestanden hierheen slepen stuurt ze naar Downloads daar;
//  - niet gekoppeld: één knop "Koppelen…" (terminal, eenmalig wachtwoord).
Item {
    id: root

    MatugenColors { id: mocha }

    signal panelSwitchRequested(string entryId)

    readonly property string kingstraBin: Quickshell.env("HOME") + "/.local/bin/kingstra"
    readonly property string feedbackScript: Quickshell.env("HOME") + "/.config/hypr/scripts/feedback.sh"
    readonly property int pad: 16
    readonly property int itemRadius: Math.max(10, Math.min(16, ThemeConfig.styleWidgetRadius))
    readonly property bool matteStyle: ThemeConfig.styleFamily === "matte"
    readonly property int preferredPanelWidth: 420
    readonly property int preferredPanelHeight: Math.ceil(content.implicitHeight + pad * 2)

    // --- Gegevens -------------------------------------------------------------
    property bool loaded: false
    property bool gekoppeld: false
    property string host: ""
    property string ip: ""
    property string user: ""
    property string label: ""
    property string kant: ""
    property bool actief: false
    // "" = nog niet gecontroleerd, "ja" / "nee" na de ssh-check.
    property string bereikbaar: ""
    property bool checking: false
    property bool dropHover: false

    readonly property string naam: label === "pc" ? "PC"
        : (label !== "" ? label.charAt(0).toUpperCase() + label.slice(1) : (host !== "" ? host : "Andere machine"))
    readonly property string peerIcon: label === "pc" ? "󰟀" : "󰌢"
    readonly property bool usable: gekoppeld && bereikbaar === "ja"
    readonly property color peerAccent: mocha.accent2

    // Welke actie loopt er (voor "bezig"), en welke is net gelukt (vinkje).
    property string busy: ""
    property string done: ""

    readonly property string koppelCommand:
        "PATH=\"$HOME/.local/bin:$PATH\"; echo 'Koppel deze machine aan je andere Kingstra-machine.'; " +
        "read -rp 'Naam van de andere machine (bv. titus): ' h; [ -n \"$h\" ] && kingstra koppel \"$h\"; " +
        "echo; read -rp 'Enter om te sluiten' _"

    function feedback(icon, title, detail) {
        Quickshell.execDetached(["bash", feedbackScript, icon, title, detail || "", "3500"]);
    }
    function refresh() { if (!stateProc.running) stateProc.running = true; }
    function checkReach() {
        if (!gekoppeld || reachProc.running) return;
        checking = true;
        reachProc.running = true;
    }
    function act(action, args) {
        if (busy !== "") return;
        busy = action;
        actProc.command = [kingstraBin, "koppel"].concat(args);
        actProc.running = true;
    }
    function sendFiles(files) {
        if (files.length === 0) return;
        act("stuur", ["stuur"].concat(files));
    }
    function fileUrlsToPaths(urls) {
        let files = [];
        for (let u of (urls || [])) {
            let s = String(u);
            if (s.indexOf("file://") === 0) files.push(decodeURIComponent(s.substring(7)));
        }
        return files;
    }
    function inTerminal(title, cmd) {
        Quickshell.execDetached(["kitty", "--title=" + title, "bash", "-lc", cmd]);
        root.panelSwitchRequested("");
    }
    function startKoppelen() { inTerminal("Koppelen", koppelCommand); }
    function showStatus() {
        inTerminal("Koppeling", "PATH=\"$HOME/.local/bin:$PATH\"; kingstra koppel status; echo; read -rp 'Enter om te sluiten' _");
    }
    // Eerst het paneel dicht, dan pas openen: zo is het venster eronder weer
    // het actieve venster en gaat dát mee naar de andere machine.
    function openThere() {
        Quickshell.execDetached(["bash", "-c", "sleep 0.35; exec \"$1\" koppel open", "koppel-open", kingstraBin]);
        root.panelSwitchRequested("");
    }
    function browse() {
        let doel = host !== "" ? host : ip;
        if (doel === "") return;
        let u = user !== "" ? user : Quickshell.env("USER");
        Quickshell.execDetached(["nautilus", "--new-window", "sftp://" + u + "@" + doel + "/home/" + u]);
        root.panelSwitchRequested("");
    }

    Component.onCompleted: refresh()

    Process {
        id: stateProc
        command: ["sh", "-c", "cat \"$HOME/.config/kingstra/koppeling.json\" 2>/dev/null || echo '{}'; " +
            "echo; systemctl --user is-active kingstra-lan-mouse.service 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = String(this.text || "");
                let cut = txt.lastIndexOf("}");
                let k = {};
                try { k = JSON.parse(cut >= 0 ? txt.substring(0, cut + 1) : "{}"); } catch (e) { k = {}; }
                let was = root.gekoppeld;
                root.gekoppeld = !!k.host;
                root.host = String(k.host || "");
                root.ip = String(k.ip || "");
                root.user = String(k.user || "");
                root.label = String(k.label || "");
                root.kant = String(k.kant || "");
                root.actief = cut >= 0 && txt.substring(cut + 1).trim() === "active";
                root.loaded = true;
                if (root.gekoppeld && (!was || root.bereikbaar === "")) root.checkReach();
            }
        }
    }
    // Snelle check: ssh zonder wachtwoord, eerst op naam, anders op het laatst
    // bekende IP-adres.
    Process {
        id: reachProc
        command: ["sh", "-c",
            "o='-o BatchMode=yes -o ConnectTimeout=2 -o StrictHostKeyChecking=accept-new'; " +
            "ssh $o \"$1@$2\" true >/dev/null 2>&1 || { [ -n \"$3\" ] && ssh $o \"$1@$3\" true >/dev/null 2>&1; }",
            "koppel-check", root.user !== "" ? root.user : Quickshell.env("USER"), root.host, root.ip]
        onExited: (code) => {
            root.checking = false;
            root.bereikbaar = code === 0 ? "ja" : "nee";
        }
    }
    Process {
        id: actProc
        onExited: (code) => {
            let what = root.busy;
            root.busy = "";
            if (code === 0) {
                root.done = what;
                doneTimer.restart();
            } else if (what === "stuur" || what === "stuur-kies") {
                if (code !== 3) root.feedback("󰌢", "Niet verstuurd", root.naam + " is niet bereikbaar. Staat hij aan en op hetzelfde netwerk?");
            } else {
                root.feedback("󰌢", "Lukte niet", "Kijk bij Status voor details.");
            }
            root.refresh();
        }
    }
    Timer { id: doneTimer; interval: 1400; onTriggered: root.done = "" }
    // Zolang het paneel open is: delen-status vaak, bereikbaarheid rustig.
    Timer { interval: 3000; running: true; repeat: true; onTriggered: root.refresh() }
    Timer { interval: 10000; running: root.gekoppeld; repeat: true; onTriggered: root.checkReach() }

    // ------------------------------------------------------------------------
    // Weergave
    // ------------------------------------------------------------------------
    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 12

        // --- Kop -------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Math.min(root.itemRadius, 18)
                color: Qt.rgba(root.peerAccent.r, root.peerAccent.g, root.peerAccent.b, 0.22)
                Text {
                    anchors.centerIn: parent
                    text: root.peerIcon
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 18
                    color: root.peerAccent
                }
                Rectangle {
                    width: 10; height: 10; radius: 5
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -1
                    color: root.usable ? mocha.green : (root.gekoppeld ? mocha.subtext0 : "transparent")
                    border.width: 2
                    border.color: mocha.base
                    Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: root.gekoppeld ? root.naam : "Andere machine"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 17
                    font.weight: ThemeConfig.headingWeight
                    color: mocha.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: "Muis, toetsenbord, klembord en bestanden · eigen netwerk"
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    color: mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: root.gekoppeld
                icon: "󰑐"
                accent: root.peerAccent
                spinning: root.checking
                tip: "Opnieuw controleren"
                onTriggered: { root.refresh(); root.checkReach(); }
            }
            IconButton {
                icon: "󰋼"
                accent: mocha.subtext1
                tip: "Status in een terminal"
                onTriggered: root.showStatus()
            }
        }

        // --- Kaart -----------------------------------------------------------
        Rectangle {
            id: hero
            Layout.fillWidth: true
            Layout.preferredHeight: heroColumn.implicitHeight + 24
            radius: Math.min(root.itemRadius + 2, 18)
            readonly property color tint: root.usable ? root.peerAccent : mocha.subtext0
            color: root.matteStyle ? mocha.shellRaisedFill : Qt.rgba(tint.r, tint.g, tint.b, root.usable ? 0.10 : 0.05)
            border.width: 1
            border.color: Qt.rgba(tint.r, tint.g, tint.b, root.usable ? 0.35 : 0.16)
            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
            }
            clip: true

            ColumnLayout {
                id: heroColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: !root.loaded ? "Laden…" : (root.gekoppeld ? root.naam + (root.host !== "" ? " · " + root.host : "") : "Nog niet gekoppeld")
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: 18
                        font.weight: ThemeConfig.headingWeight
                        color: mocha.text
                        elide: Text.ElideRight
                    }
                    Row {
                        spacing: 6
                        visible: root.gekoppeld
                        Rectangle {
                            id: statusDot
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7; height: 7; radius: 4
                            color: root.usable ? mocha.green : (root.bereikbaar === "nee" ? mocha.red : mocha.subtext0)
                            SequentialAnimation on opacity {
                                running: root.checking
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) statusDot.opacity = 1
                                NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.bereikbaar === "ja" ? "Bereikbaar"
                                : (root.bereikbaar === "nee" ? "Niet bereikbaar" : "Controleren…")
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.usable ? mocha.green : mocha.subtext0
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    visible: root.gekoppeld
                    spacing: 6
                    InfoChip {
                        icon: root.actief ? "󰍽" : "󰍾"
                        label: root.actief ? "Delen aan" : "Delen uit"
                        tint: root.actief ? mocha.green : mocha.subtext0
                    }
                    InfoChip {
                        visible: root.kant !== ""
                        icon: "󰍹"
                        label: "Staat " + root.kant
                        tint: root.peerAccent
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.gekoppeld && root.bereikbaar === "nee"
                    text: root.naam + " reageert niet. Staat hij aan, is hij wakker en zit hij op hetzelfde netwerk?"
                    wrapMode: Text.WordWrap
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.loaded && !root.gekoppeld
                    text: "Koppel je laptop eenmalig: daarna schuift je muis over de schermrand naar de andere machine, loopt het klembord mee en sleep je bestanden erheen. Je typt één keer het wachtwoord van de andere machine."
                    wrapMode: Text.WordWrap
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.loaded && !root.gekoppeld
                    PillButton {
                        label: "Koppelen…"; icon: "󰌹"; accent: root.peerAccent; primary: true
                        onTriggered: root.startKoppelen()
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        // --- Acties ----------------------------------------------------------
        GridLayout {
            Layout.fillWidth: true
            visible: root.gekoppeld
            columns: 3
            columnSpacing: 8
            rowSpacing: 8

            ActionTile {
                action: "delen"; icon: root.actief ? "󰍽" : "󰍾"
                label: root.actief ? "Delen aan" : "Delen uit"
                accent: mocha.green
                toggled: root.actief
                tip: root.actief ? "Muis, toetsenbord en klembord delen tijdelijk uitzetten"
                                 : "Muis, toetsenbord en klembord weer delen"
                onTriggered: root.act("delen", [root.actief ? "uit" : "aan"])
            }
            ActionTile {
                action: "stuur-kies"; icon: "󰁝"; label: "Bestanden sturen"; accent: mocha.accent3
                dimmed: root.bereikbaar === "nee"
                tip: "Kies bestanden; ze komen in Downloads op " + root.naam
                onTriggered: root.act("stuur-kies", ["stuur-kies"])
            }
            ActionTile {
                action: "open"; icon: "󱂬"; label: "Venster daar openen"; accent: mocha.accent1
                dimmed: root.bereikbaar === "nee"
                tip: "Open het actieve venster ook op " + root.naam + " (zelfde app, bestand of link gaat mee)"
                onTriggered: root.openThere()
            }
            ActionTile {
                action: "plaats"; icon: "󰍹"
                label: root.kant !== "" ? "Plaats: " + root.kant : "Plaats"
                accent: root.peerAccent
                tip: "Sleep " + root.naam + " in Beeldschermen naar een andere rand van je schermen"
                onTriggered: root.panelSwitchRequested("monitors")
            }
            ActionTile {
                action: "bladeren"; icon: "󰉋"; label: "Bladeren"; accent: mocha.yellow
                dimmed: root.bereikbaar === "nee"
                tip: "Open de bestanden van " + root.naam + " in Bestanden"
                onTriggered: root.browse()
            }
            ActionTile {
                action: "status"; icon: "󰋼"; label: "Status"; accent: mocha.subtext1
                tip: "Wat draait er en is " + root.naam + " bereikbaar? (terminal)"
                onTriggered: root.showStatus()
            }
        }

        // --- Dropvak ---------------------------------------------------------
        Rectangle {
            id: dropZone
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            visible: root.gekoppeld
            radius: Math.min(root.itemRadius, 16)
            readonly property color tint: root.done === "stuur" ? mocha.green : root.peerAccent
            color: root.dropHover || root.done === "stuur"
                ? Qt.rgba(tint.r, tint.g, tint.b, 0.20)
                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.04)
            border.width: 1
            border.color: root.dropHover
                ? Qt.rgba(tint.r, tint.g, tint.b, 0.70)
                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
            scale: root.dropHover ? 1.02 : 1.0
            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
            Behavior on scale {
                NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    id: dropGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.done === "stuur" ? "󰄬" : (root.busy === "stuur" ? "󰑐" : "󰇚")
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 18
                    color: root.dropHover || root.done === "stuur" ? dropZone.tint : mocha.subtext1
                    RotationAnimation on rotation {
                        running: root.busy === "stuur"
                        from: 0; to: 360; duration: 900
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) dropGlyph.rotation = 0
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.done === "stuur" ? "Verstuurd naar Downloads op " + root.naam
                        : (root.busy === "stuur" ? "Versturen…"
                        : (root.dropHover ? "Loslaten om te sturen" : "Sleep bestanden hierheen"))
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: root.dropHover ? mocha.text : mocha.subtext0
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: (drag) => {
                    root.dropHover = drag.hasUrls;
                    if (drag.hasUrls) drag.accept(Qt.CopyAction);
                }
                onExited: root.dropHover = false
                onDropped: (drop) => {
                    root.dropHover = false;
                    let files = root.fileUrlsToPaths(drop.urls);
                    if (files.length === 0) return;
                    root.sendFiles(files);
                    drop.accept(Qt.CopyAction);
                }
            }
        }
    }

    component IconButton: Rectangle {
        id: ib
        property string icon: ""
        property string tip: ""
        property color accent: mocha.text
        property bool spinning: false
        property bool highlighted: false
        signal triggered()

        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Math.min(root.itemRadius, 16)
        color: ibMouse.containsMouse || highlighted
            ? Qt.rgba(accent.r, accent.g, accent.b, highlighted ? 0.24 : 0.20)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        scale: ibMouse.pressed ? 0.94 : (ibMouse.containsMouse ? 1.07 : 1.0)
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Text {
            id: ibGlyph
            anchors.centerIn: parent
            text: ib.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: 15
            color: ib.accent
            RotationAnimation on rotation {
                running: ib.spinning
                from: 0; to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running) ibGlyph.rotation = 0
            }
        }
        MouseArea {
            id: ibMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.triggered()
        }
    }

    component SmallButton: Rectangle {
        id: sb
        property string icon: ""
        property color accent: mocha.text
        signal triggered()
        width: 24
        height: 24
        radius: 12
        color: sbMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.22)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Text {
            anchors.centerIn: parent
            text: sb.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: 12
            color: sbMouse.containsMouse ? sb.accent : mocha.subtext0
        }
        MouseArea {
            id: sbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sb.triggered()
        }
    }

    component InfoChip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        property color tint: mocha.text
        width: chipRow.implicitWidth + 16
        height: 24
        radius: height / 2
        color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 12
                color: chip.tint
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                font.weight: Font.Medium
                color: mocha.text
            }
        }
    }

    component PillButton: Rectangle {
        id: pill
        property string label: ""
        property string icon: ""
        property color accent: mocha.primary
        property bool primary: false
        property bool working: false
        signal triggered()
        Layout.preferredHeight: 32
        Layout.preferredWidth: pillRow.implicitWidth + 24
        radius: 16
        color: primary
            ? Qt.rgba(accent.r, accent.g, accent.b, pillMouse.containsMouse ? 0.34 : 0.24)
            : Qt.rgba(accent.r, accent.g, accent.b, pillMouse.containsMouse ? 0.18 : 0.08)
        border.width: 1
        border.color: Qt.rgba(accent.r, accent.g, accent.b, primary ? 0.55 : 0.25)
        scale: pillMouse.pressed ? 0.96 : 1.0
        opacity: working ? 0.7 : 1
        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                id: pillGlyph
                anchors.verticalCenter: parent.verticalCenter
                text: pill.working ? "󰑐" : pill.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 13
                color: pill.accent
                RotationAnimation on rotation {
                    running: pill.working
                    from: 0; to: 360; duration: 900
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) pillGlyph.rotation = 0
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: mocha.text
            }
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!pill.working) pill.triggered()
        }
    }

    // Tegel met icoon en label; draait tijdens het werk en toont kort een
    // vinkje als het gelukt is.
    component ActionTile: Rectangle {
        id: tile
        property string action: ""
        property string icon: ""
        property string label: ""
        property string tip: ""
        property color accent: mocha.primary
        property bool dimmed: false
        property bool toggled: false
        readonly property bool working: root.busy === action
        readonly property bool success: root.done === action
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: 66
        radius: Math.min(root.itemRadius, 16)
        color: toggled || success
            ? Qt.rgba((success ? mocha.green : accent).r, (success ? mocha.green : accent).g, (success ? mocha.green : accent).b, 0.22)
            : (tileMouse.containsMouse
                ? Qt.rgba(accent.r, accent.g, accent.b, 0.14)
                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05))
        border.width: 1
        border.color: tileMouse.containsMouse || toggled
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.50)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
        scale: tileMouse.pressed ? 0.95 : (tileMouse.containsMouse ? 1.03 : 1.0)
        opacity: dimmed ? 0.5 : 1
        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 8
            spacing: 4
            Text {
                id: tileGlyph
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.success ? "󰄬" : (tile.working ? "󰑐" : tile.icon)
                font.family: ThemeConfig.iconFont
                font.pixelSize: 20
                color: tile.success ? mocha.green
                    : (tileMouse.containsMouse || tile.toggled ? tile.accent : mocha.subtext1)
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                RotationAnimation on rotation {
                    running: tile.working
                    from: 0; to: 360; duration: 900
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) tileGlyph.rotation = 0
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: tileMouse.containsMouse || tile.toggled ? mocha.text : mocha.subtext0
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
            }
        }

        // Uitleg bij hover, onder in de tegel.
        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!tile.working) tile.triggered()
        }
        ToolTipText { shown: tileMouse.containsMouse && tile.tip !== ""; tipText: tile.tip }
    }

    // Eenvoudige hint-ballon boven de tegel (geen QtQuick.Controls nodig).
    component ToolTipText: Rectangle {
        id: tipBox
        property bool shown: false
        property string tipText: ""
        z: 50
        width: Math.min(220, tipLabel.implicitWidth + 16)
        height: tipLabel.implicitHeight + 10
        radius: 8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        color: mocha.crust
        border.width: 1
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: tipBox.shown ? 450 : 0 }
                NumberAnimation { duration: ThemeConfig.durationToken("fast") }
            }
        }
        Text {
            id: tipLabel
            anchors.centerIn: parent
            width: Math.min(204, implicitWidth)
            text: tipBox.tipText
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            font.family: ThemeConfig.uiFont
            font.pixelSize: 10
            color: mocha.text
        }
    }

}
