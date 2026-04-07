// =============================================================================
// shell.qml — Quickshell entry point — kingstra-dots
// =============================================================================
// Laadt TopBar (per scherm) en Main (popup master window) tegelijk.
// Start met: quickshell -p ~/.config/quickshell/shell.qml
// =============================================================================
import QtQuick
import Quickshell

ShellRoot {
    // Topbar — één per scherm (zit al in TopBar.qml als Variants)
    Loader { source: "TopBar.qml" }

    // Popup master window (wallpaper picker, music, network, etc.)
    Loader { source: "Main.qml" }
}
