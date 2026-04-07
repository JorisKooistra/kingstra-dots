// =============================================================================
// shell.qml — Quickshell entry point — kingstra-dots
// =============================================================================
// Start met: quickshell -p ~/.config/quickshell/shell.qml
// =============================================================================
import Quickshell
import Quickshell.Wayland
import "./bar" as Bar

ShellRoot {
    // Maak voor elke monitor een eigen topbar aan
    Variants {
        model: Quickshell.screens

        Bar.Bar {
            screen: modelData
        }
    }
}
