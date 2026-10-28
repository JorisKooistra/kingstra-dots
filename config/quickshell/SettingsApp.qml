//@ pragma AppId kingstra-settings
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded

import QtQuick
import Quickshell
import "settings"

// Kingstra Instellingen als eigen app: een apart quickshell-proces met
// app-id "kingstra-settings", los van de bar (TopBar.qml) en de popups
// (Main.qml). Starten via hypr/scripts/settings-app.sh (Super+, of de
// launcher); het venster sluiten stopt dit proces.
ShellRoot {
    // Zelfde reden als in TopBar.qml: QSettings wil een organisatienaam.
    Component.onCompleted: {
        Qt.application.organization = "kingstra-shell";
    }

    SettingsWindow {}
}
