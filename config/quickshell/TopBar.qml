//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded

import QtQuick
import Quickshell
import "bar"
import "volume"

ShellRoot {
    // QSettings (QML Settings-type) vereist een organisatienaam; zonder deze
    // faalt de init en persisteert o.a. de audio-cache in VolumePopup niet.
    Component.onCompleted: {
        Qt.application.organization = "kingstra";
    }

    BarShell {}
    VolumeBarPopup {}
}
