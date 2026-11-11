//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QPA_PLATFORMTHEME=

import QtQuick
import Quickshell
import Quickshell.Io
import "bar"
import "shellsurface"
import "volume"

ShellRoot {
    property var notificationService: NotificationService

    // QSettings (QML Settings-type) vereist een organisatienaam; zonder deze
    // faalt de init en persisteert o.a. de audio-cache niet.
    Component.onCompleted: {
        Qt.application.organization = "kingstra-shell";
    }

    LazyLoader { active: true; source: "settings/SpatialOverviewWindow.qml" }
    LazyLoader { active: true; source: "desktop/SpatialDrift.qml" }
    LazyLoader { active: true; source: "desktop/SpatialZoomControl.qml" }

    // Zacht herladen: Quickshell herlaadt de QML in hetzelfde proces en
    // hergebruikt de bestaande vensters. De ruimtereserveringen blijven dan
    // staan, dus vensters springen niet omhoog en weer terug zoals bij
    // stoppen en opnieuw starten. Instellingen › "Alleen de bar herladen"
    // roept dit aan via `quickshell ipc -p TopBar.qml call shell reload`.
    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(false) }
        // Thema meteen opnieuw inlezen (kingstra-theme-switch roept dit aan
        // vlak vóór het zetten van Hyprlands gaps), zodat strip en gaps in
        // één beweging veranderen in plaats van seconden na elkaar.
        function rereadTheme(): void { ThemeConfig.rereadThemeFile() }
    }

    BarShell {}
    ShellSurface {}
    VolumeBarPopup {}

    // Instellingen is een eigen app in een eigen proces (SettingsApp.qml,
    // gestart via hypr/scripts/settings-app.sh), niet meer deel van de bar.

    // Klok en media op het bureaublad. Via LazyLoader met een bron-URL: een
    // fout daar laat de bar en de surface gewoon starten.
    LazyLoader {
        active: true
        source: "desktop/DesktopWidgets.qml"
    }
}
