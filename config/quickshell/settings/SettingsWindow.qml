import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Instellingen als echt venster, zoals de settings-app van GNOME, KDE en
// end-4: verplaatsen, naast een app tegelen, op elk scherm openen, en hij
// blijft open als je ergens anders klikt. Hyprland laat hem zwevend en
// gecentreerd openen (regel "kingstra-settings" in hypr/lua/rules.lua).
//
// Openen loopt via qs_manager.sh, dat een regel in
// /tmp/kingstra-settings-request schrijft: "<actie>:<pagina>:<nonce>".
// Actie is open of toggle; pagina is optioneel (thema, geluid, ...).
Scope {
    id: root

    property bool shown: false
    property string pendingPage: ""
    // De request-file overleeft een shell-herstart; de eerste read is alleen
    // de uitgangspositie, anders gaat het venster bij elke login open.
    property bool primed: false
    readonly property string windowTitle: "Kingstra Instellingen"

    MatugenColors { id: mocha }

    // Imperatief, geen binding: sluit Hyprland het venster, dan zet
    // Quickshell visible zelf uit en zou een binding breken.
    onShownChanged: settingsWindow.visible = shown

    function focusWindow() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/hypr-dispatch.sh",
            "focuswindow", "title:^(" + windowTitle + ")$"]);
    }

    function handleRequest(raw) {
        if (!primed) {
            primed = true;
            return;
        }
        let parts = String(raw || "").trim().split(":");
        let action = parts[0] || "";
        let page = parts.length > 1 ? parts[1] : "";
        if (action !== "open" && action !== "toggle") return;

        if (shown) {
            let item = settingsLoader.item;
            if (page !== "") {
                if (item) item.openNamedPage(page);
                focusWindow();
            } else if (action === "toggle") {
                if (item) item.animateClose();
                else shown = false;
            } else {
                focusWindow();
            }
            return;
        }
        pendingPage = page;
        shown = true;
        focusTimer.restart();
    }

    // Hyprland geeft een quickshell-venster standaard geen focus bij openen;
    // even wachten tot het venster gemapt is en dan zelf focussen.
    Timer {
        id: focusTimer
        interval: 120
        onTriggered: root.focusWindow()
    }

    FileView {
        id: requestView
        path: "/tmp/kingstra-settings-request"
        watchChanges: true
        preload: true
        onInternalTextChanged: root.handleRequest(__text)
        onLoadFailed: root.primed = true
    }
    Timer {
        // Zelfde vangnet als de shell-surface: FileView mist soms een write.
        interval: 200
        running: true
        repeat: true
        onTriggered: requestView.reload()
    }

    FloatingWindow {
        id: settingsWindow
        visible: false
        title: root.windowTitle
        implicitWidth: 1120
        implicitHeight: 740
        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, Math.max(0.92, ThemeConfig.popupOpacity))

        // Sluiten via Hyprland (Super+Q of de muis) zet visible zelf uit.
        onVisibleChanged: if (!visible) root.shown = false

        Loader {
            id: settingsLoader
            anchors.fill: parent
            active: root.shown
            focus: true
            source: "SettingsPopup.qml"
            onLoaded: {
                item.windowed = true;
                if (root.pendingPage !== "") item.openNamedPage(root.pendingPage);
                root.pendingPage = "";
                item.forceActiveFocus();
            }
        }

        Connections {
            target: settingsLoader.item
            ignoreUnknownSignals: true
            function onCloseRequested() { root.shown = false; }
        }
    }
}
