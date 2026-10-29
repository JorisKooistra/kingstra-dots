import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

// Eén toetsenbordmenu voor alles, zoals het menu van Omarchy (Super+Alt+
// Spatie). Een boom: pijltjes kiezen, Enter of → opent, ← of
// Backspace gaat terug, typen filtert de huidige lijst. Alle acties lopen via
// de bestaande scripts (kingstra, qs_manager, ...), dus er is geen tweede pad
// voor shell-state.
//
// FocusScope: de PanelHost geeft de focus door aan deze scope (zie
// LauncherPanel voor waarom een gewoon Item daar niet werkt).
FocusScope {
    id: root

    MatugenColors { id: mocha }

    readonly property string home: Quickshell.env("HOME")
    readonly property string scripts: home + "/.config/hypr/scripts"
    readonly property int rowRadius: Math.max(12, ThemeConfig.styleWidgetRadius)

    function qs(target, sub) {
        return ["bash", scripts + "/qs_manager.sh", "toggle", target].concat(sub ? [sub] : []);
    }
    function kingstra(args) {
        return ["bash", "-lc", "PATH=\"$HOME/.local/bin:$PATH\" kingstra " + args];
    }
    function inTerminal(cmd) {
        return ["kitty", "--hold", "bash", "-lc", cmd];
    }

    // Elk item: label, icon, en óf children (submenu) óf cmd (argv).
    // panel: true betekent dat de actie zelf een paneel opent; dan sluit
    // dit menu niet eerst via qs_manager close (dat zou het paneel weer
    // dichtdoen).
    readonly property var tree: [
        { icon: "󱓞", label: "Apps", hint: "Launcher", cmd: qs("launcher"), panel: true },
        { icon: "󰊢", label: "Werkruimte-overzicht", hint: "Super+Tab", cmd: ["bash", scripts + "/overview-toggle.sh"] },
        { icon: "󰕰", label: "Vensters", children: [
            { icon: "󰕰", label: "Indeling kiezen", hint: "Super+Z", cmd: qs("snap"), panel: true },
            { icon: "󰁔", label: "Scrollen aan of uit", hint: "Super+Alt+S", cmd: ["bash", scripts + "/layout-tool.sh", "scroll"] },
            { icon: "󰕴", label: "Terug naar tegels", cmd: ["bash", scripts + "/layout-tool.sh", "apply", "tegels"] },
            { icon: "󰠮", label: "Kladblok tonen", hint: "Super+`", cmd: ["bash", scripts + "/scratchpad.sh", "toggle"] },
            { icon: "󰁝", label: "Venster naar kladblok", hint: "Super+Shift+`", cmd: ["bash", scripts + "/scratchpad.sh", "send"] },
            { icon: "󰖰", label: "Venster parkeren", hint: "Super+-", cmd: ["python3", scripts + "/park-window.py", "park"] },
            { icon: "󰖯", label: "Geparkeerd venster terug", hint: "Super+Shift+-", cmd: ["python3", scripts + "/park-window.py", "last"] },
            { icon: "󰐃", label: "Op alle werkruimtes vastzetten", cmd: ["hyprctl", "dispatch", "hl.dsp.window.pin()"] },
            { icon: "󰓩", label: "Venster uit groep halen", cmd: ["hyprctl", "dispatch", "hl.dsp.group.move_window({ action = \"out\" })"] },
            { icon: "󰌾", label: "Groep vergrendelen of vrijgeven", cmd: ["hyprctl", "dispatch", "hl.dsp.group.lock_active({ action = \"toggle\" })"] }
        ] },
        { icon: "󰏘", label: "Uiterlijk", children: [
            { icon: "󰏘", label: "Thema", children: [
                { icon: "󰝤", label: "Mono", cmd: kingstra("theme mono") },
                { icon: "󰝤", label: "Mono accent", cmd: kingstra("theme mono-accent") },
                { icon: "󰝤", label: "Neon", cmd: kingstra("theme neon") },
                { icon: "󰝤", label: "Organic", cmd: kingstra("theme organic") },
                { icon: "󰝤", label: "Paper", cmd: kingstra("theme paper") },
                { icon: "󰑐", label: "Volgend thema", hint: "Super+Shift+T", cmd: ["bash", scripts + "/theme-next-safe.sh"] },
                { icon: "󰋩", label: "Themakiezer", hint: "Super+Ctrl+T", cmd: qs("theme"), panel: true }
            ] },
            { icon: "󰸉", label: "Achtergrond", children: [
                { icon: "󰋩", label: "Kiezer", hint: "Super+Ctrl+W", cmd: ["bash", scripts + "/wallpaper-picker-safe.sh"] },
                { icon: "󰒝", label: "Willekeurig", hint: "Super+Shift+W", cmd: ["bash", scripts + "/wallpaper-random-safe.sh"] }
            ] },
            { icon: "󰥔", label: "Bureaubladwidgets", children: [
                { icon: "󰔡", label: "Aan of uit", cmd: kingstra("widgets wissel") },
                { icon: "󰁜", label: "Klok linksboven", cmd: kingstra("widgets klok linksboven") },
                { icon: "󰁝", label: "Klok rechtsboven", cmd: kingstra("widgets klok rechtsboven") },
                { icon: "󰘞", label: "Klok in het midden", cmd: kingstra("widgets klok midden") },
                { icon: "󰁆", label: "Klok linksonder", cmd: kingstra("widgets klok linksonder") },
                { icon: "󰁅", label: "Klok rechtsonder", cmd: kingstra("widgets klok rechtsonder") },
                { icon: "󰝚", label: "Mediakaart aan", cmd: kingstra("widgets media aan") },
                { icon: "󰝛", label: "Mediakaart uit", cmd: kingstra("widgets media uit") }
            ] },
            { icon: "󰒓", label: "Thema-instellingen", cmd: ["bash", scripts + "/qs_manager.sh", "open", "settings", "thema"] }
        ] },
        { icon: "󰾅", label: "Modus", children: [
            { icon: "󰈙", label: "Office", cmd: kingstra("mode office") },
            { icon: "󰊴", label: "Gaming", cmd: kingstra("mode gaming") },
            { icon: "󰝚", label: "Media", cmd: kingstra("mode media") },
            { icon: "󰚀", label: "Zen aan of uit", hint: "Super+Alt+Z", cmd: ["bash", scripts + "/zen.sh", "toggle"] }
        ] },
        { icon: "󰒓", label: "Bediening (alles in één)", hint: "Super+A", cmd: qs("bediening"), panel: true },
        { icon: "󰕮", label: "Snel schakelen", children: [
            { icon: "󰕮", label: "Controlecentrum", cmd: qs("tophover"), panel: true },
            { icon: "󰤨", label: "Wi-Fi aan/uit", cmd: ["bash", "-lc", "[ \"$(nmcli radio wifi)\" = enabled ] && nmcli radio wifi off || nmcli radio wifi on"] },
            { icon: "󰂯", label: "Bluetooth aan/uit", cmd: ["bash", home + "/.config/quickshell/network/bluetooth_panel_logic.sh", "--toggle"] },
            { icon: "󰤨", label: "Netwerk beheren (nmtui)", cmd: ["kitty", "--title=Network", "nmtui"] },
            { icon: "󰂱", label: "Bluetooth-apparaten", cmd: ["blueman-manager"] },
            { icon: "󰂛", label: "Niet storen aan/uit", cmd: ["bash", home + "/.config/quickshell/notifications/notification_control.sh", "dnd"] },
            { icon: "󰓅", label: "Energieprofiel", children: [
                { icon: "󰌪", label: "Energiebesparing", cmd: ["powerprofilesctl", "set", "power-saver"] },
                { icon: "󰾅", label: "Gebalanceerd", cmd: ["powerprofilesctl", "set", "balanced"] },
                { icon: "󰓅", label: "Prestaties", cmd: ["powerprofilesctl", "set", "performance"] }
            ] }
        ] },
        { icon: "󰍹", label: "Schermen", children: [
            { icon: "󰍹", label: "Schermindeling", cmd: qs("monitors"), panel: true },
            { icon: "󰓶", label: "Tabletmodus aan/uit", cmd: ["bash", scripts + "/tablet-mode.sh", "toggle"] }
        ] },
        { icon: "󰄀", label: "Vastleggen", children: [
            { icon: "󰹑", label: "Schermafbeelding van gebied", hint: "Print", cmd: ["bash", scripts + "/screenshot.sh"] },
            { icon: "󰍹", label: "Schermafbeelding van scherm", hint: "Super+Shift+P", cmd: ["bash", scripts + "/screenshot.sh", "--full"] },
            { icon: "󰏫", label: "Schermafbeelding met notities", hint: "Shift+Print", cmd: ["bash", scripts + "/screenshot.sh", "--annotate"] },
            { icon: "󰈊", label: "Kleur kiezen", cmd: ["bash", "-lc", "command -v hyprpicker >/dev/null && hyprpicker -a"] },
            { icon: "󰅌", label: "Klembord", hint: "Super+V", cmd: qs("clipboard"), panel: true }
        ] },
        { icon: "󰒓", label: "Systeem", children: [
            { icon: "󰒓", label: "Instellingen", hint: "Super+Ctrl+I", cmd: ["bash", scripts + "/qs_manager.sh", "open", "settings"] },
            { icon: "󰚰", label: "Bijwerken", cmd: inTerminal("kingstra update") },
            { icon: "󰓙", label: "Controleren (doctor)", cmd: inTerminal("kingstra doctor") },
            { icon: "󰁯", label: "Terugzetpunt maken", cmd: inTerminal("kingstra snapshot create") },
            { icon: "󰑓", label: "Shell herstarten", cmd: kingstra("restart") },
            { icon: "󰃭", label: "Kalender", cmd: qs("calendar"), panel: true },
            { icon: "󱎫", label: "FocusTime", cmd: qs("focustime"), panel: true },
            { icon: "󰊴", label: "Games", cmd: ["quickshell-game"] },
            { icon: "󰉋", label: "Yazi (bestanden in terminal)", cmd: ["kitty", "--title=yazi", "yazi"] },
            { icon: "󰍛", label: "Systeemmonitor", cmd: ["kitty", "--title", "btop — Kingstra", "bash", "-lc", "exec btop"] }
        ] },
        { icon: "󰐥", label: "Sessie", children: [
            { icon: "󰌾", label: "Vergrendelen", hint: "Super+Ctrl+L", cmd: ["bash", scripts + "/lock.sh"] },
            { icon: "󰤄", label: "Slaapstand", cmd: ["bash", scripts + "/suspend.sh"] },
            { icon: "󰜉", label: "Opnieuw opstarten", cmd: ["systemctl", "reboot"] },
            { icon: "󰐥", label: "Uitschakelen", cmd: ["systemctl", "poweroff"] },
            { icon: "󰍃", label: "Afsluitmenu", cmd: qs("power"), panel: true }
        ] },
        { icon: "󰋖", label: "Sneltoetsen", hint: "Super+F1", cmd: qs("help"), panel: true }
    ]

    // Pad door de boom: lijst van indexen in de ongefilterde lijsten.
    property var path: []
    property string filter: ""
    property int selectedIndex: 0

    readonly property var currentLevel: {
        let level = tree;
        for (let i = 0; i < path.length; i++) level = level[path[i]].children;
        return level;
    }
    readonly property var crumbs: {
        let out = [];
        let level = tree;
        for (let i = 0; i < path.length; i++) {
            out.push(level[path[i]].label);
            level = level[path[i]].children;
        }
        return out;
    }
    // Zichtbare items met hun index in currentLevel.
    readonly property var visibleItems: {
        let q = filter.trim().toLowerCase();
        let out = [];
        for (let i = 0; i < currentLevel.length; i++) {
            let it = currentLevel[i];
            if (q === "" || String(it.label).toLowerCase().indexOf(q) !== -1)
                out.push({ item: it, index: i });
        }
        return out;
    }
    onVisibleItemsChanged: selectedIndex = Math.min(selectedIndex, Math.max(0, visibleItems.length - 1))

    function closeMenu() {
        Quickshell.execDetached(["bash", scripts + "/qs_manager.sh", "close"]);
    }

    function activate(entry) {
        if (!entry) return;
        let it = entry.item;
        if (it.children) {
            path = path.concat([entry.index]);
            filter = "";
            selectedIndex = 0;
            return;
        }
        if (!it.panel) closeMenu();
        Quickshell.execDetached(it.cmd);
    }

    function back() {
        if (filter !== "") { filter = ""; return; }
        if (path.length === 0) { closeMenu(); return; }
        let last = path[path.length - 1];
        path = path.slice(0, path.length - 1);
        filter = "";
        // Terug op het item waar je vandaan kwam.
        selectedIndex = last;
    }

    function move(delta) {
        let n = visibleItems.length;
        if (n === 0) return;
        selectedIndex = (selectedIndex + delta + n) % n;
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    focus: true
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) { root.closeMenu(); event.accepted = true; return; }
        if (event.key === Qt.Key_Down) { root.move(1); event.accepted = true; return; }
        if (event.key === Qt.Key_Up) { root.move(-1); event.accepted = true; return; }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) {
            root.activate(root.visibleItems[root.selectedIndex]);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Left) { root.back(); event.accepted = true; return; }
        if (event.key === Qt.Key_Backspace) {
            if (root.filter !== "") root.filter = root.filter.substring(0, root.filter.length - 1);
            else root.back();
            event.accepted = true;
            return;
        }
        // Cijfer 1-9 kiest direct, zoals in een klassiek menu.
        if (root.filter === "" && event.text >= "1" && event.text <= "9" && event.text.length === 1) {
            let i = parseInt(event.text) - 1;
            if (i < root.visibleItems.length) root.activate(root.visibleItems[i]);
            event.accepted = true;
            return;
        }
        if (event.text !== "" && event.text.trim() !== "" && !(event.modifiers & Qt.ControlModifier)) {
            root.filter += event.text;
            root.selectedIndex = 0;
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Kop: kruimelpad en filter.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰍜"
                font.family: ThemeConfig.iconFont
                font.pixelSize: 16
                color: mocha.primary
            }
            Text {
                Layout.fillWidth: true
                text: ["Kingstra"].concat(root.crumbs).join("  ›  ")
                font.family: ThemeConfig.displayFont
                font.pixelSize: 15
                font.weight: Font.Black
                color: mocha.text
                elide: Text.ElideLeft
            }
            Rectangle {
                visible: root.filter !== ""
                implicitWidth: filterText.implicitWidth + 18
                implicitHeight: 24
                radius: 12
                color: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.18)
                Text {
                    id: filterText
                    anchors.centerIn: parent
                    text: "󰍉 " + root.filter
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 11
                    color: mocha.text
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.visibleItems
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property int index
                required property var modelData
                readonly property var it: modelData.item
                readonly property bool current: index === root.selectedIndex

                width: list.width
                height: 40
                radius: root.rowRadius
                color: current
                    ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.26)
                    : (rowMouse.containsMouse ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.12) : "transparent")
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        Layout.preferredWidth: 16
                        text: row.index < 9 && root.filter === "" ? String(row.index + 1) : ""
                        font.family: ThemeConfig.monoFont
                        font.pixelSize: 10
                        color: mocha.subtext0
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        text: row.it.icon
                        font.family: ThemeConfig.iconFont
                        font.pixelSize: 16
                        color: row.current ? mocha.primary : mocha.subtext1
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.it.label
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 13
                        font.weight: row.current ? Font.Bold : Font.DemiBold
                        color: mocha.text
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: !!row.it.hint
                        text: row.it.hint || ""
                        font.family: ThemeConfig.monoFont
                        font.pixelSize: 10
                        color: mocha.subtext0
                    }
                    Text {
                        visible: !!row.it.children
                        text: "󰅂"
                        font.family: ThemeConfig.iconFont
                        font.pixelSize: 14
                        color: row.current ? mocha.text : mocha.subtext0
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = row.index
                    onClicked: root.activate(row.modelData)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "↑↓ kiezen  ·  Enter of → openen  ·  ← terug  ·  typen filtert  ·  1-9 direct"
            font.family: ThemeConfig.uiFont
            font.pixelSize: 10
            color: mocha.subtext0
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
