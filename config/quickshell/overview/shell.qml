//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QPA_PLATFORMTHEME=

import QtQuick
import Quickshell

// Keep the local overview directory as a user config overlay only. The actual
// module remains package-managed by quickshell-overview-git under /etc/xdg.
import "file:/etc/xdg/quickshell/overview/modules/overview"

ShellRoot {
    Overview {}
}
