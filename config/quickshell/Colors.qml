// =============================================================================
// Colors.qml — Kleurensysteem (Catppuccin Mocha fallback + matugen overlay)
// =============================================================================
pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var _data: ({})

    // Laad colors.json via bash Process in plaats van FileView
    property var _colorsContent: ""

    Component.onCompleted: {
        loadColors.running = true
    }

    Process {
        id: loadColors
        command: ["bash", "-c", "cat ~/.config/quickshell/colors.json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let content = this.text.trim()
                if (content) {
                    try { root._data = JSON.parse(content) } catch (e) {}
                }
                // Reload elke 5 seconden voor live updates
                reloadTimer.running = true
            }
        }
    }

    Timer {
        id: reloadTimer
        interval: 5000
        repeat: true
        onTriggered: loadColors.running = true
    }

    // ---------------------------------------------------------------------------
    // Material-kleuren — reactief op _data, fallback = Catppuccin Mocha
    // ---------------------------------------------------------------------------
    readonly property color primary:          _data.primary           ? Qt.color(_data.primary)           : Qt.color("#89b4fa")
    readonly property color onPrimary:        _data.on_primary        ? Qt.color(_data.on_primary)        : Qt.color("#1e1e2e")
    readonly property color primaryContainer: _data.primary_container ? Qt.color(_data.primary_container) : Qt.color("#313244")
    readonly property color secondary:        _data.secondary         ? Qt.color(_data.secondary)         : Qt.color("#cba6f7")
    readonly property color onSecondary:      _data.on_secondary      ? Qt.color(_data.on_secondary)      : Qt.color("#1e1e2e")
    readonly property color tertiary:         _data.tertiary          ? Qt.color(_data.tertiary)          : Qt.color("#f5c2e7")
    readonly property color error:            _data.error             ? Qt.color(_data.error)             : Qt.color("#f38ba8")
    readonly property color background:       _data.background        ? Qt.color(_data.background)        : Qt.color("#1e1e2e")
    readonly property color onBackground:     _data.on_background     ? Qt.color(_data.on_background)     : Qt.color("#cdd6f4")
    readonly property color surface:          _data.surface           ? Qt.color(_data.surface)           : Qt.color("#313244")
    readonly property color onSurface:        _data.on_surface        ? Qt.color(_data.on_surface)        : Qt.color("#cdd6f4")
    readonly property color surfaceVariant:   _data.surface_variant   ? Qt.color(_data.surface_variant)   : Qt.color("#45475a")
    readonly property color outline:          _data.outline           ? Qt.color(_data.outline)           : Qt.color("#6c7086")
    readonly property color outlineVariant:   _data.outline_variant   ? Qt.color(_data.outline_variant)   : Qt.color("#45475a")

    // ---------------------------------------------------------------------------
    // Catppuccin-namen
    // ---------------------------------------------------------------------------
    readonly property color text:     _data.text     ? Qt.color(_data.text)     : Qt.color("#cdd6f4")
    readonly property color subtext0: _data.subtext0 ? Qt.color(_data.subtext0) : Qt.color("#a6adc8")
    readonly property color overlay0: _data.overlay0 ? Qt.color(_data.overlay0) : Qt.color("#6c7086")
    readonly property color surface0: _data.surface0 ? Qt.color(_data.surface0) : Qt.color("#313244")
    readonly property color surface1: _data.surface1 ? Qt.color(_data.surface1) : Qt.color("#45475a")
    readonly property color base:     _data.base     ? Qt.color(_data.base)     : Qt.color("#1e1e2e")
    readonly property color mantle:   _data.mantle   ? Qt.color(_data.mantle)   : Qt.color("#181825")
    readonly property color crust:    _data.crust    ? Qt.color(_data.crust)    : Qt.color("#11111b")
    readonly property color blue:     _data.blue     ? Qt.color(_data.blue)     : Qt.color("#89b4fa")
    readonly property color mauve:    _data.mauve    ? Qt.color(_data.mauve)    : Qt.color("#cba6f7")
    readonly property color green:    _data.green    ? Qt.color(_data.green)    : Qt.color("#a6e3a1")
    readonly property color red:      _data.red      ? Qt.color(_data.red)      : Qt.color("#f38ba8")
    readonly property color yellow:   _data.yellow   ? Qt.color(_data.yellow)   : Qt.color("#f9e2af")
    readonly property color peach:    _data.peach    ? Qt.color(_data.peach)    : Qt.color("#fab387")
    readonly property color pink:     _data.pink     ? Qt.color(_data.pink)     : Qt.color("#f5c2e7")
    readonly property color sky:      _data.sky      ? Qt.color(_data.sky)      : Qt.color("#89dceb")
    readonly property color teal:     _data.teal     ? Qt.color(_data.teal)     : Qt.color("#94e2d5")
    readonly property color lavender: _data.lavender ? Qt.color(_data.lavender) : Qt.color("#b4befe")

    // ---------------------------------------------------------------------------
    // Afgeleid — transparanties
    // ---------------------------------------------------------------------------
    readonly property color barBackground:   Qt.rgba(base.r,    base.g,    base.b,    0.85)
    readonly property color popupBackground: Qt.rgba(mantle.r,  mantle.g,  mantle.b,  0.92)
    readonly property color pillBackground:  Qt.rgba(surface0.r, surface0.g, surface0.b, 0.80)
}
