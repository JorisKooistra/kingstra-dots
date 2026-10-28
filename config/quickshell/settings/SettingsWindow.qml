import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Instellingen als eigen app, zoals de settings-app van GNOME, KDE en
// end-4. Draait in een eigen quickshell-proces (SettingsApp.qml) met app-id
// "kingstra-settings": een gewoon venster dat je verplaatst, naast een app
// tegelt (Super+T), in Alt-tab en het overzicht terugvindt, en dat ook werkt
// als de bar gecrasht is. Hyprland opent hem zwevend en gecentreerd (regel
// "kingstra-settings" in hypr/lua/rules.lua). Venster dicht = proces stopt.
//
// Starten loopt via hypr/scripts/settings-app.sh. De eerste pagina komt uit
// KINGSTRA_SETTINGS_PAGE; verzoeken aan een draaiende app komen via
// /tmp/kingstra-settings-request: "<actie>:<pagina>:<nonce>", met actie
// open, toggle of close en een optionele pagina (thema, geluid, ...).
Scope {
    id: root

    property string pendingPage: Quickshell.env("KINGSTRA_SETTINGS_PAGE") || ""
    // Bij het starten staat de vorige request nog in de file; de eerste read
    // is alleen de uitgangspositie, de startpagina komt uit de omgeving.
    property bool primed: false
    property bool quitting: false
    readonly property string appId: "kingstra-settings"

    MatugenColors { id: mocha }

    function focusWindow() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/hypr-dispatch.sh",
            "focuswindow", "class:^(" + appId + ")$"]);
    }

    function quit() {
        if (quitting) return;
        quitting = true;
        settingsWindow.visible = false;
        Qt.quit();
    }

    function requestClose() {
        let item = settingsLoader.item;
        if (item) item.animateClose();
        else quit();
    }

    function handleRequest(raw) {
        if (!primed) {
            primed = true;
            return;
        }
        let parts = String(raw || "").trim().split(":");
        let action = parts[0] || "";
        let page = parts.length > 1 ? parts[1] : "";

        if (action === "close" || (action === "toggle" && page === "")) {
            requestClose();
            return;
        }
        if (action !== "open" && action !== "toggle") return;
        let item = settingsLoader.item;
        if (page !== "" && item) item.openNamedPage(page);
        focusWindow();
    }

    // Een nieuw venster krijgt in Hyprland meestal zelf focus; dit is het
    // vangnet voor als een ander venster of paneel hem net voor was.
    Timer {
        id: focusTimer
        interval: 120
        running: true
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
        visible: true
        title: "Kingstra Instellingen"
        implicitWidth: 1120
        implicitHeight: 740
        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, Math.max(0.92, ThemeConfig.popupOpacity))

        // Sluiten via Hyprland (Super+Q of de muis) zet visible zelf uit;
        // dan is de app klaar.
        onVisibleChanged: if (!visible) root.quit()

        Loader {
            id: settingsLoader
            anchors.fill: parent
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
            function onCloseRequested() { root.quit(); }
        }
    }
}
