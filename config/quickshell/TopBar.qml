//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded

import QtQuick
import Quickshell
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
