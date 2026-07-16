import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

// =============================================================================
// KeybindsHelp — Sneltoetsen-cheatsheet (Super + F1)
// =============================================================================
// Leest de actieve binds via settings/read_keybinds.sh (dezelfde bron als de
// settings-app) en toont ze gegroepeerd per categorie. Bedoeld als eerste
// hulplijn voor nieuwe gebruikers: alles is te vinden zonder documentatie.
// =============================================================================
Item {
    id: window
    anchors.fill: parent
    clip: true
    focus: true

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }
    function sf(val, minimumPx) { return Math.max(minimumPx, scaler.s(val)); }

    MatugenColors { id: _theme }

    property bool isReady: false
    property var groupedBinds: []
    property string searchText: ""

    readonly property var categoryOrder: ["core", "apps", "widgets", "media", "screenshots", "special", "passthrough"]
    readonly property var categoryLabels: ({
        "core":        { icon: "", label: I18n.t("keybinds_cat_core", "Vensters & werkruimtes") },
        "apps":        { icon: "", label: I18n.t("keybinds_cat_apps", "Applicaties") },
        "widgets":     { icon: "", label: I18n.t("keybinds_cat_widgets", "Panelen & widgets") },
        "media":       { icon: "", label: I18n.t("keybinds_cat_media", "Media & volume") },
        "screenshots": { icon: "", label: I18n.t("keybinds_cat_screenshots", "Screenshots") },
        "special":     { icon: "", label: I18n.t("keybinds_cat_special", "Scratchpads") },
        "passthrough": { icon: "", label: I18n.t("keybinds_cat_passthrough", "Passthrough (Citrix/VM)") }
    })

    function prettyMods(mods) {
        if (!mods) return "";
        return mods
            .replace("$mainMod", "Super")
            .replace("SHIFT", "Shift")
            .replace("CTRL", "Ctrl")
            .replace("ALT", "Alt")
            .replace("SUPER", "Super")
            .split(/\s+/).filter(function(p) { return p !== ""; }).join(" + ");
    }

    function prettyKey(key) {
        const map = {
            "left": "←", "right": "→", "up": "↑", "down": "↓",
            "Escape": "Esc", "Return": "Enter", "Backspace": "⌫",
            "mouse:272": I18n.t("keybinds_mouse_left", "Muis-links"),
            "mouse:273": I18n.t("keybinds_mouse_right", "Muis-rechts"),
            "mouse_down": I18n.t("keybinds_scroll_down", "Scroll ↓"),
            "mouse_up": I18n.t("keybinds_scroll_up", "Scroll ↑"),
            "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −",
            "XF86AudioMute": "Mute", "XF86AudioMicMute": "Mic mute",
            "XF86MonBrightnessUp": "Helderheid +", "XF86MonBrightnessDown": "Helderheid −",
            "XF86AudioPlay": "Play", "XF86AudioPause": "Pause",
            "XF86AudioNext": "Volgende", "XF86AudioPrev": "Vorige", "XF86AudioStop": "Stop"
        };
        return map[key] !== undefined ? map[key] : key;
    }

    function chipText(bind) {
        const mods = prettyMods(bind.mods);
        const key = prettyKey(bind.key);
        return mods !== "" ? (mods + " + " + key) : key;
    }

    function matchesSearch(bind) {
        if (searchText === "") return true;
        const needle = searchText.toLowerCase();
        return (bind.label || "").toLowerCase().indexOf(needle) !== -1
            || chipText(bind).toLowerCase().indexOf(needle) !== -1;
    }

    function regroup(binds) {
        let byCat = {};
        for (let i = 0; i < binds.length; i++) {
            const b = binds[i];
            if (!b || b.bound === false || !b.label) continue;
            const cat = b.cat || "core";
            if (!byCat[cat]) byCat[cat] = [];
            byCat[cat].push(b);
        }

        let groups = [];
        const seen = {};
        const pushCat = function(cat) {
            if (seen[cat] || !byCat[cat] || byCat[cat].length === 0) return;
            seen[cat] = true;
            const meta = categoryLabels[cat] || { icon: "", label: cat };
            groups.push({ cat: cat, icon: meta.icon, label: meta.label, binds: byCat[cat] });
        };
        for (let j = 0; j < categoryOrder.length; j++) pushCat(categoryOrder[j]);
        for (const other in byCat) pushCat(other);
        return groups;
    }

    property var allBinds: []

    Process {
        id: bindsLoader
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/settings/read_keybinds.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[KeybindsHelp] stream finished, bytes:", (this.text || "").length);
                try {
                    window.allBinds = JSON.parse(this.text || "[]");
                } catch (e) {
                    console.log("[KeybindsHelp] JSON parse error:", e);
                    window.allBinds = [];
                }
                window.groupedBinds = window.regroup(window.allBinds);
                console.log("[KeybindsHelp] groups:", window.groupedBinds.length);
                window.isReady = true;
            }
        }
    }

    onSearchTextChanged: {
        groupedBinds = regroup(allBinds.filter(matchesSearch));
    }

    Component.onCompleted: {
        bindsLoader.running = true;
        window.forceActiveFocus();
        searchField.forceActiveFocus();
    }

    Timer {
        interval: 1500; running: true
        onTriggered: console.log("[KeybindsHelp] size:", window.width, "x", window.height,
                                 "ready:", window.isReady,
                                 "header:", header.x, header.y, header.width, header.height, header.opacity,
                                 "visible:", window.visible, "opacity:", window.opacity)
    }

    Rectangle {
        anchors.fill: parent
        radius: window.s(18)
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.92)
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.8)
        border.width: 1
    }

    // ── Titelbalk + zoekveld ────────────────────────────────────────────────
    Column {
        id: header
        anchors.top: parent.top
        anchors.topMargin: window.s(24)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: window.s(14)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: window.s(10)

            Text {
                text: ""
                font.pixelSize: window.sf(22, 22)
                font.family: "Iosevka Nerd Font"
                color: _theme.blue
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: I18n.t("keybinds_title", "Sneltoetsen")
                font.pixelSize: window.sf(20, 20)
                font.bold: true
                color: _theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: window.s(420)
            height: window.sf(40, 40)
            radius: window.s(10)
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.85)
            border.color: searchField.activeFocus
                ? Qt.rgba(_theme.blue.r, _theme.blue.g, _theme.blue.b, 0.9)
                : Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.6)
            border.width: 1

            Text {
                text: ""
                font.family: "Iosevka Nerd Font"
                font.pixelSize: window.sf(14, 14)
                color: _theme.subtext0
                anchors.left: parent.left
                anchors.leftMargin: window.s(12)
                anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
                id: searchField
                anchors.fill: parent
                anchors.leftMargin: window.s(36)
                anchors.rightMargin: window.s(12)
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: window.sf(14, 14)
                color: _theme.text
                clip: true
                onTextChanged: window.searchText = text

                Text {
                    visible: searchField.text === ""
                    text: I18n.t("keybinds_search", "Zoeken… (bijv. “screenshot”)")
                    font.pixelSize: window.sf(14, 14)
                    color: Qt.rgba(_theme.subtext0.r, _theme.subtext0.g, _theme.subtext0.b, 0.6)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Keys.onEscapePressed: {
                    if (searchField.text !== "") {
                        searchField.text = "";
                        event.accepted = true;
                    } else {
                        event.accepted = false;
                    }
                }
            }
        }
    }

    // ── Inhoud ──────────────────────────────────────────────────────────────
    Flickable {
        id: content
        anchors.top: header.bottom
        anchors.topMargin: window.s(18)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: hintBar.top
        anchors.leftMargin: window.s(28)
        anchors.rightMargin: window.s(16)
        anchors.bottomMargin: window.s(14)
        contentHeight: catFlow.height
        clip: true
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        ScrollBar.vertical: ScrollBar { }

        Flow {
            id: catFlow
            width: content.width - window.s(12)
            spacing: window.s(16)

            Repeater {
                model: window.groupedBinds

                delegate: Rectangle {
                    required property var modelData

                    width: Math.floor((catFlow.width - window.s(16)) / 2)
                    height: catColumn.height + window.s(24)
                    radius: window.s(14)
                    color: Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.55)
                    border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.4)
                    border.width: 1

                    Column {
                        id: catColumn
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: window.s(12)
                        spacing: window.s(6)

                        Row {
                            spacing: window.s(8)
                            Text {
                                text: modelData.icon
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: window.sf(15, 15)
                                color: _theme.blue
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.label
                                font.pixelSize: window.sf(14, 14)
                                font.bold: true
                                color: _theme.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Repeater {
                            model: modelData.binds

                            delegate: Row {
                                required property var modelData
                                spacing: window.s(10)
                                width: catColumn.width

                                Rectangle {
                                    width: chipLabel.width + window.s(16)
                                    height: window.sf(24, 24)
                                    radius: window.s(6)
                                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.9)
                                    border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.7)
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: chipLabel
                                        anchors.centerIn: parent
                                        text: window.chipText(modelData)
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: window.sf(11, 11)
                                        font.bold: true
                                        color: _theme.text
                                    }
                                }

                                Text {
                                    text: modelData.label || ""
                                    font.pixelSize: window.sf(12, 12)
                                    color: _theme.subtext1
                                    elide: Text.ElideRight
                                    width: parent.width - window.s(10) - (chipLabel.width + window.s(16))
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Hintbalk ────────────────────────────────────────────────────────────
    Rectangle {
        id: hintBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: window.s(14)
        anchors.horizontalCenter: parent.horizontalCenter
        height: window.sf(38, 38)
        width: hintRow.width + window.sf(28, 28)
        radius: window.sf(10, 10)
        color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.9)
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.6)
        border.width: 1
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: window.s(14)

            Row {
                spacing: window.sf(6, 6)
                Rectangle {
                    width: window.sf(38, 38); height: window.sf(22, 22); radius: window.sf(5, 5)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Esc"; font.pixelSize: window.sf(11, 11); color: _theme.text; font.bold: true }
                }
                Text { text: I18n.t("keybinds_hint_close", "Sluiten"); font.pixelSize: window.sf(12, 12); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: 1; height: window.sf(20, 20); color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5); anchors.verticalCenter: parent.verticalCenter }

            Text {
                text: I18n.t("keybinds_hint_docs", "Volledige lijst: docs/keybindings.md")
                font.pixelSize: window.sf(12, 12)
                color: Qt.rgba(_theme.subtext0.r, _theme.subtext0.g, _theme.subtext0.b, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Keys.onEscapePressed: {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
        event.accepted = true;
    }
}
