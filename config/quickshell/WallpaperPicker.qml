//@ pragma AppId kingstra-wallpaper-picker
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QPA_PLATFORMTHEME=
import Quickshell
import "wallpaper"

ShellRoot {
    PickerWindow {}
}
