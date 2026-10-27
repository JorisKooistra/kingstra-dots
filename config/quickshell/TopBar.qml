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

    BarShell {}
    ShellSurface {}
    VolumeBarPopup {}

    // Instellingen als eigen venster. Via LazyLoader met een bron-URL: een
    // fout in dat venster laat de bar en de surface gewoon starten.
    LazyLoader {
        active: true
        source: "settings/SettingsWindow.qml"
    }

    // Klok en media op het bureaublad; zelfde isolatie als hierboven.
    LazyLoader {
        active: true
        source: "desktop/DesktopWidgets.qml"
    }
}
