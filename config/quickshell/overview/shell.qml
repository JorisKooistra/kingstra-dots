//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QPA_PLATFORMTHEME=

import QtQuick
import Quickshell

import "./modules/overview"

ShellRoot {
    Overview {}
}
