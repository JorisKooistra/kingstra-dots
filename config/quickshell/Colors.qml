// =============================================================================
// Colors.qml — Kleurensysteem geladen vanuit colors.json
// =============================================================================
// Matugen schrijft colors.json in fase 8. Dit bestand laadt de kleuren
// en stelt ze beschikbaar als singleton voor alle componenten.
// =============================================================================
pragma Singleton
import QtQuick

QtObject {
    id: root

    // Intern: JSON-bestand laden
    readonly property var _data: {
        const path = Qt.resolvedUrl("colors.json")
        try {
            const req = new XMLHttpRequest()
            req.open("GET", path, false)
            req.send()
            return JSON.parse(req.responseText)
        } catch (e) {
            console.warn("[Colors] Kon colors.json niet laden:", e)
            return {}
        }
    }

    // Hulpfunctie — lees kleur of geef fallback terug
    function get(key, fallback) {
        return _data[key] ?? (fallback ?? "#ff00ff")
    }

    // ---------------------------------------------------------------------------
    // Material-kleuren (matugen-output)
    // ---------------------------------------------------------------------------
    readonly property color primary:           get("primary",           "#89b4fa")
    readonly property color onPrimary:         get("on_primary",        "#1e1e2e")
    readonly property color primaryContainer:  get("primary_container", "#313244")
    readonly property color secondary:         get("secondary",         "#cba6f7")
    readonly property color onSecondary:       get("on_secondary",      "#1e1e2e")
    readonly property color tertiary:          get("tertiary",          "#f5c2e7")
    readonly property color error:             get("error",             "#f38ba8")
    readonly property color background:        get("background",        "#1e1e2e")
    readonly property color onBackground:      get("on_background",     "#cdd6f4")
    readonly property color surface:           get("surface",           "#313244")
    readonly property color onSurface:         get("on_surface",        "#cdd6f4")
    readonly property color surfaceVariant:    get("surface_variant",   "#45475a")
    readonly property color outline:           get("outline",           "#6c7086")
    readonly property color outlineVariant:    get("outline_variant",   "#45475a")

    // ---------------------------------------------------------------------------
    // Catppuccin-namen (handig als directe alias)
    // ---------------------------------------------------------------------------
    readonly property color text:      get("text",      "#cdd6f4")
    readonly property color subtext0:  get("subtext0",  "#a6adc8")
    readonly property color overlay0:  get("overlay0",  "#6c7086")
    readonly property color surface0:  get("surface0",  "#313244")
    readonly property color surface1:  get("surface1",  "#45475a")
    readonly property color base:      get("base",      "#1e1e2e")
    readonly property color mantle:    get("mantle",    "#181825")
    readonly property color crust:     get("crust",     "#11111b")
    readonly property color blue:      get("blue",      "#89b4fa")
    readonly property color mauve:     get("mauve",     "#cba6f7")
    readonly property color green:     get("green",     "#a6e3a1")
    readonly property color red:       get("red",       "#f38ba8")
    readonly property color yellow:    get("yellow",    "#f9e2af")
    readonly property color peach:     get("peach",     "#fab387")
    readonly property color pink:      get("pink",      "#f5c2e7")
    readonly property color sky:       get("sky",       "#89dceb")
    readonly property color teal:      get("teal",      "#94e2d5")
    readonly property color lavender:  get("lavender",  "#b4befe")

    // ---------------------------------------------------------------------------
    // Afgeleid — transparanties voor bar en popups
    // ---------------------------------------------------------------------------
    readonly property color barBackground:     Qt.rgba(
        Qt.color(get("base", "#1e1e2e")).r,
        Qt.color(get("base", "#1e1e2e")).g,
        Qt.color(get("base", "#1e1e2e")).b,
        0.85
    )
    readonly property color popupBackground:   Qt.rgba(
        Qt.color(get("mantle", "#181825")).r,
        Qt.color(get("mantle", "#181825")).g,
        Qt.color(get("mantle", "#181825")).b,
        0.92
    )
    readonly property color pillBackground:    Qt.rgba(
        Qt.color(get("surface0", "#313244")).r,
        Qt.color(get("surface0", "#313244")).g,
        Qt.color(get("surface0", "#313244")).b,
        0.80
    )
}
