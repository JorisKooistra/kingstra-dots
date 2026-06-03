//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded

import QtQuick
import Quickshell
import "bar"
import "volume"

ShellRoot {
    BarShell {}
    VolumeBarPopup {}
}
