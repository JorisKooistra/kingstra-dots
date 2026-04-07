// =============================================================================
// shell.qml — Quickshell entry point — kingstra-dots
// =============================================================================
// Start met: quickshell -p ~/.config/quickshell/shell.qml
// =============================================================================
import Quickshell
import Quickshell.Wayland
import "./bar"

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }
}
